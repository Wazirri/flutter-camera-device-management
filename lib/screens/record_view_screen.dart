import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/custom_app_bar.dart';

class RecordViewScreen extends StatefulWidget {
  const RecordViewScreen({Key? key}) : super(key: key);

  @override
  State<RecordViewScreen> createState() => _RecordViewScreenState();
}

class _RecordViewScreenState extends State<RecordViewScreen> {
  final _dateController = TextEditingController(text: '2025-04-01');
  int _selectedRecordingIndex = 0;
  
  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: CustomAppBar(
        title: 'Recordings',
        isDesktop: isDesktop,
        actions: [
          _buildDateSelector(),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Timeline sidebar - only visible on desktop/tablet
          if (isDesktop || ResponsiveHelper.isTablet(context))
            SizedBox(
              width: 280,
              child: Card(
                margin: EdgeInsets.zero,
                color: AppTheme.darkSurface,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                child: Column(
                  children: [
                    _buildCalendar(),
                    Expanded(
                      child: _buildRecordingsList(),
                    ),
                  ],
                ),
              ),
            ),
          
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Recording video display area
                Expanded(
                  child: _buildRecordingView(),
                ),
                
                // Playback controls
                _buildPlaybackControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppTheme.primaryBlue,
                    onPrimary: Colors.white,
                    surface: AppTheme.darkSurface,
                    onSurface: AppTheme.darkTextPrimary,
                  ),
                  dialogBackgroundColor: AppTheme.darkSurface,
                ),
                child: child!,
              );
            },
          );
          if (date != null) {
            setState(() {
              _dateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Text(_dateController.text),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.darkSurface.withOpacity(0.8), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'April 2025',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      // UI only
                    },
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      // UI only
                    },
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalendarGrid(),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    // Create a simple calendar grid
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: 7 + 30, // 7 days of week + 30 days in month
      itemBuilder: (context, index) {
        if (index < 7) {
          // Weekday headers
          final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
          return Center(
            child: Text(
              weekdays[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextSecondary,
              ),
            ),
          );
        } else {
          // Day cells
          final day = index - 7 + 1;
          final hasRecordings = [1, 5, 10, 15, 20, 25].contains(day);
          final isSelected = day == 1; // April 1st is selected
          
          return InkWell(
            onTap: () {
              // UI only
            },
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.primaryBlue 
                    : hasRecordings 
                        ? AppTheme.primaryBlue.withOpacity(0.1) 
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    color: isSelected 
                        ? Colors.white 
                        : hasRecordings 
                            ? AppTheme.primaryBlue 
                            : AppTheme.darkTextPrimary,
                    fontWeight: isSelected || hasRecordings ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildRecordingsList() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        final hour = 8 + index;
        final formattedHour = hour.toString().padLeft(2, '0');
        final hasRecording = [8, 10, 14].contains(hour);
        
        if (hasRecording) {
          return _buildRecordingItem(
            index: index,
            time: '$formattedHour:00 - $formattedHour:30',
            cameraName: 'Camera ${index + 1}',
            eventType: index % 2 == 0 ? 'Motion Detected' : 'Scheduled',
            isSelected: _selectedRecordingIndex == index,
          );
        } else {
          return ListTile(
            title: Text(
              '$formattedHour:00',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 14,
              ),
            ),
            subtitle: const Text(
              'No recordings',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildRecordingItem({
    required int index,
    required String time,
    required String cameraName,
    required String eventType,
    required bool isSelected,
  }) {
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppTheme.primaryBlue.withOpacity(0.15),
      onTap: () {
        setState(() {
          _selectedRecordingIndex = index;
        });
      },
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(
            Icons.videocam,
            color: AppTheme.primaryBlue,
            size: 20,
          ),
        ),
      ),
      title: Text(
        cameraName,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryBlue : AppTheme.darkTextPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkTextSecondary,
            ),
          ),
          Text(
            eventType,
            style: TextStyle(
              fontSize: 12,
              color: eventType == 'Motion Detected'
                  ? AppTheme.warning
                  : AppTheme.darkTextSecondary,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.play_circle_fill,
        color: isSelected ? AppTheme.primaryBlue : AppTheme.primaryOrange,
        size: 24,
      ),
    );
  }

  Widget _buildRecordingView() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Placeholder for the recording view
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam,
                  size: 64,
                  color: AppTheme.primaryOrange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Recording Playback',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Camera ${_selectedRecordingIndex + 1} - April 1, 2025',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Recording info overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    size: 12,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recording',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Timestamp overlay
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '2025-04-01 08:15:22',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      height: 100,
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Progress slider
          Slider(
            value: 0.3,
            onChanged: (value) {
              // UI only
            },
            activeColor: AppTheme.primaryBlue,
            inactiveColor: AppTheme.darkBackground,
          ),
          
          // Time and controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '01:45 / 05:30',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                  ),
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      // UI only
                    },
                    child: const Icon(Icons.pause),
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                    tooltip: 'Download',
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      // UI only
                    },
                    color: AppTheme.darkTextPrimary,
                    tooltip: 'Fullscreen',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}