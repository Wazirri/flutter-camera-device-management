import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io'; // Keep for Process.run
import '../providers/websocket_provider_optimized.dart';

// Enum to represent FTP item type
enum FtpItemType { file, directory }

// Class to represent an item in the FTP listing
class FtpListItem {
  final String name;
  final FtpItemType type;
  final String fullPath;
  final DateTime? modifiedDate; // Optional: if FTP server provides it

  FtpListItem({
    required this.name,
    required this.type,
    required this.fullPath,
    this.modifiedDate,
  });
}

// Still need ActivityItem for when we display actual media files
class ActivityItem {
  final String id;
  final DateTime timestamp;
  final String type; // 'Picture' or 'Video'
  final String cameraName;
  final String description;
  final String imageUrl; // For both picture and video thumbnail/link

  ActivityItem({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.cameraName,
    required this.description,
    required this.imageUrl,
  });
}

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({Key? key}) : super(key: key);

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  // FTP configuration data - static or from WebSocket
  final Map<String, Map<String, String>> _ftpConfigurations = {};
  Map<String, String>? _activeFtpConfig; // Store the selected/active FTP config

  // State for FTP browsing
  String _currentFtpPath = '/cam_detections/'; // Initial path
  List<FtpListItem> _ftpListItems = [];
  bool _isLoadingDirectory = false;
  String _loadingError = '';

  // UI state (keep selectedCameraName if you plan to filter by camera later at a deeper level)
  // String? _selectedCameraName; // Might be useful if we want to show "KAMERA2 activities"

  @override
  void initState() {
    super.initState();
    debugPrint('[Activities] ==> initState() called');
    _initializeFtpAndLoadInitialDirectory();
    debugPrint('[Activities] ==> initState() completed');
  }

  Future<void> _initializeFtpAndLoadInitialDirectory() async {
    debugPrint('[Activities] ==> _initializeFtpAndLoadInitialDirectory() called');
    _loadFtpConfigurations(); // Load configurations (WebSocket or test) - Removed await
    if (_ftpConfigurations.isNotEmpty) {
      // For now, let's assume we use the first available FTP configuration
      // Or, if you have a specific one like 'test_device', use that.
      if (_activeFtpConfig == null && _ftpConfigurations.containsKey('test_device')) {
        _activeFtpConfig = _ftpConfigurations['test_device'];
        _currentFtpPath = _activeFtpConfig!['basePath'] ?? '/cam_detections/';
         debugPrint('[Activities] Active FTP Config set to test_device. Path: $_currentFtpPath');
      } else if (_activeFtpConfig == null && _ftpConfigurations.isNotEmpty) {
        _activeFtpConfig = _ftpConfigurations.entries.first.value;
        _currentFtpPath = _activeFtpConfig!['basePath'] ?? _currentFtpPath; // Use current path if base path is null
        debugPrint('[Activities] Active FTP Config set to first available. Path: $_currentFtpPath');
      }
      
      if (_activeFtpConfig != null) {
        await _loadDirectory(_currentFtpPath);
      } else {
        debugPrint('[Activities] No suitable FTP configuration became active.');
         setState(() {
            _loadingError = 'No active FTP configuration found.';
            _isLoadingDirectory = false;
        });
      }
    } else {
      debugPrint('[Activities] No FTP configurations loaded. Cannot browse.');
      setState(() {
        _loadingError = 'FTP configuration not available.';
        _isLoadingDirectory = false;
      });
    }
  }

  void _loadFtpConfigurations() {
    debugPrint('[Activities] ==> _loadFtpConfigurations() called');
    // Attempt to load from WebSocket
    final websocketProvider = Provider.of<WebSocketProviderOptimized>(context, listen: false);
    if (websocketProvider.lastMessage != null) {
      debugPrint('[Activities] Parsing WebSocket message for FTP configurations: ${websocketProvider.lastMessage}');
      _parseFtpConfigurationsFromWebSocket(websocketProvider.lastMessage);
    }

    // If WebSocket didn't provide any, or if you want a fallback/test:
    if (_ftpConfigurations.isEmpty) {
      debugPrint('[Activities] No FTP configurations from WebSocket, loading test configuration');
      _loadTestFtpConfiguration();
    }
    
    debugPrint('[Activities] Final loaded FTP configurations: ${_ftpConfigurations.keys.toList()}');
    debugPrint('[Activities] FTP configurations details: $_ftpConfigurations');
  }

  void _parseFtpConfigurationsFromWebSocket(dynamic websocketData) {
    debugPrint('[Activities] Parsing WebSocket data for FTP configurations...');
    
    if (websocketData is! Map<String, dynamic>) {
      debugPrint('[Activities] WebSocket data is not a map');
      return;
    }
    
    for (var entry in websocketData.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // FTP URL formatını kontrol et: ecs_slaves.m_AA_AA_92_EE_2F_D6.configuration.ftp.url
      if (key.contains('.configuration.ftp.')) {
        final parts = key.split('.');
        if (parts.length >= 4) {
          final deviceId = parts[1]; // m_AA_AA_92_EE_2F_D6
          final ftpProperty = parts[4]; // url, username, password
          
          // FTP konfigürasyonu için device entry'si oluştur
          _ftpConfigurations[deviceId] ??= {};
          
          if (ftpProperty == 'url' && value is String) {
            debugPrint('[Activities] Found FTP URL for $deviceId: $value');
            
            // URL'yi parse et: ftp://212.253.90.143:20521/cam_detections
            final uri = Uri.parse(value);
            _ftpConfigurations[deviceId]!['host'] = uri.host;
            _ftpConfigurations[deviceId]!['port'] = uri.port.toString();
            _ftpConfigurations[deviceId]!['basePath'] = uri.path; // Store base path
            
          } else if (ftpProperty == 'username' && value is String) {
            _ftpConfigurations[deviceId]!['username'] = value;
            debugPrint('[Activities] Found FTP username for $deviceId: $value');
            
          } else if (ftpProperty == 'password' && value is String) {
            _ftpConfigurations[deviceId]!['password'] = value;
            debugPrint('[Activities] Found FTP password for $deviceId');
          }
        }
      }
    }
    
    // After parsing, if _currentFtpPath is based on a basePath, update it.
    // For now, we assume /cam_detections/ is universal or the first config's base path.
    if (_ftpConfigurations.isNotEmpty && _activeFtpConfig == null) {
        _activeFtpConfig = _ftpConfigurations.entries.first.value;
        _currentFtpPath = _activeFtpConfig!['basePath'] ?? '/cam_detections/';
         debugPrint('[Activities] Default FTP path set to: $_currentFtpPath from first config');
    } else if (_activeFtpConfig != null) {
        _currentFtpPath = _activeFtpConfig!['basePath'] ?? _currentFtpPath;
        debugPrint('[Activities] FTP path updated/confirmed: $_currentFtpPath from active config');
    }


    debugPrint('[Activities] Parsed ${_ftpConfigurations.length} FTP configurations');
  }

  void _loadTestFtpConfiguration() {
    // FTP konfigürasyonu - credentials çalışıyor
    _ftpConfigurations['test_device'] = {
      'host': '212.253.90.143',
      'port': '20521',
      'username': 'dahuaftp',
      'password': 'dahuaftp',
      'basePath': '/cam_detections/', // Ensure this is the root you want to browse
    };
    // If this is the only config, make it active
    if (_activeFtpConfig == null && _ftpConfigurations.containsKey('test_device')) {
        _activeFtpConfig = _ftpConfigurations['test_device'];
        _currentFtpPath = _activeFtpConfig!['basePath'] ?? '/cam_detections/';
        debugPrint('[Activities] Test FTP configuration loaded and set as active. Path: $_currentFtpPath');
    } else {
        debugPrint('[Activities] Loaded test FTP configuration, but another config might be active or path already set.');
    }
  }

  Future<void> _loadDirectory(String path) async {
    if (_activeFtpConfig == null) {
      debugPrint('[Activities] No active FTP configuration. Cannot load directory.');
      setState(() {
        _loadingError = 'FTP configuration not selected or available.';
        _isLoadingDirectory = false;
      });
      return;
    }

    debugPrint('[Activities] ==> _loadDirectory() called for path: $path');
    setState(() {
      _isLoadingDirectory = true;
      _loadingError = '';
      _ftpListItems.clear(); // Clear previous items
    });

    try {
      final ftpHost = _activeFtpConfig!['host']!;
      final ftpPort = int.parse(_activeFtpConfig!['port']!);
      final username = _activeFtpConfig!['username']!;
      final password = _activeFtpConfig!['password']!;
      // Note: The 'path' argument to _loadDirectory is the full path from FTP root.
      // The 'basePath' from config is the starting point.

      final rawListing = await _fetchFtpDirListing(
        ftpHost,
        ftpPort,
        username,
        password,
        path, // Use the full path for listing
      );

      final List<FtpListItem> parsedItems = [];
      for (final line in rawListing) {
        // A more robust parsing logic is needed here.
        // For now, we'll assume simple names and try to guess type.
        // A common way FTP LIST command shows directories is with a 'd' at the start of permissions,
        // or by checking if the name contains a '.' for files (very basic).
        // `curl --list-only` usually just gives names. We might need a different curl command
        // or a proper FTP library for detailed listings if `curl --list-only` isn't enough.

        final itemName = line.trim();
        if (itemName.isEmpty || itemName == "." || itemName == "..") continue;

        // Basic type detection: if it has an extension, assume file. Otherwise, directory.
        // This is a simplification and might not always be correct.
        // For Dahua, pic_001, video_001 are directories. YYYY-MM-DD are directories.
        // .jpg, .dav are files.
        FtpItemType itemType = FtpItemType.directory; // Default to directory
        if (itemName.contains('.') && (itemName.endsWith('.jpg') || itemName.endsWith('.dav') || itemName.endsWith('.idx'))) {
          itemType = FtpItemType.file;
        }
        // Further refinement for known directory names if they don't have extensions
        else if (itemName.startsWith('pic_') || itemName.startsWith('video_') || RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(itemName) || RegExp(r'^\d{2}$').hasMatch(itemName) /*hour folders*/) {
           itemType = FtpItemType.directory;
        }


        // Construct full path for the item
        String itemFullPath = path.endsWith('/') ? '$path$itemName' : '$path/$itemName';


        parsedItems.add(FtpListItem(
          name: itemName,
          type: itemType,
          fullPath: itemFullPath,
        ));
      }
      
      // Sort: directories first, then files, then by name
      parsedItems.sort((a, b) {
        if (a.type == FtpItemType.directory && b.type == FtpItemType.file) {
          return -1;
        }
        if (a.type == FtpItemType.file && b.type == FtpItemType.directory) {
          return 1;
        }
        return a.name.compareTo(b.name);
      });


      setState(() {
        _ftpListItems = parsedItems;
        _currentFtpPath = path; // Update current path
        _isLoadingDirectory = false;
      });
      debugPrint('[Activities] Loaded ${parsedItems.length} items for path: $path');

    } catch (e) {
      setState(() {
        _loadingError = 'Error loading directory: $e';
        _isLoadingDirectory = false;
      });
      debugPrint('[Activities] Error in _loadDirectory: $e');
    }
  }
  
  // FTP directory listing using curl command
  Future<List<String>> _fetchFtpDirListing(String host, int port, String username, String password, String path) async {
    try {
      debugPrint('[FTP] Attempting to list directory: ftp://$username:***@$host:$port$path');
      
      final result = await Process.run('curl', [
        '-s', // Silent mode
        '--show-error', // Show errors
        '--list-only', // List names only
        '--ftp-ssl', // Try to use SSL/TLS for control connection if available
        '--user', '$username:$password',
        'ftp://$host:$port$path/', // Ensure path ends with a slash for directories
      ]);
      
      debugPrint('[FTP] Curl exit code: ${result.exitCode} for path $path');
      if (result.stdout.toString().isNotEmpty) {
         debugPrint('[FTP] Curl stdout (first 100 chars): ${result.stdout.toString().substring(0, result.stdout.toString().length > 100 ? 100 : result.stdout.toString().length)}');
      } else {
        debugPrint('[FTP] Curl stdout is empty.');
      }
      if (result.stderr.toString().isNotEmpty) {
        debugPrint('[FTP] Curl stderr: ${result.stderr}');
      }

      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).toList();
        debugPrint('[FTP] Found ${nonEmptyLines.length} items in directory $path');
        return nonEmptyLines;
      } else {
        // Handle common curl error codes for FTP
        String errorMessage = 'Curl failed with exit code ${result.exitCode}.';
        if (result.stderr.toString().contains('No such file or directory')) {
            errorMessage = 'Directory not found or no items: $path';
        } else if (result.stderr.toString().contains('Login denied')) {
            errorMessage = 'FTP login denied.';
        } else {
            errorMessage += ' Stderr: ${result.stderr}';
        }
        debugPrint('[FTP] Error: $errorMessage');
        // Instead of returning empty list, throw an error to be caught by _loadDirectory
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[FTP] Exception during curl for path $path: $e');
      throw Exception('FTP command execution failed: $e'); // Re-throw to be caught
    }
  }

  // Helper to get parent directory
  String _getParentPath(String currentPath) {
    if (currentPath == '/' || currentPath.isEmpty || currentPath == (_activeFtpConfig?['basePath'] ?? '/cam_detections/')) {
      return _activeFtpConfig?['basePath'] ?? '/cam_detections/'; // Already at root or base
    }
    var uri = Uri.parse(currentPath);
    var segments = List<String>.from(uri.pathSegments);
    if (segments.isNotEmpty) {
      segments.removeLast();
    }
    if (segments.isEmpty) {
        return _activeFtpConfig?['basePath'] ?? '/cam_detections/';
    }
    return (currentPath.startsWith('/') ? '/' : '') + segments.join('/') + '/';
  }


  // Placeholder for UI, will be built in the next step
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FTP Browser'),
            Text(
              _currentFtpPath,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        leading: _currentFtpPath != (_activeFtpConfig?['basePath'] ?? '/cam_detections/') && _currentFtpPath != "/"
            ? IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: () {
                  final parentPath = _getParentPath(_currentFtpPath);
                  _loadDirectory(parentPath);
                },
              )
            : null, // No back button if at root
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDirectory(_currentFtpPath),
          ),
        ],
      ),
      body: _isLoadingDirectory
          ? const Center(child: CircularProgressIndicator())
          : _loadingError.isNotEmpty
              ? Center(child: Text('Error: $_loadingError', style: const TextStyle(color: Colors.red)))
              : _ftpListItems.isEmpty
                  ? Center(child: Text('No items found in $_currentFtpPath'))
                  : ListView.builder(
                      itemCount: _ftpListItems.length,
                      itemBuilder: (context, index) {
                        final item = _ftpListItems[index];
                        return ListTile(
                          leading: Icon(item.type == FtpItemType.directory ? Icons.folder : Icons.insert_drive_file),
                          title: Text(item.name),
                          // subtitle: Text(item.fullPath), // Optional: for debugging
                          onTap: () {
                            if (item.type == FtpItemType.directory) {
                              _loadDirectory(item.fullPath);
                            } else {
                              // Handle file tap - e.g., show preview or download
                              debugPrint('Tapped on file: ${item.fullPath}');
                              // For now, just log. Later, could open a viewer.
                              _showMediaPreview(item);
                            }
                          },
                        );
                      },
                    ),
    );
  }

  // Placeholder for showing media. Will need media_kit or similar.
  void _showMediaPreview(FtpListItem item) {
    // This is where you would integrate a media player or image viewer
    // For now, just a dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Preview: ${item.name}'),
          content: Text('Full path: ${item.fullPath}\\nType: ${item.type}'),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Remove or comment out old methods that are no longer used
  // Future<void> _loadActivitiesForDate(DateTime date) async { ... }
  // Future<void> _scanFtpForCamerasAndActivities(...) async { ... }
  // String? _parseFolderNameFromFtpLine(String ftpLine) { ... }
  // Future<List<ActivityItem>> _scanCameraActivities(...) async { ... }
  // ActivityItem? _parseFileToActivity(...) { ... }
  // Widget _buildDateSelector() { ... }
  // Widget _buildCameraFilter() { ... }
  // Widget _buildActivitiesList() { ... }
  // void _selectDate() async { ... }
  // void _playVideo(String videoUrl) { ... }
  // void _showImageDialog(String imageUrl) { ... }

} // End of _ActivitiesScreenState
