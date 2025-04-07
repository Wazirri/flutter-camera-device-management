import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../theme/app_theme.dart';

// Custom video controls for our Media Kit player
class VideoControls extends StatelessWidget {
  final bool isPlaying;
  final bool isMuted;
  final bool isFullscreen;
  final VoidCallback onPlayPause;
  final VoidCallback onMuteToggle;
  final VoidCallback onFullscreenToggle;

  const VideoControls({
    Key? key,
    required this.isPlaying,
    required this.isMuted,
    required this.isFullscreen,
    required this.onPlayPause,
    required this.onMuteToggle,
    required this.onFullscreenToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Play/Pause button
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: onPlayPause,
          ),
          
          // Right-side controls
          Row(
            children: [
              // Mute button
              IconButton(
                icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: onMuteToggle,
              ),
              
              // Fullscreen button
              IconButton(
                icon: Icon(
                  isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                ),
                onPressed: onFullscreenToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
