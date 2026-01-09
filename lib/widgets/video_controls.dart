import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../theme/app_theme.dart';

// Custom video controls for our Media Kit player
class VideoControls extends StatefulWidget {
  final Player player;
  final bool showFullScreenButton;
  final VoidCallback? onFullScreenToggle;
  final bool isLiveStream; // New: indicate if this is a live/EVENT HLS stream
  final Duration? playlistDuration; // Calculated duration from HLS playlist
  final VoidCallback? onSeekToLive; // Callback to seek to live edge
  final VoidCallback? onSeekToStart; // Callback to seek to playlist start

  const VideoControls({
    Key? key,
    required this.player,
    this.showFullScreenButton = true,
    this.onFullScreenToggle,
    this.isLiveStream = false,
    this.playlistDuration,
    this.onSeekToLive,
    this.onSeekToStart,
  }) : super(key: key);

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  late final _subscription;
  
  // Slider dragging state to prevent seek while dragging
  bool _isDragging = false;
  double _dragValue = 0;
  
  // Throttle position updates to reduce setState calls during live playback
  DateTime _lastPositionUpdate = DateTime.now();
  static const _positionUpdateInterval = Duration(milliseconds: 500); // Update max 2 times per second

  @override
  void initState() {
    super.initState();

    // Initial values
    _updatePlaybackState();

    // Set up listener for changes - only update if state actually changed
    _subscription = widget.player.stream.playing.listen((playing) {
      if (mounted && playing != _playing) {
        setState(() {
          _playing = playing;
        });
      }
    });

    // Listen to position changes - throttled to reduce setState calls
    widget.player.stream.position.listen((position) {
      if (mounted && !_isDragging) {
        final now = DateTime.now();
        // Only update if enough time has passed since last update
        if (now.difference(_lastPositionUpdate) >= _positionUpdateInterval) {
          _lastPositionUpdate = now;
          setState(() {
            _position = position;
          });
        }
      }
    });

    // Listen to duration changes - only update if actually changed
    widget.player.stream.duration.listen((duration) {
      if (mounted && duration != _duration) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // Listen to volume changes - only update if actually changed
    widget.player.stream.volume.listen((volume) {
      if (mounted && volume != _volume) {
        setState(() {
          _volume = volume;
        });
      }
    });
  }

  void _updatePlaybackState() async {
    final playing = widget.player.state.playing;
    final position = widget.player.state.position;
    final duration = widget.player.state.duration;
    final volume = widget.player.state.volume;

    if (mounted) {
      setState(() {
        _playing = playing;
        _position = position;
        _duration = duration;
        _volume = volume;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // For live streams with playlist duration, use the larger of:
    // - Player's duration (what's currently loaded/seekable)
    // - Playlist duration (total content available)
    Duration effectiveDuration;
    if (widget.isLiveStream && widget.playlistDuration != null && widget.playlistDuration! > Duration.zero) {
      // Use playlist duration if it's larger than what player reports
      effectiveDuration = widget.playlistDuration! > _duration ? widget.playlistDuration! : _duration;
      // Debug log removed for performance - was causing slowdown in live mode
    } else {
      effectiveDuration = _duration;
    }

    // Position is always what the player reports (unless dragging)
    Duration effectivePosition = _isDragging 
        ? Duration(milliseconds: _dragValue.toInt()) 
        : _position;
    Duration positionOffset = Duration.zero;

    // Only show offset info for display purposes, not for seeking
    if (widget.isLiveStream &&
        widget.playlistDuration != null &&
        widget.playlistDuration! > Duration.zero) {
      // Just for info: how much of playlist is not in player's buffer
      positionOffset = widget.playlistDuration! - _duration;
      if (positionOffset < Duration.zero) positionOffset = Duration.zero;
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Position slider at the bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  // Current position text
                  Text(
                    _formatDuration(effectivePosition),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),

                  // Position slider
                  Expanded(
                    child: Slider(
                      value: effectivePosition.inMilliseconds.toDouble().clamp(
                            0,
                            effectiveDuration.inMilliseconds.toDouble().max(0),
                          ),
                      min: 0,
                      max: effectiveDuration.inMilliseconds.toDouble().max(1),
                      onChangeStart: (value) {
                        // Start dragging - pause position updates
                        setState(() {
                          _isDragging = true;
                          _dragValue = value;
                        });
                      },
                      onChanged: (value) {
                        // Only update drag value, don't seek yet
                        setState(() {
                          _dragValue = value;
                        });
                      },
                      onChangeEnd: (value) {
                        // Dragging ended - now seek to final position
                        setState(() {
                          _isDragging = false;
                        });
                        widget.player.seek(Duration(milliseconds: value.toInt()));
                      },
                      activeColor: AppTheme.primaryOrange,
                      inactiveColor: Colors.grey.shade600,
                    ),
                  ),

                  // Duration text or LIVE badge
                  widget.isLiveStream
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : Text(
                          _formatDuration(effectiveDuration),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                ],
              ),
            ),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side controls
                Row(
                  children: [
                    // Play/Pause button
                    IconButton(
                      icon: Icon(
                        _playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_playing) {
                          widget.player.pause();
                        } else {
                          widget.player.play();
                        }
                      },
                    ),

                    // Rewind 10 seconds
                    IconButton(
                      icon: const Icon(
                        Icons.replay_10,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () {
                        // Simple seek - go back 10 seconds from current position
                        final newPos = _position - const Duration(seconds: 10);
                        widget.player
                            .seek(newPos.isNegative ? Duration.zero : newPos);
                      },
                      tooltip: '-10s',
                    ),

                    // Skip to beginning (for live streams)
                    if (widget.isLiveStream)
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () {
                          // Use callback if provided, otherwise seek to 0
                          if (widget.onSeekToStart != null) {
                            widget.onSeekToStart!();
                          } else {
                            widget.player.seek(Duration.zero);
                          }
                        },
                        tooltip: 'En Başa Git',
                      ),

                    // Forward 10 seconds
                    IconButton(
                      icon: const Icon(
                        Icons.forward_10,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () {
                        // Simple seek - go forward 10 seconds
                        final newPos = _position + const Duration(seconds: 10);
                        if (newPos < _duration) {
                          widget.player.seek(newPos);
                        } else {
                          widget.player
                              .seek(_duration - const Duration(seconds: 1));
                        }
                      },
                      tooltip: '+10s',
                    ),
                  ],
                ),

                // Center: Go to Live button (for live streams)
                if (widget.isLiveStream)
                  TextButton.icon(
                    onPressed: () {
                      // Go to live - use callback or seek to player's end
                      if (widget.onSeekToLive != null) {
                        widget.onSeekToLive!();
                      } else {
                        // Seek to player's duration (not effective duration)
                        widget.player
                            .seek(_duration - const Duration(seconds: 3));
                      }
                    },
                    icon: const Icon(Icons.skip_next,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'Canlıya Git',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      backgroundColor: Colors.red.withOpacity(0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                // Control buttons on the right
                Row(
                  children: [
                    // Volume button
                    IconButton(
                      icon: Icon(
                        _volume > 0 ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        widget.player.setVolume(_volume > 0 ? 0 : 100);
                      },
                    ),

                    // Fullscreen button
                    if (widget.showFullScreenButton)
                      IconButton(
                        icon: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: widget.onFullScreenToggle,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper to format duration
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

// Extension to handle max for doubles
extension MaxDouble on double {
  double max(double other) {
    return this > other ? this : other;
  }
}
