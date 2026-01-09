import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../providers/websocket_provider.dart';
import '../providers/camera_devices_provider.dart';
import '../utils/responsive_helper.dart';
import '../models/camera_device.dart';
import '../models/conversion_item.dart';

class RecordingDownloadScreen extends StatefulWidget {
  const RecordingDownloadScreen({Key? key}) : super(key: key);

  @override
  State<RecordingDownloadScreen> createState() => _RecordingDownloadScreenState();
}

class _RecordingDownloadScreenState extends State<RecordingDownloadScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  String? _selectedCameraName;
  DateTime _startDate = DateTime.now().subtract(const Duration(hours: 1));
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _endTime = TimeOfDay.now();
  String _selectedFormat = 'mp4';
  String? _selectedTargetSlaveMac;
  
  bool _isLoading = false;
  
  // Conversions data
  ConversionsResponse? _conversionsData;
  bool _isLoadingConversions = false;
  
  // Pending conversion tracking
  bool _isPendingConversion = false;
  String _pendingConversionCamera = '';
  String _pendingConversionStartTime = ''; // To match the correct conversion request
  String _pendingConversionEndTime = '';   // To match the correct conversion request
  String _pendingConversionStatus = '';
  Timer? _conversionPollingTimer;
  int _pollingAttempts = 0;
  static const int _maxPollingAttempts = 30; // 30 * 10s = 5 minutes max
  
  // Available formats
  final List<String> _formats = ['mp4', 'avi', 'mkv', 'mov'];
  
  @override
  void initState() {
    super.initState();
    // Load conversions when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversions();
    });
  }
  
  @override
  void dispose() {
    _conversionPollingTimer?.cancel();
    super.dispose();
  }
  
  // Start polling for conversion completion
  void _startConversionPolling(String cameraName, String targetSlaveMac, String startTime, String endTime) {
    // Cancel any existing timer
    _conversionPollingTimer?.cancel();
    _pollingAttempts = 0;
    
    setState(() {
      _isPendingConversion = true;
      _pendingConversionCamera = cameraName;
      _pendingConversionStartTime = startTime;
      _pendingConversionEndTime = endTime;
      _pendingConversionStatus = 'Converting... (checking every 10 seconds)';
    });
    
    print('[Conversions] Starting polling for $cameraName on device $targetSlaveMac (start: $startTime, end: $endTime)');
    
    // Poll every 10 seconds
    _conversionPollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      _pollingAttempts++;
      print('[Conversions] Polling attempt $_pollingAttempts/$_maxPollingAttempts for $cameraName');
      
      setState(() {
        _pendingConversionStatus = 'Converting... (attempt $_pollingAttempts/$_maxPollingAttempts)';
      });
      
      // Check if max attempts reached
      if (_pollingAttempts >= _maxPollingAttempts) {
        timer.cancel();
        setState(() {
          _isPendingConversion = false;
          _pendingConversionStatus = '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversion timeout. Please check manually.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Reload conversions to check status
      await _loadConversions();
      
      // Check if the file is ready (file_path is not empty)
      // We need to match by camera name AND start/end time to find the correct conversion
      if (_conversionsData != null) {
        for (final entry in _conversionsData!.data.entries) {
          final deviceMac = entry.key;
          final conversions = entry.value;
          if (conversions != null && deviceMac == targetSlaveMac) {
            for (final conversion in conversions) {
              if (conversion.cameraName == cameraName) {
                // Check if start/end times match (normalize the format for comparison)
                // Server returns format like: 2026-01-09T01:15:00+03:00
                // We sent format like: 2026-01-09_01-15-00
                final serverStartNormalized = _normalizeTimeForComparison(conversion.startTime);
                final serverEndNormalized = _normalizeTimeForComparison(conversion.endTime);
                final requestStartNormalized = _normalizeTimeForComparison(startTime);
                final requestEndNormalized = _normalizeTimeForComparison(endTime);
                
                print('[Conversions] Checking conversion: server($serverStartNormalized-$serverEndNormalized) vs request($requestStartNormalized-$requestEndNormalized)');
                
                if (serverStartNormalized == requestStartNormalized && serverEndNormalized == requestEndNormalized) {
                  if (conversion.filePath.isNotEmpty) {
                    // File is ready!
                    timer.cancel();
                    setState(() {
                      _isPendingConversion = false;
                      _pendingConversionStatus = '';
                    });
                    print('[Conversions] File ready for $cameraName: ${conversion.filePath}');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Conversion complete for $cameraName! File is ready for download.'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                    // Refresh the list to show updated file path
                    _loadConversions();
                    return;
                  } else {
                    print('[Conversions] File not ready yet for $cameraName (file_path is empty)');
                  }
                }
              }
            }
          }
        }
      }
    });
  }
  
  // Normalize time format for comparison (extract just the datetime part)
  String _normalizeTimeForComparison(String time) {
    // Handle server format: 2026-01-09T01:15:00+03:00 -> 2026-01-09_01-15-00
    // Handle request format: 2026-01-09_01-15-00 -> 2026-01-09_01-15-00
    String normalized = time
        .replaceAll('T', '_')
        .replaceAll(':', '-')
        .split('+').first  // Remove timezone
        .split('.').first; // Remove milliseconds if any
    return normalized;
  }
  
  Future<void> _loadConversions() async {
    setState(() {
      _isLoadingConversions = true;
    });
    
    try {
      final webSocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
      
      // Send conversions command
      print('[Conversions] Sending conversions request');
      final success = await webSocketProvider.sendCommand('conversions');
      
      if (success) {
        print('[Conversions] Conversions request sent successfully');
        
        // Wait a bit for response and check
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Check if we got a response using dedicated conversions response
        final conversionsMessage = webSocketProvider.lastConversionsResponse;
        if (conversionsMessage != null) {
          print('[Conversions] Parsing conversions response');
          try {
            final conversionsResponse = ConversionsResponse.fromJson(conversionsMessage);
            setState(() {
              _conversionsData = conversionsResponse;
              print('[Conversions] Parsed ${_conversionsData!.data.length} device(s)');
            });
          } catch (e) {
            print('[Conversions] Error parsing conversions response: $e');
          }
        } else {
          print('[Conversions] No conversions response received');
        }
      } else {
        print('[Conversions] Failed to send conversions request');
      }
      
    } catch (e) {
      print('[Conversions] Error loading conversions: $e');
    } finally {
      setState(() {
        _isLoadingConversions = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Download'),
        automaticallyImplyLeading: false, // Geri tuşunu kaldır
      ),
      body: Consumer2<CameraDevicesProviderOptimized, WebSocketProviderOptimized>(
        builder: (context, cameraProvider, webSocketProvider, child) {
          // Only include cameras with MAC address and remove duplicates
          final allCamerasWithMac = cameraProvider.allCameras
              .where((camera) => camera.mac.isNotEmpty)
              .toList();
          
          // Remove duplicate cameras (same MAC address)
          final Map<String, Camera> uniqueCamerasByMac = {};
          for (var camera in allCamerasWithMac) {
            if (!uniqueCamerasByMac.containsKey(camera.mac)) {
              uniqueCamerasByMac[camera.mac] = camera;
            }
          }
          final cameras = uniqueCamerasByMac.values.toList();
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pending Conversion Indicator
                  if (_isPendingConversion)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '⏳ Conversion in Progress',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_pendingConversionCamera ($_pendingConversionStartTime → $_pendingConversionEndTime)',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    _pendingConversionStatus,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () {
                                _conversionPollingTimer?.cancel();
                                setState(() {
                                  _isPendingConversion = false;
                                  _pendingConversionStatus = '';
                                });
                              },
                              tooltip: 'Cancel waiting',
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_isPendingConversion) const SizedBox(height: 12),
                  
                  // Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Convert & Download Recording',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select a camera, time range, and format to convert and download recordings.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Camera Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Camera Selection',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          _buildGroupedCameraDropdown(cameras, cameraProvider),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Time Range Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time Range',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          
                          // Start Date and Time
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  label: 'Start Date',
                                  date: _startDate,
                                  onDateSelected: (date) {
                                    setState(() {
                                      _startDate = date;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTimeField(
                                  label: 'Start Time',
                                  time: _startTime,
                                  onTimeSelected: (time) {
                                    setState(() {
                                      _startTime = time;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // End Date and Time
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  label: 'End Date',
                                  date: _endDate,
                                  onDateSelected: (date) {
                                    setState(() {
                                      _endDate = date;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTimeField(
                                  label: 'End Time',
                                  time: _endTime,
                                  onTimeSelected: (time) {
                                    setState(() {
                                      _endTime = time;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Format Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conversion Settings',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          
                          // Format Selection
                          DropdownButtonFormField<String>(
                            value: _selectedFormat,
                            decoration: const InputDecoration(
                              labelText: 'Output Format',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.video_file),
                            ),
                            items: _formats.map((format) {
                              return DropdownMenuItem<String>(
                                value: format,
                                child: Text(format.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedFormat = value!;
                              });
                            },
                          ),
                          // Target Device is auto-selected based on camera selection
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Convert Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _convertRecording,
                      icon: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.transform),
                      label: Text(_isLoading ? 'Converting...' : 'Start Conversion'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Conversion Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Conversion time depends on the recording length and selected format\n'
                            '• The converted file will be available for download after completion\n'
                            '• Make sure the target device has sufficient storage space\n'
                            '• MP4 format is recommended for better compatibility',
                            style: TextStyle(color: Colors.blue[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Conversions Section
                  _buildConversionsSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDateField({
    required String label,
    required DateTime date,
    required Function(DateTime) onDateSelected,
  }) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      controller: TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(date),
      ),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
        );
        if (pickedDate != null) {
          onDateSelected(pickedDate);
        }
      },
    );
  }
  
  Widget _buildTimeField({
    required String label,
    required TimeOfDay time,
    required Function(TimeOfDay) onTimeSelected,
  }) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.access_time),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      controller: TextEditingController(
        text: time.format(context),
      ),
      onTap: () async {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (pickedTime != null) {
          onTimeSelected(pickedTime);
        }
      },
    );
  }
  
  void _convertRecording() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final webSocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
      
      // Combine date and time for start and end
      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      
      final endDateTime = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );
      
      // Validate time range
      if (endDateTime.isBefore(startDateTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End time must be after start time'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Format datetime to string (adjust format as needed by server)
      final startFormatted = DateFormat('yyyy-MM-dd_HH-mm-ss').format(startDateTime);
      final endFormatted = DateFormat('yyyy-MM-dd_HH-mm-ss').format(endDateTime);
      
      // Get camera provider to find the selected camera
      final cameraProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
      final cameras = cameraProvider.allCameras;
      
      // Find the selected camera to get its MAC address
      Camera? selectedCamera;
      try {
        selectedCamera = cameras.firstWhere(
          (camera) => (camera.name.isNotEmpty ? camera.name : camera.mac) == _selectedCameraName!,
        );
      } catch (e) {
        selectedCamera = cameras.isNotEmpty ? cameras.first : null;
      }
      
      if (selectedCamera == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected camera not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Send conversion request with camera name
      final success = await webSocketProvider.sendConvertRecording(
        cameraName: selectedCamera.name.isNotEmpty ? selectedCamera.name : selectedCamera.mac,
        startTime: startFormatted,
        endTime: endFormatted,
        format: _selectedFormat,
        targetSlaveMac: _selectedTargetSlaveMac!,
      );
      
      if (success) {
        final cameraName = selectedCamera.name.isNotEmpty ? selectedCamera.name : selectedCamera.mac;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion request sent for $cameraName. Waiting for file to be ready...'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Start polling for conversion completion (pass start/end time for correct matching)
        _startConversionPolling(cameraName, _selectedTargetSlaveMac!, startFormatted, endFormatted);
        
        // Refresh conversions list
        _loadConversions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send conversion request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Build grouped camera dropdown with camera groups only
  Widget _buildGroupedCameraDropdown(List<Camera> cameras, CameraDevicesProviderOptimized cameraProvider) {
    // Group cameras by camera groups only
    final Map<String, List<Camera>> camerasByGroup = {};
    
    // Get camera groups
    final cameraGroups = cameraProvider.cameraGroupsList;
    print('[RecordingDownload] Camera groups count: ${cameraGroups.length}');
    print('[RecordingDownload] Total cameras: ${cameras.length}');
    
    // Group cameras by camera groups first
    Set<String> groupedCameraIds = {};
    if (cameraGroups.isNotEmpty) {
      for (final group in cameraGroups) {
        final camerasInGroup = cameraProvider.getCamerasInGroup(group.name);
        print('[RecordingDownload] Group "${group.name}" has ${camerasInGroup.length} cameras');
        if (camerasInGroup.isNotEmpty) {
          camerasByGroup[group.name] = camerasInGroup;
          for (final camera in camerasInGroup) {
            groupedCameraIds.add(camera.id);
          }
        }
      }
    }
    
    // Find ungrouped cameras (not assigned to any group)
    final ungroupedCameras = cameras.where((camera) => !groupedCameraIds.contains(camera.id)).toList();
    
    // Build dropdown items
    List<DropdownMenuItem<String>> items = [];
    
    // Add camera groups
    camerasByGroup.forEach((groupName, camerasInGroup) {
      // Add group header
      items.add(DropdownMenuItem<String>(
        value: null,
        enabled: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.group_work, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                groupName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ));
      
      // Add cameras in this group
      for (var camera in camerasInGroup) {
        items.add(DropdownMenuItem<String>(
          value: camera.name.isNotEmpty ? camera.name : camera.mac,
          child: Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              camera.name.isNotEmpty 
                ? '${camera.name} (${camera.mac})'
                : camera.mac,
            ),
          ),
        ));
      }
    });
    
    // Add ungrouped cameras if any exist
    if (ungroupedCameras.isNotEmpty) {
      // Add ungrouped cameras header
      items.add(DropdownMenuItem<String>(
        value: null,
        enabled: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: const Row(
            children: [
              Icon(Icons.videocam_off_outlined, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'Ungrouped Cameras',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ));
      
      // Add ungrouped cameras
      for (var camera in ungroupedCameras) {
        items.add(DropdownMenuItem<String>(
          value: camera.name.isNotEmpty ? camera.name : camera.mac,
          child: Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              camera.name.isNotEmpty 
                ? '${camera.name} (${camera.mac})'
                : camera.mac,
            ),
          ),
        ));
      }
    }
    
    return DropdownButtonFormField<String>(
      value: _selectedCameraName,
      decoration: const InputDecoration(
        labelText: 'Select Camera',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.videocam),
        helperText: 'Cameras grouped by Groups and Devices',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a camera';
        }
        return null;
      },
      items: items,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCameraName = value;
            
            // Auto-select the target device for the selected camera
            // Find the camera by name or MAC
            Camera? selectedCamera;
            try {
              selectedCamera = cameras.firstWhere(
                (camera) => (camera.name.isNotEmpty ? camera.name : camera.mac) == value,
              );
            } catch (e) {
              // Camera not found
              selectedCamera = null;
            }
            
            // Find the device that contains this camera
            if (selectedCamera != null) {
              final deviceForCamera = cameraProvider.findDeviceForCamera(selectedCamera);
              if (deviceForCamera != null) {
                _selectedTargetSlaveMac = deviceForCamera.macKey;
              }
            }
          });
        }
      },
    );
  }
  
  Widget _buildConversionsSection() {
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Conversions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadConversions,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            
            if (_isLoadingConversions)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_conversionsData == null || _conversionsData!.data.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No active conversions',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._buildConversionsList(),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildConversionsList() {
    final widgets = <Widget>[];
    final cameraProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    _conversionsData!.data.forEach((macAddress, conversions) {
      if (conversions != null && conversions.isNotEmpty) {
        // Find device by MAC address
        final device = cameraProvider.devices.values.firstWhere(
          (d) => d.macAddress == macAddress,
          orElse: () => cameraProvider.devices.values.first,
        );
        
        widgets.add(
          ExpansionTile(
            title: Text('Device: $macAddress'),
            subtitle: Text('${conversions.length} conversion(s)'),
            initiallyExpanded: true,
            children: conversions.map((conversion) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: const Icon(Icons.video_file, color: Colors.blue),
                  ),
                  title: Text(conversion.cameraName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Format: ${conversion.format.toUpperCase()}'),
                      Text('Start: ${_formatTime(conversion.startTime)}'),
                      Text('End: ${_formatTime(conversion.endTime)}'),
                      Text(
                        'File: ${conversion.filePath.split('/').last}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        tooltip: 'İzle',
                        onPressed: () => _playConversion(conversion, device.ipv4),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        tooltip: 'İndir',
                        onPressed: () => _downloadConversion(conversion, device.ipv4),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }
    });
    
    return widgets;
  }
  
  String _formatTime(String isoTime) {
    try {
      final dateTime = DateTime.parse(isoTime);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (e) {
      return isoTime;
    }
  }

  Future<void> _downloadConversion(ConversionItem conversion, String deviceIp) async {
    try {
      // Extract camera name, date folder and filename from file path
      // Example path: /mnt/sda/Rec/KAMERA91/2025-10-05/filename.mp4
      final pathParts = conversion.filePath.split('/');
      if (pathParts.length < 3) {
        throw Exception('Invalid file path format');
      }
      
      // Get the camera name (third to last), date folder (second to last) and filename (last part)
      final filename = pathParts.last;
      final dateFolder = pathParts[pathParts.length - 2];
      final cameraName = pathParts[pathParts.length - 3];
      
      // Construct download URL: ip:8080/Rec/CAMERA/date/filename
      final url = 'http://$deviceIp:8080/Rec/$cameraName/$dateFolder/$filename';
      
      print('Downloading conversion from: $url');
      
      // Get Downloads directory
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Could not find Downloads directory');
      }
      
      // Create unique filename if file already exists
      String savePath = '${downloadsDir.path}/$filename';
      int counter = 1;
      while (File(savePath).existsSync()) {
        final nameWithoutExt = filename.substring(0, filename.lastIndexOf('.'));
        final ext = filename.substring(filename.lastIndexOf('.'));
        savePath = '${downloadsDir.path}/${nameWithoutExt}_$counter$ext';
        counter++;
      }
      
      // Download the file
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
      
      print('File saved to: $savePath');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File downloaded to Downloads folder: $filename'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () async {
              if (Platform.isMacOS) {
                await Process.run('open', ['-R', savePath]);
              }
            },
          ),
        ),
      );
    } catch (e) {
      print('Download error: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _playConversion(ConversionItem conversion, String deviceIp) {
    try {
      // Extract camera name, date folder and filename from file path
      final pathParts = conversion.filePath.split('/');
      if (pathParts.length < 3) {
        throw Exception('Invalid file path format');
      }
      
      final filename = pathParts.last;
      final dateFolder = pathParts[pathParts.length - 2];
      final cameraName = pathParts[pathParts.length - 3];
      
      // Construct video URL
      final videoUrl = 'http://$deviceIp:8080/Rec/$cameraName/$dateFolder/$filename';
      
      print('Playing conversion from: $videoUrl');
      
      // Show video player dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Container(
            width: 800,
            height: 600,
            child: Column(
              children: [
                AppBar(
                  title: Text(conversion.cameraName),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: _buildVideoPlayer(videoUrl),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('Play error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildVideoPlayer(String videoUrl) {
    return _ConversionVideoPlayer(videoUrl: videoUrl);
  }
}

// Simple video player widget for conversions
class _ConversionVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _ConversionVideoPlayer({required this.videoUrl});

  @override
  State<_ConversionVideoPlayer> createState() => _ConversionVideoPlayerState();
}

class _ConversionVideoPlayerState extends State<_ConversionVideoPlayer> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    
    // Load and play the video
    player.open(Media(widget.videoUrl));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: controller,
      controls: MaterialVideoControls,
    );
  }
}