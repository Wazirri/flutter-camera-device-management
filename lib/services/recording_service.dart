import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recording.dart';
import '../models/camera_device.dart';
import 'dart:async';

class RecordingService {
  // Singleton instance
  static final RecordingService _instance = RecordingService._internal();

  factory RecordingService() {
    return _instance;
  }

  RecordingService._internal();

  // Timeout for HTTP requests
  final Duration _timeout = const Duration(seconds: 10);

  // Cache for recording days by camera
  final Map<String, List<RecordingDay>> _recordingDaysCache = {};
  
  // Cache for recordings by day
  final Map<String, List<Recording>> _recordingsCache = {};

  // Get base URL for recordings for a specific camera
  String _getRecordingBaseUrl(Camera camera) {
    // Format: http://{IP}:8080/Rec/{CAMERA_NAME}/
    return 'http://${camera.ip}:8080/Rec/${camera.name}';
  }

  // Get all available recording days for a camera
  Future<List<RecordingDay>> getRecordingDays(Camera camera) async {
    final cacheKey = camera.name;
    
    // Check cache first
    if (_recordingDaysCache.containsKey(cacheKey)) {
      return _recordingDaysCache[cacheKey]!;
    }
    
    try {
      // Fetch the directory listing
      final baseUrl = _getRecordingBaseUrl(camera);
      final response = await http.get(Uri.parse(baseUrl)).timeout(_timeout);
      
      if (response.statusCode == 200) {
        // Parse the HTML response to extract directory names
        // Note: This is a simple implementation and might need adjustment based on
        // the actual server response format
        final html = response.body;
        
        // Extract directory names (YYYY_MM_DD format)
        final RegExp dirRegex = RegExp(r'href="([0-9]{4}_[0-9]{2}_[0-9]{2})/');
        final matches = dirRegex.allMatches(html);
        
        final List<RecordingDay> days = [];
        
        for (final match in matches) {
          final dirName = match.group(1);
          if (dirName != null) {
            try {
              // Parse the date from directory name
              final parts = dirName.split('_');
              if (parts.length == 3) {
                final year = int.parse(parts[0]);
                final month = int.parse(parts[1]);
                final day = int.parse(parts[2]);
                
                final date = DateTime(year, month, day);
                final dayUrl = '$baseUrl/$dirName';
                
                days.add(RecordingDay(
                  date: date,
                  cameraName: camera.name,
                  baseUrl: dayUrl,
                  recordings: [], // Empty initially
                ));
              }
            } catch (e) {
              print('Error parsing date: $e');
            }
          }
        }
        
        // Sort days in descending order (newest first)
        days.sort((a, b) => b.date.compareTo(a.date));
        
        // Cache the result
        _recordingDaysCache[cacheKey] = days;
        
        return days;
      } else {
        print('Failed to get recording days: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching recording days: $e');
      return [];
    }
  }

  // Get recordings for a specific day
  Future<List<Recording>> getRecordingsForDay(RecordingDay day) async {
    final cacheKey = '${day.cameraName}_${day.dateFormatted}';
    
    // Check cache first
    if (_recordingsCache.containsKey(cacheKey)) {
      return _recordingsCache[cacheKey]!;
    }
    
    try {
      // Fetch the directory listing for the specific day
      final response = await http.get(Uri.parse(day.baseUrl)).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final html = response.body;
        
        // Extract MP4 file names
        final RegExp fileRegex = RegExp(r'href="([^"]+\.mp4)"');
        final matches = fileRegex.allMatches(html);
        
        final List<Recording> recordings = [];
        
        for (final match in matches) {
          final fileName = match.group(1);
          if (fileName != null) {
            final recording = Recording.fromDirectoryEntry(fileName, day.baseUrl, day.cameraName);
            if (recording != null) {
              recordings.add(recording);
            }
          }
        }
        
        // Sort recordings by time (newest first)
        recordings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        
        // Cache the result
        _recordingsCache[cacheKey] = recordings;
        
        return recordings;
      } else {
        print('Failed to get recordings: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching recordings: $e');
      return [];
    }
  }

  // Clear caches
  void clearCache() {
    _recordingDaysCache.clear();
    _recordingsCache.clear();
  }
  
  // Clear cache for a specific camera
  void clearCacheForCamera(String cameraName) {
    _recordingDaysCache.remove(cameraName);
    
    // Remove all recording caches for this camera
    final keysToRemove = _recordingsCache.keys
        .where((key) => key.startsWith('${cameraName}_'))
        .toList();
    
    for (final key in keysToRemove) {
      _recordingsCache.remove(key);
    }
  }
}
