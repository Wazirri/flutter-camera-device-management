import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../theme/app_theme.dart';

// Custom video controls for our Media Kit player
class VideoControls extends StatefulWidget {
  final Player player;
  final bool showFullScreenButton;
  final VoidCallback? onFullScreenToggle;

  const VideoControls({
    Key? key,
    required this.player,
    this.showFullScreenButton = true,
    this.onFullScreenToggle,
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

  @override
  void initState() {
    super.initState();
    
    // Initial values
    _updatePlaybackState();
    
    // Set up listener for changes
    _subscription = widget.player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _playing = playing;
        });
      }
    });
    
    // Listen to position changes
    widget.player.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
    
    // Listen to duration changes
    widget.player.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
    
    // Listen to volume changes
    widget.player.stream.volume.listen((volume) {
      if (mounted) {
        setState(() {
          _volume = volume;
        });
      }
    });
  }
  
  void _updatePlaybackState() async {
    final playing = await widget.player.state.playing;
    final position = await widget.player.state.position;
    final duration = await widget.player.state.duration;
    final volume = await widget.player.state.volume;
    
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
        child: Row(
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
            
            // Position slider
            Expanded(
              child: Slider(
                value: _position.inMilliseconds.toDouble().clamp(
                      0,
                      _duration.inMilliseconds.toDouble().max(0),
                    ),
                min: 0,
                max: _duration.inMilliseconds.toDouble().max(1),
                onChanged: (value) {
                  widget.player.seek(Duration(milliseconds: value.toInt()));
                },
                activeColor: AppTheme.primaryOrange,
                inactiveColor: Colors.grey.shade600,
              ),
            ),
            
            // Position/duration text
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            
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
