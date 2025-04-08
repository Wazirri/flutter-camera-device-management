#!/usr/bin/env python3

def fix_animations():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()
    
    # Find where we need to add animation controller and animations
    after_vars = '''  String? _selectedRecording;
  
  // Calendar related variables
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final kFirstDay = DateTime(DateTime.now().year - 1, 1, 1);
  final kLastDay = DateTime(DateTime.now().year + 1, 12, 31);
  '''
    
    animation_code = '''  String? _selectedRecording;
  
  // Calendar related variables
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final kFirstDay = DateTime(DateTime.now().year - 1, 1, 1);
  final kLastDay = DateTime(DateTime.now().year + 1, 12, 31);
  
  // Animation controller and animations
  late AnimationController _animationController;
  late Animation<Offset> _calendarSlideAnimation;
  late Animation<Offset> _playerSlideAnimation;
  late Animation<double> _fadeInAnimation;
  
  // Recording URLs
  String? _recordingsUrl;
  bool _isLoadingDates = false;
  bool _isLoadingRecordings = false;
  String _loadingError = '';
  Map<DateTime, List<String>> _recordingEvents = {};
  '''
    
    content = content.replace(after_vars, animation_code)
    
    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.write(content)
    
    return "Added animation-related variables to record_view_screen.dart"

print(fix_animations())
