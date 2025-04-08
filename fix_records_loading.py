#!/usr/bin/env python3

def fix_loading_issue():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()

    # Mevcut _loadAvailableCameras metodu
    old_code = '''  void _loadAvailableCameras() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    List<Camera> cameras = [];
    
    // Collect all cameras from all devices
    for (final device in cameraDevicesProvider.devices.values) {
      cameras.addAll(device.cameras);
    }
    
    setState(() {
      _availableCameras = cameras;
      
      // If a camera is provided, find its index in the list
      if (_camera != null) {
        final index = cameras.indexWhere((c) => c.id == _camera!.id);
        if (index != -1) {
          _selectedCameraIndex = index;
        }
      }
    });
  }'''

    # _loadAvailableCameras metodu sonunda otomatik yükleme ekleyelim
    new_code = '''  void _loadAvailableCameras() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    List<Camera> cameras = [];
    
    // Collect all cameras from all devices
    for (final device in cameraDevicesProvider.devices.values) {
      cameras.addAll(device.cameras);
    }
    
    setState(() {
      _availableCameras = cameras;
      
      // If a camera is provided, find its index in the list
      if (_camera != null) {
        final index = cameras.indexWhere((c) => c.id == _camera!.id);
        if (index != -1) {
          _selectedCameraIndex = index;
        }
      }
      // If we have cameras but no camera is selected yet, select the first one
      else if (cameras.isNotEmpty && _camera == null) {
        _camera = cameras.first;
        _selectedCameraIndex = 0;
        _initializeCamera(); // Initialize the first camera automatically
      }
    });
  }'''

    content = content.replace(old_code, new_code)

    # updateRecordingsForSelectedDay metoduna hataya karşı kontrol ekleyelim
    old_code = '''  void _updateRecordingsForSelectedDay() async {
    if (_selectedDay == null || _recordingsUrl == null) {
      return;
    }
    
    setState(() {
      _isLoadingDates = true;
      _availableRecordings = [];
      _loadingError = '';
    });'''

    new_code = '''  void _updateRecordingsForSelectedDay() async {
    if (_selectedDay == null || _recordingsUrl == null) {
      print('Cannot load recordings: selectedDay or recordingsUrl is null');
      return;
    }
    
    setState(() {
      _isLoadingDates = true;
      _availableRecordings = [];
      _loadingError = '';
    });
    
    // Debug logging
    print('Loading recordings for day: ${_selectedDay}');
    print('Using recordings URL: $_recordingsUrl');'''

    content = content.replace(old_code, new_code)

    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.write(content)

    return "Fixed record_view_screen.dart - Added automatic camera selection and loading of recordings"

print(fix_loading_issue())
