#!/usr/bin/env python3

def fix_methods():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()

    # Check if file content contains "initState"
    if "void initState()" not in content:
        # Need to add the initState method
        init_state_method = '''
  @override
  void initState() {
    super.initState();
    
    // Initialize player
    _player = Player();
    _controller = VideoController(_player);
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _calendarSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _playerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));
    
    // Start animation
    _animationController.forward();
    
    // Get camera from widget if provided
    _camera = widget.camera;
    if (_camera != null) {
      _initializeCamera();
    }
    
    // Load available cameras from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableCameras();
    });
  }
  
  void _initializeCamera() {
    // Get camera device to fetch recording URL
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final device = cameraDevicesProvider.getDeviceForCamera(_camera!);
    
    if (device != null) {
      // Create HTTP URL for recordings
      _recordingsUrl = 'http://${device.ipv4}:8080/Rec/${_camera!.name}/';
      
      // Update selected day to today
      _selectedDay = DateTime.now();
      
      // Load recordings for today
      _updateRecordingsForSelectedDay();
    } else {
      setState(() {
        _loadingError = 'Device not found for camera: ${_camera!.name}';
      });
    }
  }
  
  void _loadAvailableCameras() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    List<Camera> cameras = [];
    
    // Collect all cameras from all devices
    for (final device in cameraDevicesProvider.devices) {
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
  }

  void _selectCamera(int index) {
    if (index >= 0 && index < _availableCameras.length) {
      setState(() {
        _selectedCameraIndex = index;
        _camera = _availableCameras[index];
        _selectedRecording = null;
        _recordingsUrl = null;
        _availableRecordings = [];
        _loadingError = '';
      });
      
      _initializeCamera();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _player.dispose();
    super.dispose();
  }'''
        
        # Add the initState method after the _recordingEvents variable declaration
        # Find a suitable place to insert
        if "_recordingEvents = {};" in content:
            content = content.replace("_recordingEvents = {};", "_recordingEvents = {};" + init_state_method)
        else:
            # If the specific line is not found, try to place it after the class declaration
            position = content.find("class _RecordViewScreenState extends State<RecordViewScreen> with SingleTickerProviderStateMixin {")
            if position != -1:
                # Insert after the first { of the class
                end_pos = content.find("{", position) + 1
                content = content[:end_pos] + init_state_method + content[end_pos:]
    
    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.write(content)
    
    return "Added initState and related methods to record_view_screen.dart"

print(fix_methods())
