import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/websocket_provider_optimized.dart';
import '../providers/camera_devices_provider_optimized.dart';
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
        
        // Check if we got a response
        final lastMessage = webSocketProvider.lastMessage;
        if (lastMessage != null && lastMessage is Map<String, dynamic>) {
          final command = lastMessage['c'];
          if (command == 'conversions') {
            print('[Conversions] Parsing conversions response');
            try {
              final conversionsResponse = ConversionsResponse.fromJson(lastMessage);
              setState(() {
                _conversionsData = conversionsResponse;
                print('[Conversions] Parsed ${_conversionsData!.data.length} device(s)');
              });
            } catch (e) {
              print('[Conversions] Error parsing conversions response: $e');
            }
          }
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
          final devices = cameraProvider.devicesList;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  
                  // Format and Target Device Selection
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
                          
                          Row(
                            children: [
                              // Format Selection
                              Expanded(
                                child: DropdownButtonFormField<String>(
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
                              ),
                              const SizedBox(width: 16),
                              
                              // Target Device Selection
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedTargetSlaveMac,
                                  decoration: const InputDecoration(
                                    labelText: 'Target Device',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.devices),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a target device';
                                    }
                                    return null;
                                  },
                                  items: devices.map((device) {
                                    return DropdownMenuItem<String>(
                                      value: device.macKey,
                                      child: Text(
                                        device.deviceName?.isNotEmpty == true 
                                          ? '${device.deviceName} (${device.macAddress})'
                                          : device.macAddress,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTargetSlaveMac = value;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversion request sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
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
    
    // Group cameras by camera groups first
    Set<String> groupedCameraIds = {};
    if (cameraGroups.isNotEmpty) {
      for (final group in cameraGroups) {
        final camerasInGroup = cameraProvider.getCamerasInGroup(group.name);
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
    
    _conversionsData!.data.forEach((macAddress, conversions) {
      if (conversions != null && conversions.isNotEmpty) {
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
                  trailing: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Download: ${conversion.filePath}'),
                        ),
                      );
                    },
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
}