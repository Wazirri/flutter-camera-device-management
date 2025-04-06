#!/bin/bash

# Fix 1: Replace the line with the 'dispose' method for VideoController
sed -i 's/controller.dispose();/controller.player.dispose();/g' lib/screens/multi_live_view_screen_new.dart

# Fix 2: Fix the 'for' loop that iterates over devices
sed -i 's/for (final device in devicesProvider.devices) {/for (final device in devicesProvider.devices.values) {/g' lib/screens/multi_live_view_screen_new.dart

# Fix 3 & 5: Replace the null return in orElse with an empty camera
sed -i 's/orElse: () => null,/orElse: () => Camera(),/g' lib/screens/multi_live_view_screen_new.dart

# Fix 4 & 6 & 9 & 11: Replace other instances of dispose() call on VideoController
sed -i 's/_videoControllers\[slotCode\]!.dispose();/_videoControllers[slotCode]!.player.dispose();/g' lib/screens/multi_live_view_screen_new.dart

# Fix 7 & 8: Fix the VideoController instantiation
sed -i 's/final controller = VideoController(/final controller = VideoController(Player(),/g' lib/screens/multi_live_view_screen_new.dart
sed -i 's/controls: NoVideoControls,/\/\/ controls option is not supported here/g' lib/screens/multi_live_view_screen_new.dart

# Fix 10: Replace Media with player.open
sed -i 's/      Media(camera.rtspUri),/      Media(Uri.parse(camera.rtspUri ?? "")),/g' lib/screens/multi_live_view_screen_new.dart

chmod +x temp_fix.sh
./temp_fix.sh
