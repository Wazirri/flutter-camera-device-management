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
import '../providers/conversion_tracking_provider.dart';
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
  
  @override
  void dispose() {
    super.dispose();
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
        
        // Wait a bit for response and check - reduced delay
        await Future.delayed(const Duration(milliseconds: 200));
        
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
      body: Consumer3<CameraDevicesProviderOptimized, WebSocketProviderOptimized, ConversionTrackingProvider>(
        builder: (context, cameraProvider, webSocketProvider, trackingProvider, child) {
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
          final pendingConversions = trackingProvider.pendingConversions.where((c) => !c.isComplete).toList();
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pending Conversions Indicator (from global provider)
                  if (pendingConversions.isNotEmpty)
                    Card(
                      color: Colors.orange.shade100,
                      elevation: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade400, width: 2),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade600,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '🔄 ${pendingConversions.length} Dönüştürme Devam Ediyor',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...pendingConversions.map((conversion) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Icon(Icons.videocam, size: 18, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          conversion.cameraName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                        Text(
                                          '${conversion.startTime} → ${conversion.endTime}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                        Text(
                                          conversion.status,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.cancel, color: Colors.red.shade400, size: 20),
                                    onPressed: () => trackingProvider.stopTracking(conversion),
                                    tooltip: 'Takibi Durdur',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  if (pendingConversions.isNotEmpty) const SizedBox(height: 16),
                  
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
                  _buildConversionsSection(trackingProvider),
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
            content: Text('$cameraName için dönüştürme isteği gönderildi...'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Start tracking with global provider (continues across page changes)
        final trackingProvider = Provider.of<ConversionTrackingProvider>(context, listen: false);
        trackingProvider.startTracking(
          cameraName: cameraName,
          targetSlaveMac: _selectedTargetSlaveMac!,
          startTime: startFormatted,
          endTime: endFormatted,
          format: _selectedFormat,
        );
        
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
    // Get camera groups
    final cameraGroups = cameraProvider.cameraGroupsList;
    
    // Group cameras by camera groups
    final Map<String, List<Camera>> camerasByGroup = {};
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
    
    // Find ungrouped cameras
    final ungroupedCameras = cameras.where((camera) => !groupedCameraIds.contains(camera.id)).toList();
    
    // Build list of all cameras with their group info for display
    // Using a custom widget instead of DropdownButtonFormField to allow duplicates
    final List<_CameraMenuItem> menuItems = [];
    
    // Add camera groups
    camerasByGroup.forEach((groupName, camerasInGroup) {
      // Add group header
      menuItems.add(_CameraMenuItem(isHeader: true, groupName: groupName));
      
      // Add cameras in this group
      for (var camera in camerasInGroup) {
        menuItems.add(_CameraMenuItem(
          camera: camera,
          groupName: groupName,
        ));
      }
    });
    
    // Add ungrouped cameras
    if (ungroupedCameras.isNotEmpty) {
      menuItems.add(_CameraMenuItem(isHeader: true, groupName: 'Grupsuz', isUngrouped: true));
      
      for (var camera in ungroupedCameras) {
        menuItems.add(_CameraMenuItem(camera: camera, groupName: 'Grupsuz'));
      }
    }
    
    return InkWell(
      onTap: () => _showCameraSelectionDialog(menuItems, cameras, cameraProvider),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Kamera Seçin',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.videocam),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          errorText: _selectedCameraName == null && _formKey.currentState?.validate() == false 
              ? 'Lütfen bir kamera seçin' : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _selectedCameraName ?? 'Kamera seçin...',
                style: TextStyle(
                  fontSize: 14,
                  color: _selectedCameraName != null ? null : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
  
  void _showCameraSelectionDialog(List<_CameraMenuItem> menuItems, List<Camera> cameras, CameraDevicesProviderOptimized cameraProvider) {
    String searchQuery = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter items based on search query
          final filteredItems = searchQuery.isEmpty
              ? menuItems
              : menuItems.where((item) {
                  if (item.isHeader) {
                    // Keep header if any camera in that group matches
                    final groupName = item.groupName ?? '';
                    return menuItems.any((m) =>
                        !m.isHeader &&
                        m.groupName == groupName &&
                        (m.camera!.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                         m.camera!.mac.toLowerCase().contains(searchQuery.toLowerCase())));
                  }
                  final camera = item.camera!;
                  final cameraName = camera.name.isNotEmpty ? camera.name : camera.mac;
                  return cameraName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                         camera.mac.toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();
          
          return AlertDialog(
            title: const Text('Kamera Seçin'),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: 350,
              height: 450,
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Kamera ara...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setDialogState(() {
                                    searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  // Camera list
                  Expanded(
                    child: filteredItems.isEmpty
                        ? Center(
                            child: Text(
                              'Sonuç bulunamadı',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
              
              if (item.isHeader) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: item.isUngrouped ? Colors.grey[100] : Colors.blue[50],
                  child: Row(
                    children: [
                      Icon(
                        item.isUngrouped ? Icons.videocam_off : Icons.folder,
                        size: 18,
                        color: item.isUngrouped ? Colors.grey[600] : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.groupName ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item.isUngrouped ? Colors.grey[700] : Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              final camera = item.camera!;
              final cameraName = camera.name.isNotEmpty ? camera.name : camera.mac;
              final isSelected = _selectedCameraName == cameraName;
              
              return ListTile(
                dense: true,
                selected: isSelected,
                selectedTileColor: Colors.blue[100],
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: Icon(
                  Icons.videocam,
                  size: 20,
                  color: isSelected ? Colors.blue : Colors.grey,
                ),
                title: Text(
                  cameraName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  camera.mac,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () {
                  setState(() {
                    _selectedCameraName = cameraName;
                    
                    // Find the device for this camera
                    Camera? selectedCamera;
                    try {
                      selectedCamera = cameras.firstWhere(
                        (c) => (c.name.isNotEmpty ? c.name : c.mac) == cameraName,
                      );
                    } catch (e) {
                      selectedCamera = null;
                    }
                    
                    if (selectedCamera != null) {
                      final deviceForCamera = cameraProvider.findDeviceForCamera(selectedCamera);
                      if (deviceForCamera != null) {
                        _selectedTargetSlaveMac = deviceForCamera.macKey;
                      }
                    }
                  });
                  Navigator.of(context).pop();
                },
              );
            },
          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildConversionsSection(ConversionTrackingProvider trackingProvider) {
    // Use trackingProvider.conversionsData which is updated by polling
    final conversionsData = trackingProvider.conversionsData ?? _conversionsData;
    
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
                Row(
                  children: [
                    if (trackingProvider.hasPendingConversions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        _loadConversions();
                        trackingProvider.refreshConversions();
                      },
                      tooltip: 'Refresh',
                    ),
                  ],
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
            else if (conversionsData == null || conversionsData.data.isEmpty)
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
              ..._buildConversionsList(conversionsData),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildConversionsList(ConversionsResponse conversionsData) {
    final widgets = <Widget>[];
    final cameraProvider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    // Group conversions by camera name instead of device MAC
    final Map<String, List<MapEntry<String, ConversionItem>>> conversionsByCamera = {};
    
    conversionsData.data.forEach((macAddress, conversions) {
      if (conversions != null && conversions.isNotEmpty) {
        for (final conversion in conversions) {
          final cameraName = conversion.cameraName;
          if (!conversionsByCamera.containsKey(cameraName)) {
            conversionsByCamera[cameraName] = [];
          }
          conversionsByCamera[cameraName]!.add(MapEntry(macAddress, conversion));
        }
      }
    });
    
    // Sort camera names
    final sortedCameraNames = conversionsByCamera.keys.toList()..sort();
    
    // Build widgets for each camera
    for (final cameraName in sortedCameraNames) {
      final cameraConversions = conversionsByCamera[cameraName]!;
      
      widgets.add(
        ExpansionTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.videocam, color: Colors.white, size: 20),
          ),
          title: Text(cameraName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${cameraConversions.length} kayıt'),
          initiallyExpanded: true,
          children: cameraConversions.map((entry) {
            final macAddress = entry.key;
            final conversion = entry.value;
            
            // Find device by MAC address for IP
            final device = cameraProvider.devices.values.firstWhere(
              (d) => d.macAddress == macAddress,
              orElse: () => cameraProvider.devices.values.first,
            );
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: const Icon(Icons.video_file, color: Colors.green),
                ),
                title: Text(
                  conversion.filePath.split('/').last,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTime(conversion.startTime)} - ${_formatTime(conversion.endTime).split(' ').last}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.video_settings, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          conversion.format.toUpperCase(),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: Colors.blue),
                      tooltip: 'İzle',
                      onPressed: () => _playConversion(conversion, device.ipv4),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.green),
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
    
    return widgets;
  }
  
  String _formatTime(String isoTime) {
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
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

// Helper class for camera menu items
class _CameraMenuItem {
  final bool isHeader;
  final bool isUngrouped;
  final String? groupName;
  final Camera? camera;

  _CameraMenuItem({
    this.isHeader = false,
    this.isUngrouped = false,
    this.groupName,
    this.camera,
  });
}