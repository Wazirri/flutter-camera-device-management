import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

/// Screen for watching live/ongoing HLS recordings
/// Supports seeking back in the playlist while recording continues
class LiveRecordingScreen extends StatefulWidget {
  final String recordingUrl;
  final String cameraName;
  
  const LiveRecordingScreen({
    Key? key,
    required this.recordingUrl,
    required this.cameraName,
  }) : super(key: key);

  @override
  State<LiveRecordingScreen> createState() => _LiveRecordingScreenState();
}

class _LiveRecordingScreenState extends State<LiveRecordingScreen>
    with WidgetsBindingObserver {
  late Player _player;
  late VideoController _controller;
  
  bool _isBuffering = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isPlaying = false;
  bool _isLive = true; // Whether we're at the live edge
  bool _isLiveRecording = true; // Whether the recording is still ongoing (no ENDLIST)
  bool _isAppInBackground = false; // Track app background state
  
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferedDuration = Duration.zero;
  Duration _lastKnownDuration = Duration.zero; // Track duration changes
  
  Timer? _liveCheckTimer;
  Timer? _playlistRefreshTimer;
  
  // Track if user manually seeked away from live
  bool _userSeekedAway = false;
  
  // Segment count tracking for live detection
  int _lastSegmentCount = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkIfLiveRecording();
    _initializePlayer();
  }
  
  /// Check if the m3u8 is a live/event stream (no #EXT-X-ENDLIST)
  Future<void> _checkIfLiveRecording() async {
    try {
      final response = await http.get(Uri.parse(widget.recordingUrl));
      if (response.statusCode == 200) {
        final content = response.body;
        _isLiveRecording = !content.contains('#EXT-X-ENDLIST');
        _lastSegmentCount = RegExp(r'\.ts').allMatches(content).length;
        print('[LiveRecording] Is live recording: $_isLiveRecording, segments: $_lastSegmentCount');
      }
    } catch (e) {
      print('[LiveRecording] Error checking playlist: $e');
    }
  }
  
  void _initializePlayer() {
    // Create player with HLS-optimized configuration
    _player = Player(
      configuration: PlayerConfiguration(
        // Larger buffer for smoother live playback
        bufferSize: 64 * 1024 * 1024, // 64MB buffer
      ),
    );
    _controller = VideoController(_player);
    
    // Listen to player events
    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isBuffering = buffering;
        });
      }
    });
    
    _player.stream.error.listen((error) {
      if (mounted && error.isNotEmpty) {
        print('[LiveRecording] Player error: $error');
        setState(() {
          _hasError = true;
          _errorMessage = error;
        });
      }
    });
    
    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
    
    _player.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
          // Check if we're near live edge (within 5 seconds of duration)
          if (_duration.inSeconds > 0) {
            _isLive = !_userSeekedAway && 
                      (_duration.inSeconds - position.inSeconds) < 5;
          }
        });
      }
    });
    
    _player.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
          
          // If duration increased significantly, playlist was refreshed with new segments
          if (_isLiveRecording && duration > _lastKnownDuration + const Duration(seconds: 5)) {
            print('[LiveRecording] Duration grew: $_lastKnownDuration -> $duration');
            _lastKnownDuration = duration;
            
            // If we're supposed to be at live edge, seek to new live position
            if (_isLive && !_userSeekedAway) {
              Future.delayed(const Duration(milliseconds: 200), () {
                _seekToLive();
              });
            }
          }
        });
      }
    });
    
    _player.stream.buffer.listen((buffer) {
      if (mounted) {
        setState(() {
          _bufferedDuration = buffer;
        });
      }
    });
    
    // Open the stream
    _openLiveStream();
    
    // Periodically check for live edge and refresh playlist
    _startLiveCheckTimer();
    
    // Start playlist refresh timer for live recordings
    if (_isLiveRecording) {
      _startPlaylistRefreshTimer();
    }
  }
  
  void _startPlaylistRefreshTimer() {
    // Check every 10 seconds for new segments
    _playlistRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted && _isLiveRecording) {
        try {
          final response = await http.get(Uri.parse(widget.recordingUrl));
          if (response.statusCode == 200) {
            final content = response.body;
            final newSegmentCount = RegExp(r'\.ts').allMatches(content).length;
            
            if (newSegmentCount > _lastSegmentCount) {
              print('[LiveRecording] New segments detected: $_lastSegmentCount -> $newSegmentCount');
              _lastSegmentCount = newSegmentCount;
              
              // Recording still active, duration will increase automatically via media_kit
              // If user is at live edge, they will be caught up by _liveCheckTimer
            }
            
            // Check if recording has ended
            if (content.contains('#EXT-X-ENDLIST')) {
              print('[LiveRecording] Recording has ended (ENDLIST found)');
              setState(() {
                _isLiveRecording = false;
                _isLive = false;
              });
              timer.cancel();
            }
          }
        } catch (e) {
          print('[LiveRecording] Error refreshing playlist: $e');
        }
      }
    });
  }
  
  void _openLiveStream() {
    print('[LiveRecording] Opening live stream: ${widget.recordingUrl}');
    print('[LiveRecording] Is live recording: $_isLiveRecording');
    
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _isBuffering = true;
      _lastKnownDuration = Duration.zero;
    });
    
    // Create media with HLS-specific options for live streaming
    // These are passed to MPV (the underlying player) via the Media extras
    final media = Media(
      widget.recordingUrl,
      extras: {
        // Force HLS protocol
        'demuxer-lavf-o': 'protocol_whitelist=[file,http,https,tcp,tls,crypto]',
        // Reduce latency for live streams
        'hls-bitrate': 'max',
        // Allow playlist refresh for live streams
        'demuxer-max-bytes': '150MiB',
        // Low cache for lower latency
        'cache-secs': '10',
        // Force stream to update
        'stream-lavf-o': 'reconnect=1,reconnect_streamed=1',
      },
    );
    
    _player.open(media, play: true);
    
    // Seek to end (live edge) after a short delay to let duration be determined
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _seekToLive();
      }
    });
  }
  
  void _startLiveCheckTimer() {
    // Check every 3 seconds if we should seek to live
    _liveCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _isLive && !_userSeekedAway && _duration.inSeconds > 0) {
        // If we're supposed to be live but fell behind, catch up
        final behindSeconds = _duration.inSeconds - _position.inSeconds;
        if (behindSeconds > 10) {
          print('[LiveRecording] Fell behind by $behindSeconds seconds, catching up...');
          _seekToLive();
        }
      }
    });
  }
  
  void _seekToLive() {
    if (_duration.inSeconds > 0) {
      // Seek to 2 seconds before the end to be at live edge
      final livePosition = Duration(seconds: _duration.inSeconds - 2);
      print('[LiveRecording] Seeking to live edge: $livePosition');
      _player.seek(livePosition);
      _userSeekedAway = false;
      setState(() {
        _isLive = true;
      });
    }
  }
  
  void _seekTo(Duration position) {
    _player.seek(position);
    
    // If user seeks more than 5 seconds away from live edge, mark as not live
    if (_duration.inSeconds > 0) {
      final behindSeconds = _duration.inSeconds - position.inSeconds;
      if (behindSeconds > 5) {
        _userSeekedAway = true;
        setState(() {
          _isLive = false;
        });
      } else {
        _userSeekedAway = false;
        setState(() {
          _isLive = true;
        });
      }
    }
  }
  
  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }
  
  void _skipBackward(int seconds) {
    final newPosition = Duration(seconds: (_position.inSeconds - seconds).clamp(0, _duration.inSeconds));
    _seekTo(newPosition);
  }
  
  void _skipForward(int seconds) {
    final newPosition = Duration(seconds: (_position.inSeconds + seconds).clamp(0, _duration.inSeconds));
    _seekTo(newPosition);
  }
  
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveCheckTimer?.cancel();
    _playlistRefreshTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // App going to background - pause player to prevent texture issues
        if (!_isAppInBackground) {
          _isAppInBackground = true;
          print('[LiveRecording] App going to background - pausing player');
          try {
            _player.pause();
          } catch (e) {
            print('[LiveRecording] Error pausing player: $e');
          }
        }
        break;
      case AppLifecycleState.resumed:
        // App coming back to foreground - resume stream
        if (_isAppInBackground) {
          _isAppInBackground = false;
          print('[LiveRecording] App resumed - resuming stream');
          try {
            _player.play();
          } catch (e) {
            print('[LiveRecording] Error resuming player: $e');
          }
        }
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        print('[LiveRecording] App detached - stopping player');
        try {
          _player.stop();
        } catch (e) {
          print('[LiveRecording] Error stopping player: $e');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.cameraName),
            const SizedBox(width: 12),
            if (_isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 10, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'CANLI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        backgroundColor: AppTheme.darkSurface,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLive)
            TextButton.icon(
              onPressed: _seekToLive,
              icon: const Icon(Icons.skip_next, color: Colors.red),
              label: const Text(
                'CANLIYA DÖN',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Video player
          Expanded(
            child: Stack(
              children: [
                // Video
                Center(
                  child: Video(
                    controller: _controller,
                    fill: Colors.black,
                    controls: null, // We use custom controls
                  ),
                ),
                
                // Buffering indicator
                if (_isBuffering)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
                    ),
                  ),
                
                // Error overlay
                if (_hasError)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openLiveStream,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Live indicator on video
                if (_isLive)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record, size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'CANLI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Custom controls
          Container(
            color: AppTheme.darkSurface,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              children: [
                // Progress bar
                Row(
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _isLive ? Colors.red : AppTheme.primaryOrange,
                          inactiveTrackColor: Colors.grey.shade700,
                          thumbColor: _isLive ? Colors.red : AppTheme.primaryOrange,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        ),
                        child: Slider(
                          value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
                          min: 0,
                          max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
                          onChanged: (value) {
                            _seekTo(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                    ),
                    Text(
                      _isLive ? 'CANLI' : _formatDuration(_duration),
                      style: TextStyle(
                        color: _isLive ? Colors.red : Colors.white70,
                        fontSize: 12,
                        fontWeight: _isLive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                
                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Skip backward 30s
                    IconButton(
                      onPressed: () => _skipBackward(30),
                      icon: const Icon(Icons.replay_30, color: Colors.white),
                      iconSize: 32,
                    ),
                    
                    // Skip backward 10s
                    IconButton(
                      onPressed: () => _skipBackward(10),
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      iconSize: 32,
                    ),
                    
                    // Play/Pause
                    IconButton(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.white,
                      ),
                      iconSize: 56,
                    ),
                    
                    // Skip forward 10s
                    IconButton(
                      onPressed: () => _skipForward(10),
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      iconSize: 32,
                    ),
                    
                    // Go to live
                    IconButton(
                      onPressed: _seekToLive,
                      icon: Icon(
                        Icons.skip_next,
                        color: _isLive ? Colors.grey : Colors.red,
                      ),
                      iconSize: 32,
                      tooltip: 'Canlıya Dön',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
