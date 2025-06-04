import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/camera_device.dart';
import '../models/camera_layout_config.dart';

/// Multi Camera View için Provider sınıfı
/// Bu provider, çoklu kamera görünümü için gerekli state'i yönetir
class MultiCameraViewProvider with ChangeNotifier {
  // Tüm mevcut layout şablonları
  List<CameraLayoutConfig> _layouts = [];
  
  // Aktif sayfa dizini
  int _activePageIndex = 0;
  
  // Her sayfa için seçilen layout'lar (layoutCode değeri)
  List<int> _pageLayouts = [5]; // Varsayılan olarak 5 (2x2 grid) ile başla
  
  // Her sayfa için kamera mapping'i (sayfa indeksi -> konum -> kamera)
  // Map<Sayfa İndeksi, Map<Kamera Konumu, Kamera Kodu>>
  Map<int, Map<int, int>> _cameraAssignments = {};
  
  // Otomatik kamera atama modu
  bool _isAutoAssignmentMode = true;
  
  // Kameralar listesi (CameraDevice listesi)
  List<Camera> _availableCameras = [];

  // Map to store saved presets
  final Map<String, Map<int, Map<int, int>>> _savedPresets = {};
  static const String _presetsKey = 'camera_layout_presets';

  // Constructor
  MultiCameraViewProvider() {
    // Başlangıçta layout dosyasını yükle
    _loadCameraLayouts();
    
    // İlk sayfa için boş bir kamera atama haritası oluştur
    _cameraAssignments[0] = {};
    
    // Load saved presets from shared preferences
    _loadSavedPresets();
    
    // Auto-load configuration if available
    _autoLoadConfigurationOnStart();
  }
  
  // Load saved presets from shared preferences
  Future<void> _loadSavedPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? presetsJson = prefs.getString(_presetsKey);
      
      if (presetsJson != null && presetsJson.isNotEmpty) {
        Map<String, dynamic> jsonData = jsonDecode(presetsJson);
        
        // Clear existing presets
        _savedPresets.clear();
        
        // Convert the dynamic JSON to the expected format
        jsonData.forEach((presetName, pageData) {
          Map<int, Map<int, int>> pageAssignments = {};
          
          // Each page data entry
          (pageData as Map<String, dynamic>).forEach((pageKey, assignmentsData) {
            // Convert string keys to int
            int pageIndex = int.parse(pageKey);
            Map<int, int> cameraAssignments = {};
            
            // Each camera assignment
            (assignmentsData as Map<String, dynamic>).forEach((posKey, cameraIndex) {
              cameraAssignments[int.parse(posKey)] = cameraIndex as int;
            });
            
            pageAssignments[pageIndex] = cameraAssignments;
          });
          
          _savedPresets[presetName] = pageAssignments;
        });
        
        print('Loaded ${_savedPresets.length} presets from shared preferences');
        notifyListeners();
      }
    } catch (e) {
      print('Error loading presets from shared preferences: $e');
    }
  }
  
  // Private method for auto-loading configuration on app start
  Future<void> _autoLoadConfigurationOnStart() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay to ensure initialization
      await autoLoadConfiguration();
    } catch (e) {
      print('Error auto-loading configuration on start: $e');
    }
  }
  
  // Save presets to shared preferences
  Future<void> _savePresetsToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String presetsJson = jsonEncode(_savedPresets);
      await prefs.setString(_presetsKey, presetsJson);
      print('Saved ${_savedPresets.length} presets to shared preferences');
    } catch (e) {
      print('Error saving presets to shared preferences: $e');
    }
  }

  // Getters
  List<CameraLayoutConfig> get layouts => _layouts;
  int get activePageIndex => _activePageIndex;
  List<int> get pageLayouts => _pageLayouts;
  bool get isAutoAssignmentMode => _isAutoAssignmentMode;
  List<Camera> get availableCameras => _availableCameras;
  
  // Aktif layout getter'ı
  CameraLayoutConfig? get activeLayout {
    if (_layouts.isEmpty || _pageLayouts.isEmpty || _activePageIndex >= _pageLayouts.length) {
      return null;
    }
    
    int layoutCode = _pageLayouts[_activePageIndex];
    return _layouts.firstWhere(
      (layout) => layout.layoutCode == layoutCode,
      orElse: () => _layouts.first,
    );
  }
  
  // Aktif sayfadaki kamera atamaları
  Map<int, int> get activeCameraAssignments {
    return _cameraAssignments[_activePageIndex] ?? {};
  }
  
  // Belirli bir sayfadaki kamera atamalarını al
  Map<int, int> cameraAssignments(int pageIndex) {
    return _cameraAssignments[pageIndex] ?? {};
  }
  
  // Belirli bir sayfa için kamera atamalarını direkt olarak ayarla
  void setCameraAssignments(int pageIndex, Map<int, int> assignments) {
    _cameraAssignments[pageIndex] = assignments;
    notifyListeners();
  }

  // JSON dosyasından kamera layout'larını yükle
  Future<void> _loadCameraLayouts() async {
    try {
      final String jsonContent = await rootBundle.loadString('assets/layouts/cameraLayout.json');
      final List<dynamic> layoutsJson = jsonDecode(jsonContent);
      
      _layouts = layoutsJson.map((json) => CameraLayoutConfig.fromJson(json)).toList();
      
      // Layoutları layoutCode'a göre sırala
      _layouts.sort((a, b) => a.layoutCode.compareTo(b.layoutCode));
      
      notifyListeners();
    } catch (e) {
      print('Error loading camera layouts: $e');
    }
  }
  
  // Kameraları ayarla
  void setAvailableCameras(List<Camera> cameras) {
    _availableCameras = cameras;
    
    // Eğer otomatik atama modu aktifse, kameraları otomatik olarak ata
    if (_isAutoAssignmentMode) {
      _autoAssignCameras();
    }
    
    notifyListeners();
  }
  
  // Otomatik kamera atama
  void _autoAssignCameras() {
    if (_availableCameras.isEmpty || activeLayout == null) return;
    
    final Map<int, int> assignments = {};
    final locations = activeLayout!.cameraLoc;
    
    // Her lokasyon için, mevcut kameralardan birini ata
    for (int i = 0; i < locations.length; i++) {
      if (i < _availableCameras.length) {
        int cameraPosition = locations[i].cameraCode;
        // index+1 değerini kullan (varsayılan CameraCode değil)
        assignments[cameraPosition] = i + 1;
      }
    }
    
    _cameraAssignments[_activePageIndex] = assignments;
    notifyListeners();
  }
  
  // Automatic camera assignment with different sorting criteria
  void autoAssignCamerasBySorting(String sortingCriteria) {
    if (_availableCameras.isEmpty || activeLayout == null) return;
    
    // Create a sorted copy of the available cameras based on criteria
    final List<Camera> sortedCameras = List.from(_availableCameras);
    
    switch (sortingCriteria) {
      case 'name':
        sortedCameras.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'brand':
        sortedCameras.sort((a, b) => a.brand.compareTo(b.brand));
        break;
      case 'status':
        // Sort by connection status (online first)
        sortedCameras.sort((a, b) => b.connected ? 1 : -1);
        break;
      case 'ip':
        sortedCameras.sort((a, b) => a.ip.compareTo(b.ip));
        break;
      default:
        // Default is no sorting (use the original order)
        break;
    }
    
    final Map<int, int> assignments = {};
    final locations = activeLayout!.cameraLoc;
    
    // Assign sorted cameras to positions
    for (int i = 0; i < locations.length; i++) {
      if (i < sortedCameras.length) {
        int cameraPosition = locations[i].cameraCode;
        int cameraIndex = _availableCameras.indexOf(sortedCameras[i]) + 1;
        assignments[cameraPosition] = cameraIndex;
      }
    }
    
    _cameraAssignments[_activePageIndex] = assignments;
    notifyListeners();
  }
  
  // Manuel kamera atama
  void assignCamera(int cameraPosition, int cameraIndex) {
    if (_cameraAssignments[_activePageIndex] == null) {
      _cameraAssignments[_activePageIndex] = {};
    }
    
    // Eğer cameraIndex 0 ise, kamerayı kaldır
    if (cameraIndex == 0) {
      _cameraAssignments[_activePageIndex]!.remove(cameraPosition);
    } else {
      _cameraAssignments[_activePageIndex]![cameraPosition] = cameraIndex;
    }
    
    notifyListeners();
  }
  
  // Aktif sayfa layout'unu değiştir
  void setActivePageLayout(int layoutCode) {
    if (_pageLayouts.length <= _activePageIndex) {
      // Eksik sayfalar için varsayılan layout ekle
      while (_pageLayouts.length <= _activePageIndex) {
        _pageLayouts.add(5); // Varsayılan 2x2 grid (layoutCode 5)
      }
    }
    
    _pageLayouts[_activePageIndex] = layoutCode;
    
    // Eğer otomatik atama modundaysak, kameraları otomatik olarak yeniden ata
    if (_isAutoAssignmentMode) {
      _autoAssignCameras();
    }
    
    notifyListeners();
  }
  
  // Aktif sayfa değiştir
  void setActivePage(int pageIndex) {
    if (pageIndex < 0) return;
    
    // Eğer yeni bir sayfa ise, varsayılan değerleri ayarla
    if (pageIndex >= _pageLayouts.length) {
      _pageLayouts.add(5); // Varsayılan 2x2 grid
      _cameraAssignments[pageIndex] = {};
    }
    
    _activePageIndex = pageIndex;
    
    // Eğer otomatik atama modundaysak, kameraları otomatik olarak yeniden ata
    if (_isAutoAssignmentMode) {
      _autoAssignCameras();
    }
    
    notifyListeners();
  }
  
  // Sayfa ekle
  void addPage() {
    int newPageIndex = _pageLayouts.length;
    _pageLayouts.add(5); // Varsayılan 2x2 grid
    _cameraAssignments[newPageIndex] = {};
    
    // Yeni sayfaya geç
    _activePageIndex = newPageIndex;
    
    notifyListeners();
  }
  
  // Sayfayı sil (aktif sayfa)
  void removePage() {
    if (_pageLayouts.length <= 1) return; // En az bir sayfa kalmalı
    
    _pageLayouts.removeAt(_activePageIndex);
    _cameraAssignments.remove(_activePageIndex);
    
    // Kalan sayfalardaki atama indekslerini güncelle
    final Map<int, Map<int, int>> updatedAssignments = {};
    
    _cameraAssignments.forEach((pageIndex, assignments) {
      if (pageIndex > _activePageIndex) {
        updatedAssignments[pageIndex - 1] = assignments;
      } else if (pageIndex < _activePageIndex) {
        updatedAssignments[pageIndex] = assignments;
      }
    });
    
    _cameraAssignments = updatedAssignments;
    
    // Aktif sayfayı güncelle
    if (_activePageIndex >= _pageLayouts.length) {
      _activePageIndex = _pageLayouts.length - 1;
    }
    
    notifyListeners();
  }
  
  // Otomatik/manuel atama modunu değiştir
  void toggleAssignmentMode() {
    _isAutoAssignmentMode = !_isAutoAssignmentMode;
    
    // Eğer otomatik moda geçildiyse, kameraları otomatik olarak yeniden ata
    if (_isAutoAssignmentMode) {
      _autoAssignCameras();
    }
    
    notifyListeners();
  }

  // Get the list of saved preset names
  List<String> get presetNames => _savedPresets.keys.toList();

  // Save current assignments as a preset with a given name
  void savePresetWithName(String presetName) {
    if (presetName.isNotEmpty) {
      // Create a deep copy of current assignments
      final Map<int, Map<int, int>> presetData = {};
      
      _cameraAssignments.forEach((pageIndex, assignments) {
        presetData[pageIndex] = Map<int, int>.from(assignments);
      });
      
      _savedPresets[presetName] = presetData;
      _savePresetsToPreferences(); // Save changes to persistent storage
      notifyListeners();
    }
  }

  // Save current camera assignments under an existing preset name
  void savePreset(String presetName) {
    savePresetWithName(presetName);
  }

  // Load a saved preset by name
  void loadPreset(String presetName) {
    final preset = _savedPresets[presetName];
    if (preset != null) {
      // Apply the preset to current assignments
      _cameraAssignments = {};
      
      preset.forEach((pageIndex, assignments) {
        _cameraAssignments[pageIndex] = Map<int, int>.from(assignments);
      });
      
      // Make sure we have enough pages for the preset
      while (_pageLayouts.length < preset.length) {
        _pageLayouts.add(5); // Add default layout
      }
      
      notifyListeners();
    }
  }

  // Delete a saved preset
  void deletePreset(String presetName) {
    _savedPresets.remove(presetName);
    _savePresetsToPreferences(); // Save changes to persistent storage
    notifyListeners();
  }

  // Update the name of a saved preset
  void updatePresetName(String oldName, String newName) {
    if (oldName != newName && _savedPresets.containsKey(oldName) && !_savedPresets.containsKey(newName)) {
      final presetData = _savedPresets[oldName];
      _savedPresets.remove(oldName);
      _savedPresets[newName] = presetData!;
      _savePresetsToPreferences(); // Save changes to persistent storage
      notifyListeners();
    }
  }

  // Export presets to JSON string
  String exportPresetsToJson() {
    return jsonEncode(_savedPresets);
  }
  
  // Import presets from JSON string
  void importPresetsFromJson(String jsonString) {
    try {
      Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      // Convert the dynamic JSON to the expected format
      Map<String, Map<int, Map<int, int>>> importedPresets = {};
      
      jsonData.forEach((presetName, pageData) {
        Map<int, Map<int, int>> pageAssignments = {};
        
        // Each page data entry
        (pageData as Map<String, dynamic>).forEach((pageKey, assignmentsData) {
          // Convert string keys to int
          int pageIndex = int.parse(pageKey);
          Map<int, int> cameraAssignments = {};
          
          // Each camera assignment
          (assignmentsData as Map<String, dynamic>).forEach((posKey, cameraIndex) {
            cameraAssignments[int.parse(posKey)] = cameraIndex as int;
          });
          
          pageAssignments[pageIndex] = cameraAssignments;
        });
        
        importedPresets[presetName] = pageAssignments;
      });
      
      // Merge with existing presets
      _savedPresets.addAll(importedPresets);
      
      notifyListeners();
    } catch (e) {
      print('Error importing presets: $e');
      throw Exception('Invalid preset format');
    }
  }
  
  // Send a command to the system
  // This method would typically communicate with a backend service
  // or another provider like WebSocketProvider to send the actual command
  Future<bool> sendCommand(String command) async {
    try {
      // For now, we're simulating successful command execution
      print('Sending command: $command');
      
      // Handle special commands related to layouts
      if (command.contains('quick_setup')) {
        // Simulate quick setup by resetting to default layout
        _pageLayouts = [5]; // Reset to default 2x2 grid
        _activePageIndex = 0;
        _cameraAssignments = {0: {}};
        
        if (_isAutoAssignmentMode) {
          _autoAssignCameras();
        }
        
      } else if (command.contains('reset_layouts')) {
        // Reset all layouts to default
        _pageLayouts = [5]; // Reset to default 2x2 grid
        _activePageIndex = 0;
        _cameraAssignments = {0: {}};
        
        if (_isAutoAssignmentMode) {
          _autoAssignCameras();
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error sending command: $e');
      return false;
    }
  }

  // JSON Configuration Management
  static const String _configFileName = 'multi_camera_layout_config.json';
  String? _currentConfigPath;

  // Get the default config directory path
  Future<String> _getConfigDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final configDir = Directory('${directory.path}/MultiCameraConfigs');
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }
      return configDir.path;
    } catch (e) {
      print('Error getting config directory: $e');
      // Fallback to application documents directory
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  // Save current configuration to JSON file
  Future<bool> saveConfigurationToFile({String? customPath, String? fileName}) async {
    try {
      final configData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'pageLayouts': _pageLayouts,
        'activePageIndex': _activePageIndex,
        'cameraAssignments': _cameraAssignments.map((key, value) => 
          MapEntry(key.toString(), value.map((k, v) => MapEntry(k.toString(), v)))),
        'isAutoAssignmentMode': _isAutoAssignmentMode,
        'savedPresets': _savedPresets.map((presetName, presetData) => 
          MapEntry(presetName, presetData.map((pageIndex, assignments) => 
            MapEntry(pageIndex.toString(), assignments.map((pos, cam) => 
              MapEntry(pos.toString(), cam)))))),
      };

      String filePath;
      if (customPath != null) {
        filePath = customPath;
      } else {
        final configDir = await _getConfigDirectory();
        final fileNameToUse = fileName ?? _configFileName;
        filePath = '$configDir/$fileNameToUse';
      }

      final file = File(filePath);
      await file.writeAsString(jsonEncode(configData));
      
      _currentConfigPath = filePath;
      
      // Save the config path in shared preferences for auto-loading
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_config_path', filePath);
      
      print('Configuration saved to: $filePath');
      notifyListeners();
      return true;
    } catch (e) {
      print('Error saving configuration: $e');
      return false;
    }
  }

  // Load configuration from JSON file
  Future<bool> loadConfigurationFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('Configuration file does not exist: $filePath');
        return false;
      }

      final jsonString = await file.readAsString();
      final configData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate version (optional)
      final version = configData['version'] as String?;
      print('Loading configuration version: $version');

      // Load page layouts
      if (configData['pageLayouts'] != null) {
        _pageLayouts = List<int>.from(configData['pageLayouts']);
      }

      // Load active page index
      if (configData['activePageIndex'] != null) {
        _activePageIndex = configData['activePageIndex'] as int;
        // Ensure active page index is within bounds
        if (_activePageIndex >= _pageLayouts.length) {
          _activePageIndex = 0;
        }
      }

      // Load camera assignments
      if (configData['cameraAssignments'] != null) {
        _cameraAssignments.clear();
        final assignments = configData['cameraAssignments'] as Map<String, dynamic>;
        assignments.forEach((pageKey, pageAssignments) {
          final pageIndex = int.parse(pageKey);
          final cameraMap = <int, int>{};
          (pageAssignments as Map<String, dynamic>).forEach((posKey, cameraIndex) {
            cameraMap[int.parse(posKey)] = cameraIndex as int;
          });
          _cameraAssignments[pageIndex] = cameraMap;
        });
      }

      // Load auto assignment mode
      if (configData['isAutoAssignmentMode'] != null) {
        _isAutoAssignmentMode = configData['isAutoAssignmentMode'] as bool;
      }

      // Load saved presets
      if (configData['savedPresets'] != null) {
        _savedPresets.clear();
        final presets = configData['savedPresets'] as Map<String, dynamic>;
        presets.forEach((presetName, presetData) {
          final pageAssignments = <int, Map<int, int>>{};
          (presetData as Map<String, dynamic>).forEach((pageKey, assignments) {
            final pageIndex = int.parse(pageKey);
            final cameraMap = <int, int>{};
            (assignments as Map<String, dynamic>).forEach((posKey, cameraIndex) {
              cameraMap[int.parse(posKey)] = cameraIndex as int;
            });
            pageAssignments[pageIndex] = cameraMap;
          });
          _savedPresets[presetName] = pageAssignments;
        });
      }

      _currentConfigPath = filePath;
      
      // Save the config path in shared preferences for auto-loading
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_config_path', filePath);

      print('Configuration loaded from: $filePath');
      notifyListeners();
      return true;
    } catch (e) {
      print('Error loading configuration: $e');
      return false;
    }
  }

  // Auto-load configuration on app start
  Future<bool> autoLoadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastConfigPath = prefs.getString('last_config_path');
      
      if (lastConfigPath != null) {
        final file = File(lastConfigPath);
        if (await file.exists()) {
          return await loadConfigurationFromFile(lastConfigPath);
        }
      }
      return false;
    } catch (e) {
      print('Error auto-loading configuration: $e');
      return false;
    }
  }

  // Get available configuration files
  Future<List<FileSystemEntity>> getAvailableConfigFiles() async {
    try {
      final configDir = await _getConfigDirectory();
      final directory = Directory(configDir);
      
      if (await directory.exists()) {
        final files = await directory.list().toList();
        return files.where((file) => 
          file is File && file.path.endsWith('.json')).toList();
      }
      return [];
    } catch (e) {
      print('Error getting available config files: $e');
      return [];
    }
  }

  // Delete configuration file
  Future<bool> deleteConfigurationFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        
        // If this was the current config, clear the preference
        if (_currentConfigPath == filePath) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('last_config_path');
          _currentConfigPath = null;
        }
        
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting configuration file: $e');
      return false;
    }
  }

  // Convenience wrapper methods for UI
  
  // Save configuration with a custom name
  Future<void> saveConfiguration(String name) async {
    final success = await saveConfigurationToFile(fileName: '$name.json');
    if (!success) {
      throw Exception('Failed to save configuration');
    }
  }
  
  // Load configuration by name
  Future<void> loadConfiguration(String name) async {
    final configDir = await _getConfigDirectory();
    final filePath = '$configDir/$name.json';
    final success = await loadConfigurationFromFile(filePath);
    if (!success) {
      throw Exception('Failed to load configuration');
    }
  }
  
  // List all available configurations
  Future<List<Map<String, String>>> listConfigurations() async {
    try {
      final files = await getAvailableConfigFiles();
      final configurations = <Map<String, String>>[];
      
      for (final file in files) {
        if (file is File) {
          // Extract name from file path (remove .json extension)
          final fileName = file.path.split('/').last;
          final name = fileName.replaceAll('.json', '');
          
          // Get file modification time as timestamp
          final stat = await file.stat();
          final timestamp = stat.modified.toString().split('.')[0]; // Remove microseconds
          
          configurations.add({
            'name': name,
            'timestamp': timestamp,
            'path': file.path,
          });
        }
      }
      
      // Sort by modification time (newest first)
      configurations.sort((a, b) => b['timestamp']!.compareTo(a['timestamp']!));
      
      return configurations;
    } catch (e) {
      print('Error listing configurations: $e');
      return [];
    }
  }
  
  // Delete configuration by name
  Future<void> deleteConfiguration(String name) async {
    final configDir = await _getConfigDirectory();
    final filePath = '$configDir/$name.json';
    final success = await deleteConfigurationFile(filePath);
    if (!success) {
      throw Exception('Failed to delete configuration');
    }
  }

  // Getters for configuration management
  String? get currentConfigPath => _currentConfigPath;
  
  // Check if a configuration is currently loaded
  bool get hasLoadedConfig => _currentConfigPath != null;
}
