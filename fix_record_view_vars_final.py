#!/usr/bin/env python3

# This script fixes the record_view_screen.dart file by removing duplicate _isMuted and _isFullscreen declarations
# and adds the correct VideoControls widget implementation

with open('lib/screens/record_view_screen.dart', 'r') as file:
    content = file.read()

# Remove all duplicate _isMuted and _isFullscreen declarations
import re
content = re.sub(r'^\s*bool _isMuted = false;.*\n^\s*bool _isFullscreen = false;.*\n', '', content, flags=re.MULTILINE)

# Add the variables in the correct place (after _isLiveStream)
if "bool _isMuted = false;" not in content:
    content = content.replace(
        "bool _isLiveStream = true; // Track if showing live stream or recording",
        "bool _isLiveStream = true; // Track if showing live stream or recording\n  bool _isMuted = false;     // Track if audio is muted\n  bool _isFullscreen = false; // Track if in fullscreen mode"
    )

# Fix VideoControls widget implementation
# Find the VideoControls widget
controls_pattern = re.compile(r'VideoControls\([\s\S]*?\),')
if controls_pattern.search(content):
    updated_controls = """VideoControls(
                isPlaying: _isPlaying,
                isMuted: _isMuted,
                isFullscreen: _isFullscreen,
                onPlayPause: _togglePlayPause,
                onMuteToggle: _toggleMute,
                onFullscreenToggle: _toggleFullScreen,
              ),"""
    content = controls_pattern.sub(updated_controls, content)

# Write the updated content back to the file
with open('lib/screens/record_view_screen.dart', 'w') as file:
    file.write(content)

print("Fixed record_view_screen.dart")
