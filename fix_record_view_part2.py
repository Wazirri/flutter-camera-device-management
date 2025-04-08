#!/usr/bin/env python3

def fix_record_view():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()
    
    # 1. Fix the Camera import (Camera modeli camera_device.dart içinde)
    content = content.replace("import '../models/camera.dart';", "")
    
    # 2. Fix CameraDevicesProvider.devices değişkeninin Map<String, CameraDevice> olması
    old_code = '''  void _loadAvailableCameras() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    List<Camera> cameras = [];
    
    // Collect all cameras from all devices
    for (final device in cameraDevicesProvider.devices) {
      cameras.addAll(device.cameras);
    }'''
    
    new_code = '''  void _loadAvailableCameras() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    List<Camera> cameras = [];
    
    // Collect all cameras from all devices
    for (final device in cameraDevicesProvider.devices.values) {
      cameras.addAll(device.cameras);
    }'''
    
    content = content.replace(old_code, new_code)
    
    # 3. Fix VideoControls widget parametresi
    old_code = '''          child: Video(
            controller: _controller,
            fill: Colors.black,
            controls: false,
          ),'''
    
    new_code = '''          child: Video(
            controller: _controller,
            fill: Colors.black,
            controls: null,
          ),'''
    
    content = content.replace(old_code, new_code)
    
    # 4. Fix VideoControls widget parametresi
    old_code = '''          child: _camera != null ? VideoControls(
            player: _player,
            hasFullScreenButton: true,
            onFullScreenToggle: _toggleFullScreen,
          ) : const SizedBox.shrink(),'''
    
    new_code = '''          child: _camera != null ? VideoControls(
            player: _player,
            showFullScreenButton: true,
            onFullScreenToggle: _toggleFullScreen,
          ) : const SizedBox.shrink(),'''
    
    content = content.replace(old_code, new_code)
    
    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.write(content)
    
    return "Fixed record_view_screen.dart issues"

print(fix_record_view())
