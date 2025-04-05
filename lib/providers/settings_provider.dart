import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // Shared preferences instance
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Default values
  bool _darkMode = true;
  String _serverIp = '85.104.114.145';
  int _serverPort = 1200;
  String _username = 'admin';
  String _password = 'admin';
  bool _autoConnect = true;
  bool _autoSlideshowEnabled = false;
  double _slideshowInterval = 30.0; // seconds
  
  // Getters
  bool get darkMode => _darkMode;
  String get serverIp => _serverIp;
  int get serverPort => _serverPort;
  String get username => _username;
  String get password => _password;
  bool get autoConnect => _autoConnect;
  bool get autoSlideshowEnabled => _autoSlideshowEnabled;
  double get slideshowInterval => _slideshowInterval;
  bool get isInitialized => _initialized;
  
  // Constructor
  SettingsProvider() {
    _loadSettings();
  }
  
  // Initialize and load settings from shared preferences
  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Load saved settings with fallback to defaults
      _darkMode = _prefs.getBool('darkMode') ?? true;
      _serverIp = _prefs.getString('serverIp') ?? '85.104.114.145';
      _serverPort = _prefs.getInt('serverPort') ?? 1200;
      _username = _prefs.getString('username') ?? 'admin';
      _password = _prefs.getString('password') ?? 'admin';
      _autoConnect = _prefs.getBool('autoConnect') ?? true;
      _autoSlideshowEnabled = _prefs.getBool('autoSlideshowEnabled') ?? false;
      _slideshowInterval = _prefs.getDouble('slideshowInterval') ?? 30.0;
      
      _initialized = true;
      notifyListeners();
      
      debugPrint('Settings loaded: IP=$_serverIp, Port=$_serverPort, AutoConnect=$_autoConnect');
    } catch (e) {
      debugPrint('Error loading settings: $e');
      // Continue with default values
      _initialized = true;
      notifyListeners();
    }
  }
  
  // Save all settings to shared preferences
  Future<void> _saveSettings() async {
    try {
      await _prefs.setBool('darkMode', _darkMode);
      await _prefs.setString('serverIp', _serverIp);
      await _prefs.setInt('serverPort', _serverPort);
      await _prefs.setString('username', _username);
      await _prefs.setString('password', _password);
      await _prefs.setBool('autoConnect', _autoConnect);
      await _prefs.setBool('autoSlideshowEnabled', _autoSlideshowEnabled);
      await _prefs.setDouble('slideshowInterval', _slideshowInterval);
      
      debugPrint('Settings saved');
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }
  
  // Setters
  void setDarkMode(bool value) {
    _darkMode = value;
    _saveSettings();
    notifyListeners();
  }
  
  void setServerIp(String value) {
    _serverIp = value;
    _saveSettings();
    notifyListeners();
  }
  
  void setServerPort(int value) {
    _serverPort = value;
    _saveSettings();
    notifyListeners();
  }
  
  void setUsername(String value) {
    _username = value;
    _saveSettings();
    notifyListeners();
  }
  
  void setPassword(String value) {
    _password = value;
    _saveSettings();
    notifyListeners();
  }
  
  void setAutoConnect(bool value) {
    _autoConnect = value;
    _saveSettings();
    notifyListeners();
  }
  
  void setAutoSlideshowEnabled(bool value) {
    _autoSlideshowEnabled = value;
    _saveSettings();
    notifyListeners();
  }
  
  void setSlideshowInterval(double value) {
    _slideshowInterval = value;
    _saveSettings();
    notifyListeners();
  }
  
  // Set connection parameters at once
  void setConnectionParams({
    String? serverIp,
    int? serverPort,
    String? username,
    String? password,
    bool? autoConnect,
  }) {
    if (serverIp != null) _serverIp = serverIp;
    if (serverPort != null) _serverPort = serverPort;
    if (username != null) _username = username;
    if (password != null) _password = password;
    if (autoConnect != null) _autoConnect = autoConnect;
    
    _saveSettings();
    notifyListeners();
  }
  
  // Reset settings to defaults
  Future<void> resetToDefaults() async {
    _darkMode = true;
    _serverIp = '85.104.114.145';
    _serverPort = 1200;
    _username = 'admin';
    _password = 'admin';
    _autoConnect = true;
    _autoSlideshowEnabled = false;
    _slideshowInterval = 30.0;
    
    await _saveSettings();
    notifyListeners();
  }
}
