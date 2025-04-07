import 'package:intl/intl.dart';

class Recording {
  final String name;        // Recording name
  final String filePath;    // Full path to the recording file
  final String url;         // Full URL to the recording file
  final DateTime dateTime;  // Date and time of the recording
  final String thumbnail;   // Thumbnail URL (if available)
  final int duration;       // Duration in seconds (if available)
  final String size;        // File size (if available)

  Recording({
    required this.name,
    required this.filePath,
    required this.url,
    required this.dateTime,
    this.thumbnail = '',
    this.duration = 0,
    this.size = '',
  });

  // Format the time portion for display
  String get timeFormatted {
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  // Format the date portion for display
  String get dateFormatted {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  // Format duration as HH:MM:SS
  String get durationFormatted {
    final hours = (duration ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((duration % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
  
  // Convert directory listing entry to Recording object
  static Recording? fromDirectoryEntry(String entry, String baseUrl, String cameraName) {
    // Expected format: file name including date and time
    // For example: "2025_04_07_133045.mp4"
    
    try {
      // Assuming filename format: YYYY_MM_DD_HHMMSS.mp4
      final RegExp regex = RegExp(r'(\d{4}_\d{2}_\d{2}_\d{6})\.mp4');
      final match = regex.firstMatch(entry);
      
      if (match != null) {
        final dateTimePart = match.group(1)!;
        final dateParts = dateTimePart.split('_');
        
        if (dateParts.length >= 4) {
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final day = int.parse(dateParts[2]);
          
          final timePart = dateParts[3];
          final hour = int.parse(timePart.substring(0, 2));
          final minute = int.parse(timePart.substring(2, 4));
          final second = int.parse(timePart.substring(4, 6));
          
          final dateTime = DateTime(year, month, day, hour, minute, second);
          
          return Recording(
            name: '$cameraName ${DateFormat('HH:mm:ss').format(dateTime)}',
            filePath: entry,
            url: '$baseUrl/$entry',
            dateTime: dateTime,
          );
        }
      }
      return null;
    } catch (e) {
      print('Error parsing recording entry: $e');
      return null;
    }
  }
}

class RecordingDay {
  final DateTime date;
  final String cameraName;
  final String baseUrl;     // Base URL for this day's recordings
  final List<Recording> recordings;
  
  RecordingDay({
    required this.date,
    required this.cameraName,
    required this.baseUrl,
    required this.recordings,
  });

  // Format date as YYYY_MM_DD for URL construction
  String get dateFormatted {
    return DateFormat('yyyy_MM_dd').format(date);
  }
  
  // Get path component for URLs
  String get pathComponent {
    return dateFormatted;
  }
}
