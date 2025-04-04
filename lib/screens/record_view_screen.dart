import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';
import '../providers/camera_devices_provider.dart';
import '../models/camera_device.dart';

class RecordViewScreen extends StatefulWidget {
  const RecordViewScreen({Key? key}) : super(key: key);

  @override
  State<RecordViewScreen> createState() => _RecordViewScreenState();
}

class _RecordViewScreenState extends State<RecordViewScreen> {
  final _dateController = TextEditingController(text: '2025-04-01');
  String _selectedCameraName = '';
  
  // Map to store MediaKit players for recordings
  Player? _recordingPlayer;
  VideoController? _videoController;
  bool _playerInitialized = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize player for the selected camera
    _recordingPlayer = Player();
    _videoController = VideoController(_recordingPlayer!);
    
    // Set up the player after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSelectedCamera();
    });
  }
  
  void _initializeSelectedCamera() {
    final cameraDevicesProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final selectedCamera = cameraDevicesProvider.selectedCamera;
    
    if (selectedCamera != null) {
      _selectedCameraName = selectedCamera.name;
      
      // Try to load a recording if available (using the record URI which would normally
      // be a past recording, but for demo purposes we're using it as-is)
      if (selectedCamera.recordUri.isNotEmpty) {
        _initializePlayer(selectedCamera.recordUri);
      }
    }
  }
  
  Future<void> _initializePlayer(String streamUrl) async {
    if (streamUrl.isEmpty) {
      debugPrint('No record stream URL available for this camera');
      return;
    }
    
    try {
      debugPrint('Initializing recording player with URL: $streamUrl');
      await _recordingPlayer!.open(Media(streamUrl));
      
      if (mounted) {
        setState(() {
          _playerInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing recording player: $e');
    }
  }
  
  @override
  void dispose() {
    _dateController.dispose();
    _recordingPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: CustomAppBar(
        title: 'Recordings',
        isDesktop: isDesktop,
        actions: [
          _buildDateSelector(),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Timeline sidebar - only visible on desktop/tablet
          if (isDesktop || ResponsiveHelper.isTablet(context))
            SizedBox(
              width: 280,
              child: Card(
                margin: EdgeInsets.zero,
                color: AppTheme.darkSurface,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                child: Column(
                  children: [
                    _buildCalendar(),
                    Expanded(
                      child: _buildCamerasList(),
                    ),
                  ],
                ),
              ),
            ),
          
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Recording video display area
                Expanded(
                  child: _buildRecordingView(),
                ),
                
                // Playback controls
                _buildPlaybackControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppTheme.primaryBlue,
                    onPrimary: Colors.white,
                    surface: AppTheme.darkSurface,
                    onSurface: AppTheme.darkTextPrimary,
                  ),
                  dialogBackgroundColor: AppTheme.darkSurface,
                ),
                child: child!,
              );
            },
          );
          if (date != null) {
            setState(() {
              _dateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Text(_dateController.text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.darkSurface.withOpacity(0.8), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'April 2025',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      // UI only
                    },
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      // UI only
                    },
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    // Create a simple calendar grid
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: 7 + 30, // 7 days of week + 30 days in month
      itemBuilder: (context, index) {
        if (index < 7) {
          // Weekday headers
          final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
          return Center(
            child: Text(
              weekdays[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextSecondary,
              ),
            ),
          );
        } else {
          // Day cells
          final day = index - 7 + 1;
          final hasRecordings = [1, 5, 10, 15, 20, 25].contains(day);
          final isSelected = day == 1; // April 1st is selected
          
          return InkWell(
            onTap: () {
              // UI only
            },
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.primaryBlue 
                    : hasRecordings 
                        ? AppTheme.primaryBlue.withOpacity(0.1) 
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    color: isSelected 
                        ? Colors.white 
                        : hasRecordings 
                            ? AppTheme.primaryBlue 
                            : AppTheme.darkTextPrimary,
                    fontWeight: isSelected || hasRecordings ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildCamerasList() {
    return Consumer<CameraDevicesProvider>(
      builder: (context, provider, child) {
        // Get all cameras from all devices
        final allCameras = provider.allCameras;
        
        if (allCameras.isEmpty) {
          return const Center(
            child: Text(
              'No cameras available.\nMake sure you are connected to the server.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }
        
        // Filter for cameras that have recording capabilities (have recordUri)
        final recordingCameras = allCameras
            .where((camera) => camera.recordUri.isNotEmpty || camera.recording)
            .toList();
        
        if (recordingCameras.isEmpty) {
          return const Center(
            child: Text(
              'No cameras with recordings found.\nCheck that cameras are properly configured.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }
        
        return ListView.builder(
          itemCount: recordingCameras.length,
          itemBuilder: (context, index) {
            final camera = recordingCameras[index];
            final isSelected = camera.name == _selectedCameraName;
            
            return _buildCameraRecordingItem(
              camera: camera,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedCameraName = camera.name;
                });
                
                // Find the device this camera belongs to
                for (var device in provider.devicesList) {
                  final cameraIndex = device.cameras.indexWhere((c) => c.name == camera.name);
                  if (cameraIndex >= 0) {
                    provider.setSelectedDevice(device.macKey);
                    provider.setSelectedCameraIndex(cameraIndex);
                    
                    // Initialize player with this camera's recording
                    if (camera.recordUri.isNotEmpty) {
                      _initializePlayer(camera.recordUri);
                    }
                    break;
                  }
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCameraRecordingItem({
    required Camera camera,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(
            Icons.videocam,
            color: isSelected ? AppTheme.primaryBlue : AppTheme.primaryOrange,
            size: 20,
          ),
        ),
      ),
      title: Text(
        camera.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryBlue : AppTheme.darkTextPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (camera.manufacturer.isNotEmpty || camera.hw.isNotEmpty)
            Text(
              '${camera.manufacturer} ${camera.hw}',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.darkTextSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            camera.recording ? 'Currently Recording' : 'Has Recordings',
            style: TextStyle(
              fontSize: 12,
              color: camera.recording ? Colors.red : AppTheme.darkTextSecondary,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.play_circle_fill,
        color: isSelected ? AppTheme.primaryBlue : AppTheme.primaryOrange,
        size: 24,
      ),
    );
  }

  Widget _buildRecordingView() {
    // Check if we have a selected camera
    final cameraProvider = Provider.of<CameraDevicesProvider>(context, listen: false);
    final selectedCamera = cameraProvider.selectedCamera;
    
    if (selectedCamera == null) {
      return const Center(
        child: Text(
          'No camera selected',
          style: TextStyle(fontSize: 16),
        ),
      );
    }
    
    // Check if player is initialized
    if (!_playerInitialized || selectedCamera.recordUri.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam,
                size: 64,
                color: AppTheme.primaryOrange,
              ),
              const SizedBox(height: 16),
              Text(
                'No Recording Available',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selectedCamera.name,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
              if (selectedCamera.recordUri.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'This camera does not have a recording URI configured',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[300],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    
    // Show the video player
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Video
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Video(
                controller: _videoController!,
                controls: true,
              ),
            ),
          ),
          
          // Camera info overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    size: 12,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedCamera.name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Recording details overlay
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_dateController.text} (${selectedCamera.recordWidth}x${selectedCamera.recordHeight})',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      height: 100,
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Progress slider
          Slider(
            value: 0.3,
            onChanged: (value) {
              // UI only
            },
            activeColor: AppTheme.primaryBlue,
            inactiveColor: AppTheme.darkBackground,
          ),
          
          // Time and controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '01:45 / 05:30',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                  ),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      // Pause/play the recording player
                      if (_recordingPlayer != null && _playerInitialized) {
                        _recordingPlayer!.playOrPause();
                      }
                    },
                    child: const Icon(Icons.pause),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                    tooltip: 'Download',
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                    tooltip: 'Fullscreen',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
