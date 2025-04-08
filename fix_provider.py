#!/usr/bin/env python3

import re

with open('lib/providers/camera_devices_provider.dart', 'r') as file:
    content = file.read()

# Replace the section with our updated code
old_section = r"""  // Get devices grouped by MAC address as a map of key to device
  Map<String, CameraDevice> get devicesByMacAddress => _devices;
  
  // Get the selected camera from the selected device
  Camera\? get selectedCamera \{"""

new_section = """  // Get devices grouped by MAC address as a map of key to device
  Map<String, CameraDevice> get devicesByMacAddress => _devices;
  
  // Find the parent device for a specific camera
  CameraDevice? getDeviceForCamera(Camera camera) {
    for (var device in _devices.values) {
      for (var cam in device.cameras) {
        if (cam.id == camera.id) {
          return device;
        }
      }
    }
    return null;
  }
  
  // Get the selected camera from the selected device
  Camera? get selectedCamera {"""

# Update the content
updated_content = re.sub(old_section, new_section, content)

# Write the updated content back to the file
with open('lib/providers/camera_devices_provider.dart', 'w') as file:
    file.write(updated_content)

print("Added getDeviceForCamera method to CameraDevicesProvider")
