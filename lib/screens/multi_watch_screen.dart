import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';
import '../theme/app_theme.dart';
import '../widgets/video_controls.dart';

class MultiWatchScreen extends StatefulWidget {
  final Map<Camera, String> cameraRecordings;
  final DateTime selectedDate;
  final Map<Camera, String>? cameraDateFormats; // Date format per camera
  final Map<Camera, String>? cameraDeviceIps; // Device IP per camera (for multi-device cameras)
  final Map<Camera, Duration>? cameraStartOffsets; // Start offset per camera for sync (relative to earliest recording)

  const MultiWatchScreen({
    Key? key,
    required this.cameraRecordings,
    required this.selectedDate,
    this.cameraDateFormats,
    this.cameraDeviceIps,
    this.cameraStartOffsets,
  }) : super(key: key);

  @override
  State<MultiWatchScreen> createState() => _MultiWatchScreenState();
}

class _MultiWatchScreenState extends State<MultiWatchScreen> {
  final Map<Camera, Player> _players = {};
  final Map<Camera, VideoController> _controllers = {};
  final Map<Camera, bool> _isBuffering = {};
  final Map<Camera, bool> _hasError = {};
  final Map<Camera, String> _errorMessages = {};
  final Map<Camera, bool> _isPlaying = {};
  final Map<Camera, String> _recordingUrls = {}; // Store URLs for live check
  Map<Camera, Duration> _cameraOffsets = {}; // Start offset per camera for synchronized playback
  
  // Synchronized playback control
  bool _isSyncPlaying = false;
  Duration _syncPosition = Duration.zero;
  Duration _syncDuration = Duration.zero;
  Duration _lastKnownDuration = Duration.zero; // Track duration changes for live streams
  Duration _playlistTotalDuration = Duration.zero; // Actual playlist duration from parsing
  Duration _lastNSegmentsDuration = Duration.zero; // Duration of last N segments for safe live position
  Player? _masterPlayer; // Reference player for sync
  bool _isSeeking = false;
  
  // Live recording support
  bool _isLiveRecording = false; // Whether any recording is still ongoing
  bool _isAtLiveEdge = true; // Whether we're at the live edge
  bool _initialSeekDone = false; // Prevent multiple initial seeks
  Timer? _liveCheckTimer;
  Timer? _playlistRefreshTimer;
  
  // Slider dragging state - prevent seek while dragging
  bool _isSliderDragging = false;
  double _sliderDragValue = 0.0;
  
  // Position update throttling - reduce setState calls
  DateTime _lastPositionUpdate = DateTime.now();
  static const _positionUpdateInterval = Duration(milliseconds: 500); // Max 2 updates per second
  
  @override
  void initState() {
    super.initState();
    // Initialize offsets from widget parameter
    _cameraOffsets = widget.cameraStartOffsets ?? {};
    if (_cameraOffsets.isNotEmpty) {
      print('[MultiWatch] Camera offsets initialized:');
      for (final entry in _cameraOffsets.entries) {
        print('  ${entry.key.name}: ${entry.value.inSeconds}s offset');
      }
    }
    _initializePlayers();
  }
  
  void _initializePlayers() {
    bool isFirst = true;
    
    for (final entry in widget.cameraRecordings.entries) {
      final camera = entry.key;
      final recording = entry.value;
      
      // Player ve controller oluştur - with HLS-friendly configuration
      final player = Player(
        configuration: PlayerConfiguration(
          // Larger buffer for HLS playlist
          bufferSize: 500 * 1024 * 1024, // 500MB buffer for live streams
        ),
      );
      
      // Set MPV options for HLS EVENT stream support
      if (player.platform is NativePlayer) {
        final nativePlayer = player.platform as NativePlayer;
        // Large demuxer buffer for full HLS playlist caching
        nativePlayer.setProperty('demuxer-max-bytes', '500MiB');
        nativePlayer.setProperty('demuxer-max-back-bytes', '400MiB');
        // Cache settings for seeking
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('cache-secs', '7200'); // 2 hour cache
        nativePlayer.setProperty('demuxer-seekable-cache', 'yes');
        // HLS specific options
        nativePlayer.setProperty('hls-bitrate', 'max');
        // Force stream to be seekable even without ENDLIST
        nativePlayer.setProperty('force-seekable', 'yes');
        // Start from the BEGINNING of playlist (index 0)
        // This ensures position values are accurate from the start of recording
        // We will seek to live edge after player is ready if this is a live recording
        nativePlayer.setProperty('demuxer-lavf-o', 'live_start_index=0');
        // Prefetch the entire playlist
        nativePlayer.setProperty('prefetch-playlist', 'yes');
        // CRITICAL: Prevent auto-seeking to live edge when playlist updates
        nativePlayer.setProperty('stream-lavf-o', 'reconnect_streamed=0');
        // Disable live sync - don't try to catch up to live edge
        nativePlayer.setProperty('untimed', 'yes');
      }
      
      final controller = VideoController(player);
      
      _players[camera] = player;
      _controllers[camera] = controller;
      _isBuffering[camera] = false;
      _hasError[camera] = false;
      _errorMessages[camera] = '';
      _isPlaying[camera] = false;
      
      // Set first player as master for sync
      if (isFirst) {
        _masterPlayer = player;
        isFirst = false;
        
        // Listen to master player for sync position/duration - THROTTLED
        player.stream.position.listen((position) {
          // Don't update position while user is dragging slider or seeking
          if (mounted && !_isSeeking && !_isSliderDragging) {
            final now = DateTime.now();
            // Only update if enough time has passed (throttle to reduce setState calls)
            if (now.difference(_lastPositionUpdate) >= _positionUpdateInterval) {
              _lastPositionUpdate = now;
              // Only update if position actually changed significantly (more than 200ms)
              if ((position - _syncPosition).abs() > const Duration(milliseconds: 200)) {
                setState(() {
                  _syncPosition = position;
                });
              }
            }
          }
        });
        
        player.stream.duration.listen((duration) {
          if (mounted && duration != Duration.zero) {
            // Use the larger of player duration or playlist parsed duration
            final effectiveDuration = duration > _playlistTotalDuration ? duration : _playlistTotalDuration;
            
            print('[MultiWatch] Duration update - player: ${duration.inSeconds}s, playlist: ${_playlistTotalDuration.inSeconds}s, using: ${effectiveDuration.inSeconds}s');
            
            setState(() {
              _syncDuration = effectiveDuration;
            });
            
            // For live recordings, seek to near-live position after player is ready
            // Player started from beginning (live_start_index=0) for accurate position tracking
            if (_isLiveRecording && !_initialSeekDone && effectiveDuration.inSeconds > 0) {
              print('[MultiWatch] Duration received: $effectiveDuration, seeking to live edge');
              _initialSeekDone = true;
              _lastKnownDuration = effectiveDuration;
              // Seek to live edge after a brief delay for stability
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  _seekToLiveEdge();
                }
              });
            }
          }
        });
        
        player.stream.playing.listen((playing) {
          if (mounted) {
            setState(() {
              _isSyncPlaying = playing;
            });
          }
        });
      }
      
      // Player event listeners
      player.stream.error.listen((error) {
        if (mounted) {
          setState(() {
            _hasError[camera] = true;
            _errorMessages[camera] = "Error playing video: ${error.toString()}";
          });
        }
      });
      
      player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _isBuffering[camera] = buffering;
          });
        }
      });
      
      player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying[camera] = playing;
          });
        }
      });
      
      // Kayıt URL'ini oluştur ve yükle
      _loadRecording(camera, recording);
    }
  }
  
  Future<void> _loadRecording(Camera camera, String recording) async {
    final cameraDevicesProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    // First check if we have a specific device IP for this camera
    String? deviceIp;
    for (var entry in widget.cameraDeviceIps?.entries ?? <MapEntry<Camera, String>>[]) {
      if (entry.key.mac == camera.mac) {
        deviceIp = entry.value;
        break;
      }
    }
    
    // Fallback to provider lookup if no specific IP provided
    if (deviceIp == null) {
      final device = cameraDevicesProvider.getDeviceForCamera(camera);
      deviceIp = device?.ipv4;
    }
    
    if (deviceIp != null) {
      // Use the stored date format for this camera - check by MAC first
      String? cameraDateFormat;
      for (var entry in widget.cameraDateFormats?.entries ?? <MapEntry<Camera, String>>[]) {
        if (entry.key.mac == camera.mac) {
          cameraDateFormat = entry.value;
          break;
        }
      }
      cameraDateFormat ??= widget.cameraDateFormats?[camera];
      
      // Default to yyyy-MM-dd (with dashes) as that's more common
      final selectedDayFormatted = cameraDateFormat ?? DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      
      final recordingUrl = 'http://$deviceIp:8080/Rec/${camera.name}/$selectedDayFormatted/$recording';
      
      // Store URL for live checking
      _recordingUrls[camera] = recordingUrl;
      
      print('[MultiWatch] Loading recording for ${camera.name}: $recordingUrl (format: ${cameraDateFormat ?? 'default'}, ip: $deviceIp)');
      
      setState(() {
        _hasError[camera] = false;
        _errorMessages[camera] = '';
      });
      
      final player = _players[camera];
      if (player != null) {
        try {
          // First parse the playlist to get actual duration BEFORE opening player
          await _checkIfLiveRecording(recordingUrl);
          
          print('[MultiWatch] After playlist check - playlistTotalDuration: ${_playlistTotalDuration.inSeconds}s, isLive: $_isLiveRecording');
          
          // Open the media
          player.open(Media(recordingUrl), play: true);
        } catch (e) {
          print('[MultiWatch] Error loading recording for ${camera.name}: $e');
          setState(() {
            _hasError[camera] = true;
            _errorMessages[camera] = 'Error loading recording: $e';
          });
        }
      }
    } else {
      print('[MultiWatch] No device IP found for camera: ${camera.name}');
      setState(() {
        _hasError[camera] = true;
        _errorMessages[camera] = 'Device not found for camera';
      });
    }
  }
  
  /// Parse m3u8 playlist and calculate total duration from EXTINF tags
  Future<Duration> _parsePlaylistDuration(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final content = response.body;
        double totalSeconds = 0;
        
        // Parse all #EXTINF:<duration> lines
        final extinfRegex = RegExp(r'#EXTINF:(\d+\.?\d*)');
        final matches = extinfRegex.allMatches(content);
        
        for (final match in matches) {
          final durationStr = match.group(1);
          if (durationStr != null) {
            totalSeconds += double.tryParse(durationStr) ?? 0;
          }
        }
        
        print('[MultiWatch] Parsed playlist duration: ${totalSeconds.toInt()} seconds (${matches.length} segments)');
        return Duration(seconds: totalSeconds.toInt());
      }
    } catch (e) {
      print('[MultiWatch] Error parsing playlist: $e');
    }
    return Duration.zero;
  }
  
  /// Check if any m3u8 is a live/event stream (no #EXT-X-ENDLIST) and parse duration
  Future<void> _checkIfLiveRecording(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final content = response.body;
        final isLive = !content.contains('#EXT-X-ENDLIST');
        
        // Parse all segment durations from playlist
        final List<double> segmentDurations = [];
        final extinfRegex = RegExp(r'#EXTINF:(\d+\.?\d*)');
        final matches = extinfRegex.allMatches(content);
        for (final match in matches) {
          final durationStr = match.group(1);
          if (durationStr != null) {
            segmentDurations.add(double.tryParse(durationStr) ?? 0);
          }
        }
        
        // Calculate total duration
        final totalSeconds = segmentDurations.fold<double>(0, (sum, d) => sum + d);
        final playlistDuration = Duration(seconds: totalSeconds.toInt());
        
        // Calculate last 10 segments duration for live offset
        final last10 = segmentDurations.length >= 10 
            ? segmentDurations.sublist(segmentDurations.length - 10) 
            : segmentDurations;
        final last10Seconds = last10.fold<double>(0, (sum, d) => sum + d);
        final last10Duration = Duration(seconds: last10Seconds.toInt());
        
        print('[MultiWatch] Playlist analysis: isLive=$isLive, duration=${playlistDuration.inSeconds}s, segments=${matches.length}, last10Segments=${last10Duration.inSeconds}s');
        
        if (mounted) {
          setState(() {
            _playlistTotalDuration = playlistDuration;
            _lastNSegmentsDuration = last10Duration;
            // Use playlist duration as sync duration if it's larger
            if (playlistDuration > _syncDuration) {
              _syncDuration = playlistDuration;
            }
          });
        }
        
        if (isLive) {
          print('[MultiWatch] Detected live recording: $url');
          if (mounted && !_isLiveRecording) {
            setState(() {
              _isLiveRecording = true;
            });
            _startLiveRecordingTimers();
          }
        }
      }
    } catch (e) {
      print('[MultiWatch] Error checking playlist: $e');
    }
  }
  
  void _startLiveRecordingTimers() {
    // Live check timer removed - we don't want auto-seeking during playback
    // User can manually use "Canlıya Dön" button if they want to go to live edge
    _liveCheckTimer?.cancel();
    
    // Periodically refresh playlist to get updated duration for live recordings
    _playlistRefreshTimer?.cancel();
    _playlistRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted || !_isLiveRecording) {
        timer.cancel();
        return;
      }
      
      // Re-parse playlist to get new duration
      for (final url in _recordingUrls.values) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final content = response.body;
            
            // Check if recording ended
            if (content.contains('#EXT-X-ENDLIST')) {
              print('[MultiWatch] Recording ended (ENDLIST found)');
              setState(() {
                _isLiveRecording = false;
              });
              timer.cancel();
              return;
            }
            
            // Parse all segment durations
            final List<double> segmentDurations = [];
            final extinfRegex = RegExp(r'#EXTINF:(\d+\.?\d*)');
            final matches = extinfRegex.allMatches(content);
            for (final match in matches) {
              final durationStr = match.group(1);
              if (durationStr != null) {
                segmentDurations.add(double.tryParse(durationStr) ?? 0);
              }
            }
            
            final totalSeconds = segmentDurations.fold<double>(0, (sum, d) => sum + d);
            final newDuration = Duration(seconds: totalSeconds.toInt());
            
            // Calculate last 10 segments duration
            final last10 = segmentDurations.length >= 10 
                ? segmentDurations.sublist(segmentDurations.length - 10) 
                : segmentDurations;
            final last10Seconds = last10.fold<double>(0, (sum, d) => sum + d);
            final last10Duration = Duration(seconds: last10Seconds.toInt());
            
            if (newDuration > _playlistTotalDuration) {
              print('[MultiWatch] Playlist duration grew: ${_playlistTotalDuration.inSeconds}s -> ${newDuration.inSeconds}s, last10Segments: ${last10Duration.inSeconds}s');
              setState(() {
                _playlistTotalDuration = newDuration;
                _lastNSegmentsDuration = last10Duration;
                if (newDuration > _syncDuration) {
                  _syncDuration = newDuration;
                }
              });
              
              // DO NOT auto-seek when playlist updates - let playback continue naturally
              // User can manually seek to live edge if they want
            }
          }
        } catch (e) {
          print('[MultiWatch] Error refreshing playlist: $e');
        }
        break; // Only check first URL
      }
    });
  }
  
  void _seekToLiveEdge() {
    if (_syncDuration.inSeconds > 0) {
      // Seek to before the last 10 segments for stable playback
      // Use calculated segment duration or default to 60 seconds (10 segments * 6 sec each)
      final offsetSeconds = _lastNSegmentsDuration.inSeconds > 0 
          ? _lastNSegmentsDuration.inSeconds 
          : 60;
      final livePosition = Duration(
          seconds: (_syncDuration.inSeconds - offsetSeconds).clamp(0, _syncDuration.inSeconds));
      print('[MultiWatch] Seeking to safe live position: $livePosition (${offsetSeconds}s before live edge)');
      _seekAll(livePosition);
      setState(() {
        _isAtLiveEdge = true;
      });
    }
  }
  
  void _playAll() {
    for (final player in _players.values) {
      player.play();
    }
  }
  
  void _pauseAll() {
    for (final player in _players.values) {
      player.pause();
    }
  }
  
  void _stopAll() {
    for (final player in _players.values) {
      player.stop();
    }
  }
  
  // Seek all players to a specific position (with per-camera offset compensation)
  void _seekAll(Duration position, {bool isUserSeek = false}) {
    print('[MultiWatch] _seekAll called: position=$position, isUserSeek=$isUserSeek, duration=$_syncDuration');
    _isSeeking = true;
    
    // If user manually seeks backward in live mode, mark as not at live edge
    if (isUserSeek && _isLiveRecording) {
      final behindSeconds = _syncDuration.inSeconds - position.inSeconds;
      if (behindSeconds > 5) {
        print('[MultiWatch] User seeked away from live edge by $behindSeconds seconds');
        setState(() {
          _isAtLiveEdge = false;
        });
      } else {
        setState(() {
          _isAtLiveEdge = true;
        });
      }
    }
    
    // Apply per-camera offset compensation for synchronized playback
    for (final entry in _players.entries) {
      final camera = entry.key;
      final player = entry.value;
      
      // Get offset for this camera (default 0 if not specified)
      final offset = _cameraOffsets[camera] ?? Duration.zero;
      
      // Calculate adjusted position: later recordings need to seek earlier
      // If camera started 20s later than reference, seek 20s earlier in that recording
      final adjustedPosition = position - offset;
      
      // Clamp to valid range (don't seek before 0)
      final clampedPosition = adjustedPosition < Duration.zero ? Duration.zero : adjustedPosition;
      
      if (offset != Duration.zero) {
        print('[MultiWatch] ${camera.name}: position=$position, offset=${offset.inSeconds}s, adjusted=${clampedPosition.inSeconds}s');
      }
      
      player.seek(clampedPosition);
    }
    setState(() {
      _syncPosition = position;
    });
    // Allow position updates after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _isSeeking = false;
    });
  }
  
  // Skip forward/backward all players
  void _skipAll(int seconds) {
    final newPosition = _syncPosition + Duration(seconds: seconds);
    final clampedPosition = newPosition < Duration.zero 
        ? Duration.zero 
        : (newPosition > _syncDuration ? _syncDuration : newPosition);
    
    print('[MultiWatch] _skipAll: $seconds seconds, new position: $clampedPosition');
    _seekAll(clampedPosition, isUserSeek: true);
  }
  
  // Toggle play/pause for all players
  void _togglePlayPause() {
    if (_isSyncPlaying) {
      _pauseAll();
    } else {
      _playAll();
    }
  }
  
  // Format duration to string
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
  
  @override
  void dispose() {
    _liveCheckTimer?.cancel();
    _playlistRefreshTimer?.cancel();
    // Tüm player'ları temizle
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraCount = widget.cameraRecordings.length;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                'Toplu İzleme - ${DateFormat('dd/MM/yyyy').format(widget.selectedDate)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isLiveRecording) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isAtLiveEdge ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 10,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isAtLiveEdge ? 'CANLI' : 'GECİKMELİ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        automaticallyImplyLeading: true, // Sadece geri butonu göster
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Go to live edge button (only show when not at live edge in live mode)
          if (_isLiveRecording && !_isAtLiveEdge)
            TextButton.icon(
              onPressed: () {
                _seekToLiveEdge();
              },
              icon: const Icon(Icons.skip_next, color: Colors.red),
              label: const Text(
                'CANLIYA DÖN',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Tümünü Oynat',
            onPressed: _playAll,
          ),
          IconButton(
            icon: const Icon(Icons.pause),
            tooltip: 'Tümünü Duraklat',
            onPressed: _pauseAll,
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: 'Tümünü Durdur',
            onPressed: _stopAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Video grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildPlayersGrid(cameraCount),
            ),
          ),
          
          // Synchronized control bar at bottom
          _buildSyncControlBar(),
        ],
      ),
    );
  }
  
  // Build the synchronized control bar
  Widget _buildSyncControlBar() {
    // Use drag value while dragging, otherwise use actual position
    final displayPosition = _isSliderDragging 
        ? Duration(milliseconds: (_sliderDragValue * _syncDuration.inMilliseconds).round())
        : _syncPosition;
    
    final progress = _syncDuration.inMilliseconds > 0
        ? (_isSliderDragging ? _sliderDragValue : _syncPosition.inMilliseconds / _syncDuration.inMilliseconds)
        : 0.0;
    
    // For live recordings, use red colors when at live edge
    final activeColor = (_isLiveRecording && _isAtLiveEdge) ? Colors.red : AppTheme.primaryOrange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seek bar
            Row(
              children: [
                // Current position
                Text(
                  _formatDuration(displayPosition),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                
                // Seek slider
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: activeColor,
                      inactiveTrackColor: Colors.grey[600],
                      thumbColor: activeColor,
                      overlayColor: activeColor.withOpacity(0.2),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChangeStart: (value) {
                        // Start dragging - pause position updates from player
                        setState(() {
                          _isSliderDragging = true;
                          _sliderDragValue = value;
                        });
                      },
                      onChanged: (value) {
                        // Only update visual position while dragging, don't seek yet
                        setState(() {
                          _sliderDragValue = value;
                        });
                      },
                      onChangeEnd: (value) {
                        // Dragging ended - now seek to final position
                        setState(() {
                          _isSliderDragging = false;
                        });
                        final newPosition = Duration(
                          milliseconds: (value * _syncDuration.inMilliseconds).round(),
                        );
                        print('[MultiWatch] Slider seek to: $newPosition');
                        _seekAll(newPosition, isUserSeek: true);
                      },
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                // Total duration or LIVE indicator
                Text(
                  (_isLiveRecording && _isAtLiveEdge) ? 'CANLI' : _formatDuration(_syncDuration),
                  style: TextStyle(
                    color: (_isLiveRecording && _isAtLiveEdge) ? Colors.red : Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: (_isLiveRecording && _isAtLiveEdge) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Skip backward 30s
                IconButton(
                  icon: const Icon(Icons.replay_30, color: Colors.white, size: 28),
                  tooltip: '30 saniye geri',
                  onPressed: () => _skipAll(-30),
                ),
                
                // Skip backward 10s
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                  tooltip: '10 saniye geri',
                  onPressed: () => _skipAll(-10),
                ),
                
                const SizedBox(width: 16),
                
                // Play/Pause button
                Container(
                  decoration: BoxDecoration(
                    color: (_isLiveRecording && _isAtLiveEdge) ? Colors.red : AppTheme.primaryOrange,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isSyncPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    tooltip: _isSyncPlaying ? 'Tümünü Duraklat' : 'Tümünü Oynat',
                    onPressed: _togglePlayPause,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Skip forward 10s
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                  tooltip: '10 saniye ileri',
                  onPressed: () => _skipAll(10),
                ),
                
                // Skip forward 30s / Go to live button
                if (_isLiveRecording && !_isAtLiveEdge)
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.red, size: 28),
                    tooltip: 'Canlıya Dön',
                    onPressed: _seekToLiveEdge,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.forward_30, color: Colors.white, size: 28),
                    tooltip: '30 saniye ileri',
                    onPressed: () => _skipAll(30),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlayersGrid(int cameraCount) {
    // Ekran boyutuna göre optimal grid düzenini belirle
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    int crossAxisCount;
    double childAspectRatio;
    
    if (cameraCount == 1) {
      // Tek kamera - tam ekran
      crossAxisCount = 1;
      childAspectRatio = isLandscape ? 16 / 9 : 9 / 16;
    } else if (cameraCount == 2) {
      // İki kamera - yan yana veya alt alta
      crossAxisCount = isLandscape ? 2 : 1;
      childAspectRatio = 16 / 9;
    } else if (cameraCount <= 4) {
      // 3-4 kamera - 2x2 grid
      crossAxisCount = 2;
      childAspectRatio = 16 / 9;
    } else if (cameraCount <= 6) {
      // 5-6 kamera - 3x2 veya 2x3
      crossAxisCount = isLandscape ? 3 : 2;
      childAspectRatio = 16 / 9;
    } else if (cameraCount <= 9) {
      // 7-9 kamera - 3x3
      crossAxisCount = 3;
      childAspectRatio = 16 / 9;
    } else if (cameraCount <= 12) {
      // 10-12 kamera - 4x3
      crossAxisCount = 4;
      childAspectRatio = 16 / 9;
    } else {
      // 12+ kamera - dense grid
      crossAxisCount = isLandscape ? 5 : 4;
      childAspectRatio = 16 / 9;
    }
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: cameraCount,
      itemBuilder: (context, index) {
        final camera = widget.cameraRecordings.keys.elementAt(index);
        final recording = widget.cameraRecordings[camera]!;
        
        return _buildVideoPlayer(camera, recording);
      },
    );
  }
  
  Widget _buildVideoPlayer(Camera camera, String recording) {
    final controller = _controllers[camera];
    final player = _players[camera];
    final isBuffering = _isBuffering[camera] ?? false;
    final hasError = _hasError[camera] ?? false;
    final errorMessage = _errorMessages[camera] ?? '';
    final cameraCount = widget.cameraRecordings.length;
    
    // Kamera sayısına göre font boyutu ayarla
    double titleFontSize = cameraCount <= 4 ? 14 : (cameraCount <= 9 ? 12 : 10);
    double iconSize = cameraCount <= 4 ? 20 : (cameraCount <= 9 ? 16 : 14);
    
    if (controller == null || player == null) {
      return _buildErrorCard(camera, 'Player not initialized');
    }
    
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: cameraCount <= 4 ? 4 : 2, // Daha az kamera = daha yüksek elevation
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kamera başlığı
          Container(
            padding: EdgeInsets.all(cameraCount <= 4 ? 8.0 : 6.0),
            color: AppTheme.primaryBlue,
            child: Row(
              children: [
                Icon(Icons.videocam, color: Colors.white, size: iconSize),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    camera.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Recording format indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    recording.toLowerCase().endsWith('.m3u8') ? 'M3U8' : 'MKV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize - 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Video oynatıcı
          Expanded(
            child: Stack(
              children: [
                // Video Widget
                Container(
                  color: Colors.black,
                  child: Video(
                    controller: controller,
                    fill: Colors.black,
                    controls: null,
                  ),
                ),
                
                // Buffering indicator
                if (isBuffering)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                
                // Error overlay
                if (hasError)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Mini controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            (_isPlaying[camera] ?? false) ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            if (_isPlaying[camera] ?? false) {
                              player.pause();
                            } else {
                              player.play();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => player.stop(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _openFullScreen(camera, recording),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Kayıt bilgisi
          Container(
            padding: const EdgeInsets.all(4.0),
            color: Colors.grey[100],
            child: Text(
              recording.split('/').last.split('_').first,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorCard(Camera camera, String error) {
    return Card(
      child: Container(
        color: Colors.grey[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              camera.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  void _openFullScreen(Camera camera, String recording) {
    final controller = _controllers[camera];
    final player = _players[camera];
    
    if (controller != null && player != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text(camera.name),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            body: Stack(
              children: [
                Center(
                  child: Video(
                    controller: controller,
                    fill: Colors.black,
                    controls: null,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoControls(
                    player: player,
                    showFullScreenButton: false,
                    isLiveStream: _isLiveRecording,
                    playlistDuration: _playlistTotalDuration,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
