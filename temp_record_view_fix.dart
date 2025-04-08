  // Fetch available recording dates for the selected camera
  void _fetchRecordings() async {
    if (_camera == null) {
      setState(() {
        _availableRecordings = [];
        _recordingsByDate.clear();
      });
      return;
    }
    
    setState(() {
      _isLoadingDates = true;
      _loadingError = '';
    });
    
    try {
      // Get the parent device of this camera
      final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
      final parentDevice = cameraProvider.getDeviceForCamera(_camera!);
      
      if (parentDevice == null) {
        throw Exception('Could not find parent device for this camera');
      }
      
      // Construct the recordings base URL using the device IP (not camera IP)
      final deviceIp = parentDevice.ipv4;
      if (deviceIp.isEmpty) {
        throw Exception('Device IP is not available');
      }
      
      _recordingsUrl = 'http://$deviceIp:8080/Rec/${_camera!.name}/';
