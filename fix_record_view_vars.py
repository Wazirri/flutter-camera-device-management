#!/usr/bin/env python3

# This script adds the missing variables and functions to the record_view_screen.dart file

with open('lib/screens/record_view_screen.dart', 'r') as file:
    content = file.read()

# Add _isMuted and _isFullscreen variables after _isLiveStream
if "bool _isMuted = false;" not in content:
    content = content.replace(
        "bool _isLiveStream = true; // Track if showing live stream or recording",
        "bool _isLiveStream = true; // Track if showing live stream or recording\n  bool _isMuted = false;     // Track if audio is muted\n  bool _isFullscreen = false; // Track if in fullscreen mode"
    )

# Add _toggleMute and _toggleFullScreen functions before dispose
if "void _toggleMute()" not in content:
    # First find the dispose method
    dispose_pos = content.find("void dispose()")
    if dispose_pos > 0:
        # Find the beginning of the dispose method
        before_dispose = content[:dispose_pos].rstrip()
        after_dispose = content[dispose_pos:]
        
        # Insert the new functions
        toggle_functions = """
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _player.setVolume(0);
      } else {
        _player.setVolume(100);
      }
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }
"""
        
        content = before_dispose + toggle_functions + "\n  " + after_dispose

# Write the content back to the file
with open('lib/screens/record_view_screen.dart', 'w') as file:
    file.write(content)

print("Added missing variables and functions to record_view_screen.dart")
