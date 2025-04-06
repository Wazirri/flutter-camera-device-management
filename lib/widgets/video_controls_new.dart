import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../theme/app_theme.dart';

/// Custom video controls for the multi-view layout
class VideoControlsNew extends StatefulWidget {
  final VideoController controller;
  final VoidCallback? onFullScreen;
  
  const VideoControlsNew({
    Key? key,
    required this.controller,
    this.onFullScreen,
  }) : super(key: key);

  @override
  State<VideoControlsNew> createState() => _VideoControlsNewState();
}

class _VideoControlsNewState extends State<VideoControlsNew> with SingleTickerProviderStateMixin {
  // Animation controller for fading controls
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  
  // Timer to auto-hide controls
  bool _isPlaying = true;
  bool _isControlsVisible = true;
  bool _isMuted = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Start with visible controls
    _animationController.value = 1.0;
    
    // Listen to player state changes
    widget.controller.player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
    
    widget.controller.player.stream.volume.listen((volume) {
      if (mounted) {
        setState(() {
          _isMuted = volume == 0;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        height: 40,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Play/Pause button
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                if (_isPlaying) {
                  widget.controller.player.pause();
                } else {
                  widget.controller.player.play();
                }
              },
            ),
            
            // Mute/Unmute button
            IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                if (_isMuted) {
                  widget.controller.player.setVolume(100);
                } else {
                  widget.controller.player.setVolume(0);
                }
                setState(() {
                  _isMuted = !_isMuted;
                });
              },
            ),
            
            // Fullscreen button
            if (widget.onFullScreen != null)
              IconButton(
                icon: const Icon(
                  Icons.fullscreen,
                  color: Colors.white,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onFullScreen,
              ),
          ],
        ),
      ),
    );
  }
}
