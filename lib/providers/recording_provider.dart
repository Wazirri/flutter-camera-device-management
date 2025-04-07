import 'package:flutter/foundation.dart';
import '../models/recording.dart';
import '../models/camera_device.dart';
import '../services/recording_service.dart';

class RecordingProvider with ChangeNotifier {
  final RecordingService _recordingService = RecordingService();
  
  // Selected camera
  Camera? _selectedCamera;
  
  // Available recording days for the selected camera
  List<RecordingDay> _recordingDays = [];
  
  // Selected day
  RecordingDay? _selectedDay;
  
  // Available recordings for the selected day
  List<Recording> _recordings = [];
  
  // Selected recording
  Recording? _selectedRecording;
  
  // Loading states
  bool _isLoadingDays = false;
  bool _isLoadingRecordings = false;
  
  // Error states and messages
  bool _hasDaysError = false;
  bool _hasRecordingsError = false;
  String _errorMessage = '';

  // Getters
  Camera? get selectedCamera => _selectedCamera;
  List<RecordingDay> get recordingDays => _recordingDays;
  RecordingDay? get selectedDay => _selectedDay;
  List<Recording> get recordings => _recordings;
  Recording? get selectedRecording => _selectedRecording;
  bool get isLoadingDays => _isLoadingDays;
  bool get isLoadingRecordings => _isLoadingRecordings;
  bool get hasDaysError => _hasDaysError;
  bool get hasRecordingsError => _hasRecordingsError;
  String get errorMessage => _errorMessage;
  
  // Select a camera and load its recording days
  Future<void> selectCamera(Camera camera) async {
    if (_selectedCamera?.name == camera.name) return;
    
    _selectedCamera = camera;
    _selectedDay = null;
    _selectedRecording = null;
    _recordings = [];
    notifyListeners();
    
    await loadRecordingDays();
  }
  
  // Load recording days for the selected camera
  Future<void> loadRecordingDays() async {
    if (_selectedCamera == null) return;
    
    _isLoadingDays = true;
    _hasDaysError = false;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final days = await _recordingService.getRecordingDays(_selectedCamera!);
      
      _recordingDays = days;
      
      // Auto-select the most recent day if available
      if (_recordingDays.isNotEmpty) {
        await selectDay(_recordingDays[0]);
      }
    } catch (e) {
      _hasDaysError = true;
      _errorMessage = 'Failed to load recording days: $e';
    } finally {
      _isLoadingDays = false;
      notifyListeners();
    }
  }
  
  // Select a day and load its recordings
  Future<void> selectDay(RecordingDay day) async {
    if (_selectedDay?.dateFormatted == day.dateFormatted && 
        _selectedDay?.cameraName == day.cameraName) return;
    
    _selectedDay = day;
    _selectedRecording = null;
    notifyListeners();
    
    await loadRecordings();
  }
  
  // Load recordings for the selected day
  Future<void> loadRecordings() async {
    if (_selectedDay == null) return;
    
    _isLoadingRecordings = true;
    _hasRecordingsError = false;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final recordings = await _recordingService.getRecordingsForDay(_selectedDay!);
      
      _recordings = recordings;
      
      // Auto-select the most recent recording if available
      if (_recordings.isNotEmpty) {
        selectRecording(_recordings[0]);
      }
    } catch (e) {
      _hasRecordingsError = true;
      _errorMessage = 'Failed to load recordings: $e';
    } finally {
      _isLoadingRecordings = false;
      notifyListeners();
    }
  }
  
  // Select a recording
  void selectRecording(Recording recording) {
    _selectedRecording = recording;
    notifyListeners();
  }
  
  // Refresh all data
  Future<void> refresh() async {
    _recordingService.clearCache();
    
    if (_selectedCamera != null) {
      await loadRecordingDays();
    }
  }
  
  // Refresh recordings for the current day
  Future<void> refreshCurrentDay() async {
    if (_selectedCamera != null && _selectedDay != null) {
      _recordingService.clearCacheForCamera(_selectedCamera!.name);
      await loadRecordings();
    }
  }
}
