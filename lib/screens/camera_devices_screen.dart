import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Added import for DateFormat

import '../models/camera_device.dart';
import '../providers/camera_devices_provider.dart';
import '../providers/websocket_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart'; // Fixed import for AppTheme
// Removed app_localizations import to fix build error

class CameraDevicesScreen extends StatefulWidget {
  const CameraDevicesScreen({Key? key}) : super(key: key);

  @override
  State<CameraDevicesScreen> createState() => _CameraDevicesScreenState();
}

class _CameraDevicesScreenState extends State<CameraDevicesScreen> {
  @override
  Widget build(BuildContext context) {
    // Removed Consumer<UserGroupProvider> that was showing dialog for every operation result
    // CLEARCAMS and SHMC have their own dedicated UI feedback (dialogs, snackbars)
    // Other operations are handled via SnackBar in main.dart
    return _buildMainScaffold(context);
  }
  
  Widget _buildMainScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Camera Devices'),
        backgroundColor: AppTheme.darkBackground,
      ),
      body: Consumer<CameraDevicesProviderOptimized>(
        builder: (context, provider, child) {
          final devices = provider.devicesList;
          
          if (devices.isEmpty) {
            return const Center(
              child: Text(
                'No camera devices found.\nMake sure you are connected to the server.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isSelected = provider.selectedDevice?.macKey == device.macKey;
              return DeviceCard(
                device: device,
                isSelected: isSelected,
                onTap: () {
                  provider.setSelectedDevice(device.macKey);
                  _showDeviceDetails(context, device);
                },
                onToggleSmartPlayer: (ctx, dev) => _toggleSmartPlayerService(dev, provider),
                onToggleRecorder: (ctx, dev) => _toggleRecorderService(dev, provider),
                onShowNetworkSettings: _showNetworkSettings,
                onAddCamera: _showAddCameraDialog,
              );
            },
          );
        },
      ),
    );
  }
  
  void _showDeviceDetails(BuildContext context, CameraDevice device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return DeviceDetailsSheet(
              device: device,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }
  
  void _toggleSmartPlayerService(CameraDevice device, CameraDevicesProviderOptimized cameraDevicesProvider) async {
    print('[Toggle] _toggleSmartPlayerService called for device: ${device.macAddress}');
    
    final newValue = !device.smartPlayerServiceOn;
    print('[Toggle] Current smartPlayerServiceOn: ${device.smartPlayerServiceOn}, newValue: $newValue');
    
    final actionText = newValue ? 'açmak' : 'kapatmak';
    final actionTitle = newValue ? 'Smart Player Aç' : 'Smart Player Kapat';
    final buttonText = newValue ? 'Aç' : 'Kapat';
    final iconData = newValue ? Icons.play_circle : Icons.stop_circle;
    final iconColor = newValue ? Colors.green : Colors.red;
    
    // Onay dialog'u göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Row(
          children: [
            Icon(iconData, color: iconColor, size: 28),
            const SizedBox(width: 8),
            Text(
              actionTitle,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          '${device.deviceName ?? device.macAddress} cihazında Smart Player servisini $actionText istiyor musunuz?',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(buttonText),
          ),
        ],
      ),
    );
    
    if (confirmed != true) {
      print('[Toggle] User cancelled smart player toggle');
      return;
    }
    
    // Progress dialog göster
    await _showServiceProgressDialog(
      context: context,
      device: device,
      serviceName: 'Smart Player',
      isEnabling: newValue,
      onSendCommand: () => cameraDevicesProvider.setSmartPlayerService(device.macAddress, newValue),
    );
  }
  
  void _toggleRecorderService(CameraDevice device, CameraDevicesProviderOptimized cameraDevicesProvider) async {
    print('[Toggle] _toggleRecorderService called for device: ${device.macAddress}');
    
    final newValue = !device.recorderServiceOn;
    print('[Toggle] Current recorderServiceOn: ${device.recorderServiceOn}, newValue: $newValue');
    
    bool clearCameras = false;
    
    // Recorder açılırken onay iste
    if (newValue) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: Row(
            children: [
              const Icon(Icons.fiber_manual_record, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Recorder Başlat',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            '${device.deviceName ?? device.macAddress} cihazında Recorder servisini başlatmak istiyor musunuz?\n\nBu işlem cihazın kayıt yapmasını başlatacaktır.',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Başlat'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) {
        print('[Toggle] User cancelled recorder start');
        return;
      }
    } else {
      // Recorder kapatılırken onay iste
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: AppTheme.darkSurface,
            title: Row(
              children: [
                const Icon(Icons.stop_circle, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Recorder Durdur',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${device.deviceName ?? device.macAddress} cihazında Recorder servisini durdurmak istiyor musunuz?',
                  style: TextStyle(color: Colors.grey.shade300),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: clearCameras,
                        onChanged: (value) {
                          setDialogState(() {
                            clearCameras = value ?? false;
                          });
                        },
                        activeColor: Colors.red,
                      ),
                      Expanded(
                        child: Text(
                          'Cihazdaki tüm kameraları da sil',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Durdur'),
              ),
            ],
          ),
        ),
      );
      
      if (confirmed != true) {
        print('[Toggle] User cancelled recorder stop');
        return;
      }
    }
    
    // Progress dialog göster
    await _showServiceProgressDialog(
      context: context,
      device: device,
      serviceName: 'Recorder',
      isEnabling: newValue,
      onSendCommand: () => cameraDevicesProvider.setRecorderService(device.macAddress, newValue),
    );
    
    // Eğer kameraları silme seçeneği seçildiyse CLEARCAMS komutunu gönder
    if (!newValue && clearCameras) {
      print('[Toggle] User requested to clear cameras after recorder stop');
      await _showClearCamsProgressDialog(context, device, cameraDevicesProvider);
    }
  }
  
  /// Generic service progress dialog for Recorder/Smart Player operations
  /// Shows single phase - command sent and immediately completes (no device response expected)
  Future<void> _showServiceProgressDialog({
    required BuildContext context,
    required CameraDevice device,
    required String serviceName,
    required bool isEnabling,
    required Future<void> Function() onSendCommand,
  }) async {
    final shortMac = device.macAddress.length > 8 
        ? '...${device.macAddress.substring(device.macAddress.length - 8)}' 
        : device.macAddress;
    
    final actionText = isEnabling ? 'Açılıyor' : 'Kapatılıyor';
    final completeText = isEnabling ? 'açıldı' : 'kapandı';
    final iconData = isEnabling ? Icons.play_circle : Icons.stop_circle;
    final iconColor = isEnabling ? Colors.green : Colors.red;
    
    bool commandSent = false;
    bool commandSuccess = false;
    String? errorMessage;
    
    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Send command on first build
            if (!commandSent) {
              commandSent = true;
              
              // Send command after dialog renders
              Future.delayed(const Duration(milliseconds: 100), () async {
                try {
                  await onSendCommand();
                  setDialogState(() {
                    commandSuccess = true;
                  });
                  
                  // Auto close after 1.5 seconds
                  Future.delayed(const Duration(milliseconds: 1500), () {
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  });
                } catch (e) {
                  setDialogState(() {
                    errorMessage = e.toString();
                  });
                }
              });
            }
            
            return AlertDialog(
              backgroundColor: AppTheme.darkSurface,
              title: Row(
                children: [
                  Icon(iconData, color: iconColor, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$serviceName $actionText',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        Text(
                          '[$shortMac]',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!commandSuccess && errorMessage == null) ...[
                    // Sending state
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Komut gönderiliyor...',
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                      ],
                    ),
                  ] else if (commandSuccess) ...[
                    // Success state
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$serviceName servisi $completeText!',
                              style: TextStyle(color: Colors.green.shade300),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (errorMessage != null) ...[
                    // Error state
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hata: $errorMessage',
                              style: TextStyle(color: Colors.red.shade300),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (commandSuccess)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Tamam'),
                  )
                else if (errorMessage != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Kapat'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('İptal'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
  
  Future<void> _showClearCamsProgressDialog(
    BuildContext context, 
    CameraDevice device, 
    CameraDevicesProviderOptimized cameraDevicesProvider
  ) async {
    final websocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
    final shortMac = device.macAddress.length > 8 
        ? '...${device.macAddress.substring(device.macAddress.length - 8)}' 
        : device.macAddress;
    
    bool phase1Complete = false;
    bool phase2Complete = false;
    
    // Store original callback
    final originalCallback = websocketProvider.onTwoPhaseNotification;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Set up callback to update dialog state ONLY - no snackbar popup
            websocketProvider.onTwoPhaseNotification = (phase, mac, message) {
              // Normalize MAC addresses for comparison
              final normalizedMac = mac.toUpperCase().replaceAll('-', ':');
              final normalizedDeviceMac = device.macAddress.toUpperCase().replaceAll('-', ':');
              
              print('[CLEARCAMS Dialog] Phase=$phase, mac=$mac, deviceMac=${device.macAddress}, match=${normalizedMac == normalizedDeviceMac}');
              
              if (normalizedMac == normalizedDeviceMac) {
                setDialogState(() {
                  if (phase == 1) {
                    phase1Complete = true;
                  } else if (phase == 2) {
                    phase2Complete = true;
                  }
                });
              }
              // Don't call original callback - dialog is showing progress instead
            };
            
            return AlertDialog(
              backgroundColor: AppTheme.darkSurface,
              title: Row(
                children: [
                  const Icon(Icons.delete_sweep, color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kameraları Temizle',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        Text(
                          '[$shortMac]',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Step 1
                  _buildProgressStep(
                    stepNumber: 1,
                    title: 'Komut Gönderiliyor',
                    subtitle: 'Mesaj başarılı şekilde iletildi',
                    isComplete: phase1Complete,
                    isActive: !phase1Complete,
                  ),
                  const SizedBox(height: 16),
                  // Step 2
                  _buildProgressStep(
                    stepNumber: 2,
                    title: 'Cihaz Onayı Bekleniyor',
                    subtitle: 'Cihaz kameraları sildi',
                    isComplete: phase2Complete,
                    isActive: phase1Complete && !phase2Complete,
                  ),
                ],
              ),
              actions: [
                if (phase2Complete)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () {
                      // Restore original callback
                      websocketProvider.onTwoPhaseNotification = originalCallback;
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Tamam'),
                  )
                else
                  TextButton(
                    onPressed: () {
                      // Restore original callback
                      websocketProvider.onTwoPhaseNotification = originalCallback;
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('İptal'),
                  ),
              ],
            );
          },
        );
      },
    );
    
    // Send the command after dialog is shown
    await cameraDevicesProvider.clearDeviceCameras(device.macAddress);
  }
  
  Widget _buildProgressStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isComplete,
    required bool isActive,
  }) {
    return Row(
      children: [
        // Step indicator
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isComplete 
                ? Colors.green 
                : isActive 
                    ? Colors.orange 
                    : Colors.grey.shade700,
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : isActive
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        '$stepNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 12),
        // Step content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isComplete || isActive ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                isComplete ? '✅ $subtitle' : subtitle,
                style: TextStyle(
                  color: isComplete 
                      ? Colors.green.shade300 
                      : Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showNetworkSettings(BuildContext context, CameraDevice device) {
    showDialog(
      context: context,
      builder: (context) => _NetworkSettingsDialog(device: device),
    );
  }
  
  void _showAddCameraDialog(BuildContext context, CameraDevice device) {
    final provider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    
    // Get all cameras - prioritize unassigned ones
    final allCameras = provider.cameras;
    
    // Separate assigned and unassigned cameras
    final unassignedCameras = allCameras.where((c) => 
      c.parentDeviceMacKey == null || c.parentDeviceMacKey!.isEmpty
    ).toList();
    final assignedCameras = allCameras.where((c) => 
      c.parentDeviceMacKey != null && c.parentDeviceMacKey!.isNotEmpty
    ).toList();
    
    // Combine: unassigned first, then assigned
    final sortedCameras = [...unassignedCameras, ...assignedCameras];
    
    // Build cameras by group map
    final Map<String, List<Camera>> camerasByGroup = {};
    for (final camera in allCameras) {
      if (camera.groups.isNotEmpty) {
        for (final groupName in camera.groups) {
          camerasByGroup.putIfAbsent(groupName, () => []);
          camerasByGroup[groupName]!.add(camera);
        }
      }
    }
    // Add "Grupsuz" category for cameras without groups
    final ungroupedCameras = allCameras.where((c) => c.groups.isEmpty).toList();
    if (ungroupedCameras.isNotEmpty) {
      camerasByGroup['📁 Grupsuz Kameralar'] = ungroupedCameras;
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) => _AddCameraSelectionDialog(
        device: device,
        cameras: sortedCameras,
        unassignedCount: unassignedCameras.length,
        camerasByGroup: camerasByGroup,
      ),
    );
  }
}

/// Dialog for selecting cameras to add to a device
class _AddCameraSelectionDialog extends StatefulWidget {
  final CameraDevice device;
  final List<Camera> cameras;
  final int unassignedCount;
  final Map<String, List<Camera>> camerasByGroup;
  
  const _AddCameraSelectionDialog({
    required this.device,
    required this.cameras,
    required this.unassignedCount,
    required this.camerasByGroup,
  });
  
  @override
  State<_AddCameraSelectionDialog> createState() => _AddCameraSelectionDialogState();
}

class _AddCameraSelectionDialogState extends State<_AddCameraSelectionDialog> with SingleTickerProviderStateMixin {
  final Set<String> _selectedCameraMacs = {};
  String _searchQuery = '';
  bool _isProcessing = false;
  int _processedCount = 0;
  String _currentProcessingMac = '';
  late TabController _tabController;
  final Set<String> _expandedGroups = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  List<Camera> get _filteredCameras {
    if (_searchQuery.isEmpty) return widget.cameras;
    final query = _searchQuery.toLowerCase();
    return widget.cameras.where((c) =>
      c.name.toLowerCase().contains(query) ||
      c.mac.toLowerCase().contains(query) ||
      c.ip.toLowerCase().contains(query) ||
      c.groups.any((g) => g.toLowerCase().contains(query))
    ).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface,
      title: Row(
        children: [
          const Icon(Icons.add_a_photo, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kamera Ekle'),
                Text(
                  widget.device.deviceType.isNotEmpty 
                    ? widget.device.deviceType 
                    : widget.device.macAddress,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (_selectedCameraMacs.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedCameraMacs.length} seçili',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Column(
          children: [
            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Kamera veya grup ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 8),
            // Tab bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.list, size: 16),
                        const SizedBox(width: 4),
                        const Text('Tümü', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder, size: 16),
                        const SizedBox(width: 4),
                        Text('Gruplar (${widget.camerasByGroup.length})', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: All cameras list
                  _buildAllCamerasList(),
                  // Tab 2: Grouped cameras
                  _buildGroupedCamerasList(),
                ],
              ),
            ),
            // Processing indicator
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _processedCount / _selectedCameraMacs.length,
                      backgroundColor: Colors.grey.shade700,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'İşleniyor: $_currentProcessingMac ($_processedCount/${_selectedCameraMacs.length})',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          onPressed: _isProcessing || _selectedCameraMacs.isEmpty 
            ? null 
            : _addSelectedCameras,
          child: Text(_isProcessing 
            ? 'İşleniyor...' 
            : 'Ekle (${_selectedCameraMacs.length})'),
        ),
      ],
    );
  }
  
  Widget _buildAllCamerasList() {
    final cameras = _filteredCameras;
    
    if (cameras.isEmpty) {
      return const Center(child: Text('Kamera bulunamadı'));
    }
    
    return Column(
      children: [
        // Info text
        if (widget.unassignedCount > 0 && _searchQuery.isEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '${widget.unassignedCount} atanmamış kamera',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: cameras.length,
            itemBuilder: (context, index) => _buildCameraListTile(cameras[index]),
          ),
        ),
      ],
    );
  }
  
  Widget _buildGroupedCamerasList() {
    // Filter groups based on search
    Map<String, List<Camera>> filteredGroups = {};
    
    if (_searchQuery.isEmpty) {
      filteredGroups = widget.camerasByGroup;
    } else {
      final query = _searchQuery.toLowerCase();
      for (final entry in widget.camerasByGroup.entries) {
        // Check if group name matches
        if (entry.key.toLowerCase().contains(query)) {
          filteredGroups[entry.key] = entry.value;
        } else {
          // Check if any camera in group matches
          final matchingCameras = entry.value.where((c) =>
            c.name.toLowerCase().contains(query) ||
            c.mac.toLowerCase().contains(query) ||
            c.ip.toLowerCase().contains(query)
          ).toList();
          if (matchingCameras.isNotEmpty) {
            filteredGroups[entry.key] = matchingCameras;
          }
        }
      }
    }
    
    if (filteredGroups.isEmpty) {
      return const Center(child: Text('Grup bulunamadı'));
    }
    
    final groupNames = filteredGroups.keys.toList()..sort();
    
    return ListView.builder(
      itemCount: groupNames.length,
      itemBuilder: (context, index) {
        final groupName = groupNames[index];
        final cameras = filteredGroups[groupName]!;
        final isExpanded = _expandedGroups.contains(groupName);
        final selectedInGroup = cameras.where((c) => _selectedCameraMacs.contains(c.mac)).length;
        
        return Card(
          color: Colors.grey.shade800,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              // Group header
              ListTile(
                dense: true,
                leading: Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  color: Colors.amber,
                ),
                title: Text(
                  groupName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${cameras.length} kamera${selectedInGroup > 0 ? ' • $selectedInGroup seçili' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: selectedInGroup > 0 ? Colors.green : Colors.grey,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Select all in group button
                    IconButton(
                      icon: Icon(
                        selectedInGroup == cameras.length 
                          ? Icons.check_box 
                          : (selectedInGroup > 0 ? Icons.indeterminate_check_box : Icons.check_box_outline_blank),
                        size: 20,
                        color: selectedInGroup > 0 ? Colors.green : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          final selectableCameras = cameras.where((c) => 
                            c.parentDeviceMacKey != widget.device.macAddress
                          ).toList();
                          
                          if (selectedInGroup == selectableCameras.length) {
                            // Deselect all
                            for (final c in selectableCameras) {
                              _selectedCameraMacs.remove(c.mac);
                            }
                          } else {
                            // Select all
                            for (final c in selectableCameras) {
                              _selectedCameraMacs.add(c.mac);
                            }
                          }
                        });
                      },
                      tooltip: 'Tümünü seç/kaldır',
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey,
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedGroups.remove(groupName);
                    } else {
                      _expandedGroups.add(groupName);
                    }
                  });
                },
              ),
              // Cameras in group
              if (isExpanded)
                Container(
                  color: Colors.grey.shade900,
                  child: Column(
                    children: cameras.map((c) => _buildCameraListTile(c, inGroup: true)).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCameraListTile(Camera camera, {bool inGroup = false}) {
    final isSelected = _selectedCameraMacs.contains(camera.mac);
    final isUnassigned = camera.parentDeviceMacKey == null || 
                         camera.parentDeviceMacKey!.isEmpty;
    final isAlreadyOnThisDevice = camera.parentDeviceMacKey == widget.device.macAddress;
    
    return Card(
      color: isSelected 
        ? Colors.green.withOpacity(0.2) 
        : (isUnassigned ? Colors.grey.shade800 : Colors.grey.shade900),
      margin: EdgeInsets.symmetric(vertical: 2, horizontal: inGroup ? 8 : 0),
      child: ListTile(
        dense: true,
        enabled: !isAlreadyOnThisDevice,
        leading: Checkbox(
          value: isSelected,
          onChanged: isAlreadyOnThisDevice ? null : (value) {
            setState(() {
              if (value == true) {
                _selectedCameraMacs.add(camera.mac);
              } else {
                _selectedCameraMacs.remove(camera.mac);
              }
            });
          },
          activeColor: Colors.green,
        ),
        title: Text(
          camera.name.isNotEmpty ? camera.name : camera.mac,
          style: TextStyle(
            fontSize: 13,
            color: isAlreadyOnThisDevice ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MAC: ${camera.mac}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (camera.ip.isNotEmpty)
              Text(
                'IP: ${camera.ip}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            if (!inGroup && camera.groups.isNotEmpty)
              Wrap(
                spacing: 4,
                children: camera.groups.take(3).map((g) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    g,
                    style: const TextStyle(fontSize: 9, color: Colors.amber),
                  ),
                )).toList(),
              ),
            if (isAlreadyOnThisDevice)
              const Text(
                'Bu cihazda zaten var',
                style: TextStyle(fontSize: 10, color: Colors.orange),
              )
            else if (!isUnassigned)
              Text(
                'Mevcut cihaz: ${camera.parentDeviceMacKey}',
                style: const TextStyle(fontSize: 10, color: Colors.amber),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              camera.connected ? Icons.wifi : Icons.wifi_off,
              size: 16,
              color: camera.connected ? Colors.green : Colors.red,
            ),
            if (isUnassigned) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'YENİ',
                  style: TextStyle(fontSize: 8, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        onTap: isAlreadyOnThisDevice ? null : () {
          setState(() {
            if (_selectedCameraMacs.contains(camera.mac)) {
              _selectedCameraMacs.remove(camera.mac);
            } else {
              _selectedCameraMacs.add(camera.mac);
            }
          });
        },
      ),
    );
  }
  
  Future<void> _addSelectedCameras() async {
    if (_selectedCameraMacs.isEmpty) return;
    
    setState(() {
      _isProcessing = true;
      _processedCount = 0;
    });
    
    final provider = Provider.of<CameraDevicesProviderOptimized>(context, listen: false);
    final cameraMacList = _selectedCameraMacs.toList();
    
    for (int i = 0; i < cameraMacList.length; i++) {
      final cameraMac = cameraMacList[i];
      
      setState(() {
        _currentProcessingMac = cameraMac;
        _processedCount = i;
      });
      
      // ADD_CAM komutunu gönder ve bekle
      await provider.addCameraToDevice(cameraMac, widget.device.macAddress);
      
      // Her komut arasında kısa bir bekleme (sunucunun işlemesi için)
      if (i < cameraMacList.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    setState(() {
      _processedCount = cameraMacList.length;
      _isProcessing = false;
    });
    
    // Dialog'u kapat
    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class DeviceCard extends StatelessWidget {
  final CameraDevice device;
  final VoidCallback onTap;
  final bool isSelected;
  final Function(BuildContext, CameraDevice) onToggleSmartPlayer;
  final Function(BuildContext, CameraDevice) onToggleRecorder;
  final Function(BuildContext, CameraDevice) onShowNetworkSettings;
  final Function(BuildContext, CameraDevice) onAddCamera;

  const DeviceCard({
    Key? key,
    required this.device,
    required this.onTap,
    this.isSelected = false,
    required this.onToggleSmartPlayer,
    required this.onToggleRecorder,
    required this.onShowNetworkSettings,
    required this.onAddCamera,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('DeviceCard build START for ${device.macAddress}');

    // Access status via the getter, which now includes logging
    final currentStatus = device.status; 
    print('DeviceCard build: ${device.macAddress}, connected: ${device.connected}, online: ${device.online}, firstTime: ${device.firstTime}, status from getter: $currentStatus'); // MODIFIED
    
    final isMaster = device.isMaster == true;
    
    // Seçili offline cihaz için gri, online için altın sarısı/primary renk kullan
    final selectedBorderColor = device.connected 
        ? AppTheme.primaryColor.withOpacity(0.8)
        : Colors.grey.shade500;
    final selectedBackgroundColor = device.connected
        ? AppTheme.primaryColor.withOpacity(0.1)
        : Colors.grey.withOpacity(0.1);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isSelected ? 8 : (isMaster ? 6 : 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isMaster 
              ? Colors.amber
              : (isSelected 
                  ? selectedBorderColor
                  : (device.connected 
                      ? AppTheme.primaryColor
                      : Theme.of(context).dividerColor)),
          width: isMaster ? 3 : (isSelected ? 3 : (device.connected ? 2 : 1)),
        ),
      ),
      color: isMaster 
          ? Colors.amber.withOpacity(0.1)
          : (isSelected 
              ? selectedBackgroundColor
              : null),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (isMaster) ...[
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.deviceType.isEmpty 
                                    ? 'Device ${device.macAddress}' 
                                    : device.deviceType,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isMaster 
                                      ? Colors.amber 
                                      : (isSelected ? AppTheme.primaryColor : null),
                                ),
                              ),
                              if (isMaster)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'MASTER DEVICE',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: device.status == DeviceStatus.online 
                          ? AppTheme.primaryColor
                          : (device.status == DeviceStatus.warning ? Colors.orange : Colors.grey),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      // Use device.status to determine online/offline text
                      device.status == DeviceStatus.online ? 'Online' : 
                      (device.status == DeviceStatus.warning 
                          ? '${device.cameras.where((c) => !c.connected).length} Kamera Bağlı Değil' 
                          : 'Offline'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'MAC: ${device.macAddress}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'IP: ${device.ipv4}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              // Camera stats with text labels
              Builder(
                builder: (context) {
                  final onlineCount = device.cameras.where((c) => c.connected).length;
                  // Recording count: cameras that are recording on THIS device
                  final recordingOnThisDevice = device.cameras.where((c) => c.isRecordingOnDevice(device.macKey)).length;
                  
                  return Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Kameralar: ${device.cameras.length}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Çevrimiçi: $onlineCount',
                        style: TextStyle(
                          fontSize: 14,
                          color: onlineCount > 0 ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Kayıt: $recordingOnThisDevice',
                        style: TextStyle(
                          fontSize: 14,
                          color: recordingOnThisDevice > 0 ? Colors.red : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (device.uptime.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Uptime: ${device.formattedUptime}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              if (device.firmwareVersion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Firmware: ${device.firmwareVersion}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              // ADDED: Explicit display for device.online and device.connected
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    device.online ? Icons.power_settings_new : Icons.power_off,
                    color: device.online ? AppTheme.online : AppTheme.offline,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Powered: ${device.online ? "On" : "Off"}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.darkTextSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4), // Space between the two new rows
              Row(
                children: <Widget>[
                  Icon(
                    device.connected ? Icons.link : Icons.link_off,
                    color: device.connected ? AppTheme.online : AppTheme.offline,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connection: ${device.connected ? "Active" : "Inactive"}',
                    style: const TextStyle(fontSize: 14, color: AppTheme.darkTextSecondary),
                  ),
                ],
              ),
              // END ADDED
              const SizedBox(height: 8),
              // Service control toggles (Smart Player and Recorder)
              Row(
                children: [
                  // Smart Player Service toggle
                  Expanded(
                    child: InkWell(
                      onTap: () => onToggleSmartPlayer(context, device),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: device.smartPlayerServiceOn 
                              ? Colors.green.withOpacity(0.15)
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: device.smartPlayerServiceOn ? Colors.green : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  size: 16,
                                  color: device.smartPlayerServiceOn ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Player',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: device.smartPlayerServiceOn ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: device.smartPlayerServiceOn,
                              onChanged: (value) => onToggleSmartPlayer(context, device),
                              activeColor: Colors.green,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Recorder Service toggle
                  Expanded(
                    child: InkWell(
                      onTap: () => onToggleRecorder(context, device),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: device.recorderServiceOn 
                              ? Colors.orange.withOpacity(0.15)
                              : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: device.recorderServiceOn ? Colors.orange : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  device.recorderServiceOn ? Icons.fiber_manual_record : Icons.stop,
                                  size: 16,
                                  color: device.recorderServiceOn ? Colors.orange : Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Recorder',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: device.recorderServiceOn ? Colors.orange : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: device.recorderServiceOn,
                              onChanged: (value) => onToggleRecorder(context, device),
                              activeColor: Colors.orange,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Last seen: ${device.lastSeenAt}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 12),
              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Add Camera button
                  ElevatedButton.icon(
                    onPressed: () => onAddCamera(context, device),
                    icon: const Icon(Icons.add_a_photo, size: 18),
                    label: const Text('Kamera Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Settings button
                  ElevatedButton.icon(
                    onPressed: () => onShowNetworkSettings(context, device),
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Network Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceDetailsSheet extends StatelessWidget {
  final CameraDevice device;
  final ScrollController scrollController;

  const DeviceDetailsSheet({
    Key? key,
    required this.device,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('DeviceDetailsSheet build START for ${device.macAddress}');
    
    final currentStatus = device.status; // Access status via the getter
    print('DeviceDetailsSheet build: ${device.macAddress}, connected: ${device.connected}, online: ${device.online}, firstTime: ${device.firstTime}, status from getter: $currentStatus'); // MODIFIED

    return DefaultTabController(
      length: 5, // Beş tab için: ECS Slaves, Sistem, App, Test, Kameralar
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceType.isEmpty 
                            ? 'Device ${device.macAddress}' 
                            : device.deviceType,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'MAC: ${device.macAddress}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: device.status == DeviceStatus.online 
                        ? AppTheme.primaryColor
                        : (device.status == DeviceStatus.warning ? Colors.orange : Colors.grey),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    // Use device.status to determine online/offline text
                    device.status == DeviceStatus.online ? 'Online' : 
                    (device.status == DeviceStatus.warning 
                        ? '${device.cameras.where((c) => !c.connected).length} Kamera Bağlı Değil' 
                        : 'Offline'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Bar
          TabBar(
            isScrollable: true,
            tabs: const [
              Tab(
                icon: Icon(Icons.devices),
                text: 'ECS Slaves',
              ),
              Tab(
                icon: Icon(Icons.computer),
                text: 'Sistem',
              ),
              Tab(
                icon: Icon(Icons.settings),
                text: 'App',
              ),
              Tab(
                icon: Icon(Icons.bug_report),
                text: 'Test',
              ),
              Tab(
                icon: Icon(Icons.videocam_outlined),
                text: 'Kameralar',
              ),
            ],
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
          ),
          
          // Tab Bar View
          Expanded(
            child: TabBarView(
              children: [
                // ECS Slaves Tab
                _buildEcsSlavesTab(context),
                // Sistem Tab
                _buildSystemTab(context),
                // App Tab
                _buildAppTab(context),
                // Test Tab
                _buildTestTab(context),
                // Kameralar Tab
                _buildCamerasTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ECS Slaves Tab - Temel cihaz bilgileri
  Widget _buildEcsSlavesTab(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ECS Slaves Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Temel cihaz bilgileri
          InfoRow(label: 'Cihaz Adı', value: device.deviceName ?? 'Bilinmiyor'),
          InfoRow(label: 'IPv4 Adresi', value: device.ipv4),
          if (device.ipv6 != null && device.ipv6!.isNotEmpty)
            InfoRow(label: 'IPv6 Adresi', value: device.ipv6!),
          InfoRow(label: 'MAC Adresi', value: device.macAddress),
          InfoRow(label: 'İlk Görülme', value: device.firstTime),
          InfoRow(label: 'Son Görülme', value: device.lastSeenAt),
          InfoRow(label: 'Şu Anki Zaman', value: device.currentTime ?? 'Bilinmiyor'),
          InfoRow(label: 'Firmware Versiyonu', value: device.firmwareVersion),
          if (device.smartwebVersion != null && device.smartwebVersion!.isNotEmpty)
            InfoRow(label: 'SmartWeb Versiyonu', value: device.smartwebVersion!),
          InfoRow(
            label: 'CPU Sıcaklığı', 
            value: device.cpuTemp > 0 ? '${device.cpuTemp.toStringAsFixed(1)}°C' : 'Mevcut değil'
          ),
          InfoRow(label: 'Master Durumu', value: device.isMaster == true ? 'Master' : 'Slave'),
          InfoRow(label: 'Son Timestamp', value: device.lastTs ?? 'Bilinmiyor'),
          InfoRow(label: 'Kayıt Yolu', value: device.recordPath),
          InfoRow(label: 'Kamera Sayısı', value: '${device.camCount}'),
          
          // Ready States
          const SizedBox(height: 16),
          const Text(
            'Hazırlık Durumları',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusRow('App Hazır', device.appReady),
          _buildStatusRow('Sistem Hazır', device.systemReady),
          _buildStatusRow('Programlar Hazır', device.programsReady),
          _buildStatusRow('Kamera Hazır', device.camReady),
          _buildStatusRow('Konfigürasyon Hazır', device.configurationReady),
          _buildStatusRow('Kamera Raporları Hazır', device.camreportsReady),
          _buildStatusRow('Movita Hazır', device.movitaReady),
          
          // Cihaz durum bilgileri
          const SizedBox(height: 16),
          const Text(
            'Cihaz Durum Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusRow('Kayıtlı', device.registered),
          InfoRow(label: 'App Versiyonu', value: '${device.appVersion}'),
          InfoRow(label: 'Sistem Sayısı', value: '${device.systemCount}'),
          InfoRow(label: 'Kamera Raporları Sayısı', value: '${device.camreportsCount}'),
          InfoRow(label: 'Program Sayısı', value: '${device.programsCount}'),
          _buildStatusRow('Master Tarafından Kapatıldı', device.isClosedByMaster),
          InfoRow(label: 'Son Heartbeat', value: device.lastHeartbeatTs > 0 ? DateTime.fromMillisecondsSinceEpoch(device.lastHeartbeatTs * 1000).toString() : 'Bilinmiyor'),
          InfoRow(label: 'Offline Başlangıcı', value: device.offlineSince > 0 ? DateTime.fromMillisecondsSinceEpoch(device.offlineSince * 1000).toString() : 'Hiçbir zaman'),
        ],
      ),
    );
  }

  // Sistem Bilgileri Tab
  Widget _buildSystemTab(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sistem Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // System bilgileri
          if (device.systemMac != null)
            InfoRow(label: 'Sistem MAC', value: device.systemMac!),
          if (device.gateway != null)
            InfoRow(label: 'Gateway', value: device.gateway!),
          if (device.systemIp != null)
            InfoRow(label: 'Sistem IP', value: device.systemIp!),
          _buildStatusRow('GPS Durumu', device.gpsOk),
          _buildStatusRow('Kontak Durumu', device.ignition),
          _buildStatusRow('İnternet Bağlantısı', device.internetExists),
          InfoRow(label: 'Boot Sayısı', value: '${device.bootCount}'),
          if (device.diskFree != null)
            InfoRow(label: 'Disk Boş Alan', value: device.diskFree!),
          if (device.diskRunning != null)
            InfoRow(label: 'Disk Durumu', value: device.diskRunning!),
          InfoRow(label: 'Boş Alan (GB)', value: '${device.emptySize}'),
          InfoRow(label: 'Kayıt Boyutu (GB)', value: '${device.recordSize}'),
          InfoRow(label: 'Kayıt Durumu', value: '${device.recording}'),
          _buildStatusRow('SHMC Hazır', device.shmcReady),
          _buildStatusRow('Zaman Ayarlandı', device.timeset),
          _buildStatusRow('Uyku Modu', device.uykumodu),
          
          // RAM Bilgileri
          const SizedBox(height: 16),
          const Text(
            'RAM Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          InfoRow(
            label: 'Toplam RAM', 
            value: device.totalRam > 0 ? '${(device.totalRam / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB' : 'Mevcut değil'
          ),
          InfoRow(
            label: 'Boş RAM', 
            value: device.freeRam > 0 ? '${(device.freeRam / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB' : 'Mevcut değil'
          ),
          
          // Ağ Bilgileri
          const SizedBox(height: 16),
          const Text(
            'Ağ Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'Ağ Bilgileri', value: device.networkInfo ?? 'Bilinmiyor'),
          InfoRow(label: 'Toplam Bağlantı', value: '${device.totalConnections}'),
          InfoRow(label: 'Toplam Oturum', value: '${device.totalSessions}'),
        ],
      ),
    );
  }

  // App Bilgileri Tab
  Widget _buildAppTab(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uygulama Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // App konfigürasyonu
          if (device.appDeviceType != null)
            InfoRow(label: 'Cihaz Tipi', value: device.appDeviceType!),
          if (device.firmwareDate != null)
            InfoRow(label: 'Firmware Tarihi', value: device.firmwareDate!),
          if (device.appFirmwareVersion != null)
            InfoRow(label: 'App Firmware Versiyonu', value: device.appFirmwareVersion!),
          _buildStatusRow('GPS Veri Akışı', device.gpsDataFlowStatus),
          InfoRow(label: 'Grup', value: '${device.group}'),
          _buildStatusRow('İç Bağlantı', device.intConnection),
          if (device.isai != null)
            InfoRow(label: 'ISAI', value: device.isai!),
          if (device.libPath != null)
            InfoRow(label: 'Lib Yolu', value: device.libPath!),
          if (device.logPath != null)
            InfoRow(label: 'Log Yolu', value: device.logPath!),
          if (device.macAddressPath != null)
            InfoRow(label: 'MAC Adres Yolu', value: device.macAddressPath!),
          InfoRow(label: 'Maksimum Kayıt Süresi', value: '${device.maxRecordDuration} dk'),
          InfoRow(label: 'Minimum Alan (MB)', value: '${device.minSpaceInMBytes}'),
          if (device.movitabinPath != null)
            InfoRow(label: 'Movita Bin Yolu', value: device.movitabinPath!),
          if (device.movitarecPath != null)
            InfoRow(label: 'Movita Rec Yolu', value: device.movitarecPath!),
          if (device.netdev != null)
            InfoRow(label: 'Ağ Cihazı', value: device.netdev!),
          if (device.pinCode != null)
            InfoRow(label: 'PIN Kodu', value: device.pinCode!),
          _buildStatusRow('PPP', device.ppp),
          _buildStatusRow('TCP Üzerinden Kayıt', device.recordOverTcp),
          if (device.appRecordPath != null)
            InfoRow(label: 'App Kayıt Yolu', value: device.appRecordPath!),
          _buildStatusRow('App Kayıt Yapıyor', device.appRecording),
          InfoRow(label: 'Kayıt Yapan Kameralar', value: '${device.recordingCameras}'),
          InfoRow(label: 'Player Restart Timeout', value: '${device.restartPlayerTimeout}'),
          if (device.rp2040version != null)
            InfoRow(label: 'RP2040 Versiyonu', value: device.rp2040version!),
        ],
      ),
    );
  }

  // Test Bilgileri Tab
  Widget _buildTestTab(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Test Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Test uptime
          if (device.testUptime != null)
            InfoRow(label: 'Test Uptime', value: device.testUptime!),
          _buildStatusRow('Test Hatası Var', device.testIsError),
          
          // Bağlantı testleri
          const SizedBox(height: 16),
          const Text(
            'Bağlantı Testleri',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          InfoRow(label: 'Bağlantı Test Sayısı', value: '${device.testConnectionCount}'),
          if (device.testConnectionLastUpdate != null)
            InfoRow(label: 'Son Bağlantı Test Güncellemesi', value: device.testConnectionLastUpdate!),
          InfoRow(label: 'Bağlantı Test Hataları', value: '${device.testConnectionError}'),
          
          // Kamera bağlantı testleri
          const SizedBox(height: 16),
          const Text(
            'Kamera Bağlantı Testleri',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          InfoRow(label: 'Kamera Bağlantı Test Sayısı', value: '${device.testKameraBaglantiCount}'),
          if (device.testKameraBaglantiLastUpdate != null)
            InfoRow(label: 'Son Kamera Test Güncellemesi', value: device.testKameraBaglantiLastUpdate!),
          InfoRow(label: 'Kamera Bağlantı Test Hataları', value: '${device.testKameraBaglantiError}'),
          
          // Program testleri
          const SizedBox(height: 16),
          const Text(
            'Program Testleri',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          InfoRow(label: 'Program Test Sayısı', value: '${device.testProgramCount}'),
          if (device.testProgramLastUpdate != null)
            InfoRow(label: 'Son Program Test Güncellemesi', value: device.testProgramLastUpdate!),
          InfoRow(label: 'Program Test Hataları', value: '${device.testProgramError}'),
        ],
      ),
    );
  }

  // Kameralar Tab
  Widget _buildCamerasTab(BuildContext context) {
    // Calculate camera stats from camreports data
    final onlineCameras = device.cameras.where((c) => c.connected).length;
    // Recording count: cameras that are recording on THIS device specifically
    final recordingCameras = device.cameras.where((c) => c.isRecordingOnDevice(device.macKey)).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Camera count with online/recording stats
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    'Kameralar: ${device.cameras.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Çevrimiçi: $onlineCameras',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: onlineCameras > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
                  Text(
                    'Kayıt: $recordingCameras',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: recordingCameras > 0 ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
              if (device.cameras.isNotEmpty && device.connected)
                TextButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('Tümünü Görüntüle'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/live-view');
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: device.cameras.isEmpty
              ? const Center(
                  child: Text('Bu cihaz için kamera bulunamadı'),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: device.cameras.length,
                  itemBuilder: (context, index) {
                    final camera = device.cameras[index];
                    return CameraCard(
                      camera: camera,
                      deviceMac: device.macKey, // Pass device MAC for camReports recording check
                      onTap: () {
                        // Set the selected camera
                        Provider.of<CameraDevicesProviderOptimized>(context, listen: false)
                            .setSelectedCameraIndex(index);
                            
                        // Navigate to live view screen
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/live-view');
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Durum göstergesi satırı
  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ),
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status ? "Evet" : "Hayır",
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  
  const InfoRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return value.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
  }
}

class CameraCard extends StatelessWidget {
  final Camera camera;
  final VoidCallback onTap;
  final String? deviceMac; // Device MAC to check camReports recording info
  
  const CameraCard({
    Key? key,
    required this.camera,
    required this.onTap,
    this.deviceMac,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if we have camReports recording info for this device
    final hasRecordingInfo = deviceMac != null && camera.hasCamReportsRecordingInfo(deviceMac!);
    final isRecordingOnThisDevice = deviceMac != null && camera.isRecordingOnDevice(deviceMac!);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: camera.connected 
              ? (hasRecordingInfo && isRecordingOnThisDevice)
                  ? Colors.red
                  : AppTheme.accentColor
              : Theme.of(context).dividerColor,
          width: camera.connected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      camera.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Recording indicator - only show if camReports recording info exists for this device
                      if (hasRecordingInfo && isRecordingOnThisDevice)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.fiber_manual_record,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                camera.recordingCount > 1 
                                    ? 'REC (${camera.recordingCount})' 
                                    : 'REC',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: camera.connected 
                              ? AppTheme.accentColor 
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          camera.connected ? 'Online' : 'Offline',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'IP: ${camera.ip}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Model: ${camera.brand} ${camera.hw}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.videocam,
                    size: 16,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Resolution: ${camera.recordWidth}x${camera.recordHeight}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Last seen: ${camera.lastSeenAt}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Network Settings Dialog
class _NetworkSettingsDialog extends StatefulWidget {
  final CameraDevice device;

  const _NetworkSettingsDialog({required this.device});

  @override
  State<_NetworkSettingsDialog> createState() => _NetworkSettingsDialogState();
}

class _NetworkSettingsDialogState extends State<_NetworkSettingsDialog> {
  late TextEditingController _ipController;
  late TextEditingController _gatewayController;
  bool _useDHCP = false;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.device.ipv4);
    _gatewayController = TextEditingController(text: '192.168.1.1');
  }

  @override
  void dispose() {
    _ipController.dispose();
    _gatewayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface,
      title: Row(
        children: [
          const Icon(Icons.network_check, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          const Text(
            'Network Settings',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.devices, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.device.deviceType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MAC: ${widget.device.macAddress}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    'Current IP: ${widget.device.ipv4}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // IP Address
            TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintText: '192.168.1.10',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.computer, color: AppTheme.primaryBlue),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              
              // Gateway
              TextField(
                controller: _gatewayController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Gateway',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  hintText: '192.168.1.1',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.router, color: AppTheme.primaryBlue),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryBlue),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            
            const SizedBox(height: 16),
            
            // DHCP Server Toggle (for slave devices)
            CheckboxListTile(
              title: const Text(
                'Enable DHCP Server',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Distribute IP addresses to slave devices',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              value: _useDHCP,
              activeColor: AppTheme.primaryBlue,
              onChanged: (value) {
                setState(() {
                  _useDHCP = value ?? false;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Warning message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Device will restart and may temporarily disconnect',
                      style: TextStyle(color: Colors.orange[300], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _applyNetworkSettings,
          icon: const Icon(Icons.check),
          label: const Text('Apply'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _applyNetworkSettings() async {
    // Validate IP and Gateway (always required)
    if (_ipController.text.isEmpty) {
      AppSnackBar.warning(context, 'Please enter an IP address');
      return;
    }
    
    if (_gatewayController.text.isEmpty) {
      AppSnackBar.warning(context, 'Please enter a gateway address');
      return;
    }

    try {
      final provider = Provider.of<CameraDevicesProviderOptimized>(
        context,
        listen: false,
      );

      // Send SET_NETWORK command
      // Format: SET_NETWORK ip gw dhcp mac
      // dhcp: 1 = Enable DHCP server for slaves, 0 = Disable
      final dhcpValue = _useDHCP ? '1' : '0';
      final ip = _ipController.text;
      final gw = _gatewayController.text;
      
      await provider.sendSetNetwork(
        ip: ip,
        gateway: gw,
        dhcp: dhcpValue,
        mac: widget.device.macAddress,
      );

      Navigator.pop(context);
      
      AppSnackBar.success(
        context,
        'Network settings updated for ${widget.device.deviceType}\n'
        'IP: $ip, Gateway: $gw${_useDHCP ? ', DHCP Server: Enabled' : ''}',
      );
    } catch (e) {
      AppSnackBar.error(context, 'Error: $e');
    }
  }
}