import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../theme/app_theme.dart';

// Custom video controls for our Media Kit player
class VideoControls extends StatelessWidget {
  final VideoState state;

  const VideoControls(this.state, {Key? key}) : super(key: key);

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
                state.playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                if (state.playing) {
                  state.player.pause();
                } else {
                  state.player.play();
                }
              },
            ),
            
            // Position slider
            Expanded(
              child: Slider(
                value: state.position.inMilliseconds.toDouble().clamp(
                      0,
                      state.duration.inMilliseconds.toDouble().max(0),
                    ),
                min: 0,
                max: state.duration.inMilliseconds.toDouble().max(1),
                onChanged: (value) {
                  state.player.seek(Duration(milliseconds: value.toInt()));
                },
                activeColor: AppTheme.primaryOrange,
                inactiveColor: Colors.grey.shade600,
              ),
            ),
            
            // Position/duration text
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                "${_formatDuration(state.position)} / ${_formatDuration(state.duration)}",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            
            // Volume button
            IconButton(
              icon: Icon(
                state.volume > 0 ? Icons.volume_up : Icons.volume_off,
                color: Colors.white,
              ),
              onPressed: () {
                state.player.setVolume(state.volume > 0 ? 0 : 100);
              },
            ),
            
            // Fullscreen button (can implement actual fullscreen toggle)
            IconButton(
              icon: const Icon(
                Icons.fullscreen,
                color: Colors.white,
              ),
              onPressed: () {
                // Would implement actual fullscreen logic if needed
              },
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
