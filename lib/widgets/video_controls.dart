import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Custom video controls for our Media Kit player
class VideoControls extends StatelessWidget {
  final bool isFullScreen;
  final bool isMuted;
  final VoidCallback onToggleFullScreen;
  final VoidCallback onToggleMute;
  final bool isRecording;
  final VoidCallback? onPlayPause;

  const VideoControls({
    Key? key,
    required this.isFullScreen,
    required this.isMuted,
    required this.onToggleFullScreen,
    required this.onToggleMute,
    this.isRecording = false,
    this.onPlayPause,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // When tapped anywhere, toggle fullscreen mode
        onToggleFullScreen();
      },
      child: Stack(
        children: [
          // Full-screen toggle button positioned at the top-right
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(
                  isFullScreen 
                    ? Icons.fullscreen_exit 
                    : Icons.fullscreen,
                  color: Colors.white,
                ),
                onPressed: onToggleFullScreen,
                tooltip: isFullScreen 
                  ? 'Exit Fullscreen' 
                  : 'Enter Fullscreen',
              ),
            ),
          ),
          
          // Volume control button positioned at the top-left
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(
                  isMuted 
                    ? Icons.volume_off 
                    : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: onToggleMute,
                tooltip: isMuted 
                  ? 'Unmute' 
                  : 'Mute',
              ),
            ),
          ),
          
          // Play/pause button centered
          if (isRecording && onPlayPause != null)
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.pause,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: onPlayPause,
                  tooltip: 'Pause',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Extension to handle max for doubles
extension MaxDouble on double {
  double max(double other) {
    return this > other ? this : other;
  }
}
