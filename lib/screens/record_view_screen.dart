import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../widgets/camera_grid_item.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/desktop_menu.dart';
import '../widgets/mobile_menu.dart';
import '../widgets/status_indicator.dart';

class RecordViewScreen extends StatefulWidget {
  const RecordViewScreen({Key? key}) : super(key: key);

  @override
  State<RecordViewScreen> createState() => _RecordViewScreenState();
}

class _RecordViewScreenState extends State<RecordViewScreen> {
  bool _isMenuExpanded = true;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedCamera = 'Camera 1';
  
  final List<String> _cameraOptions = [
    'Camera 1', 'Camera 2', 'Camera 3', 'Camera 4',
    'Camera 5', 'Camera 6', 'Camera 7', 'Camera 8',
  ];
  
  void _toggleMenu() {
    setState(() {
      _isMenuExpanded = !_isMenuExpanded;
    });
  }
  
  void _navigate(String route) {
    Navigator.pushReplacementNamed(context, route);
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.blueAccent,
              onPrimary: Colors.white,
              surface: AppTheme.darkSurface,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppTheme.darkBackground,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.blueAccent,
              onPrimary: Colors.white,
              surface: AppTheme.darkSurface,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppTheme.darkBackground,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Record View',
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {},
            tooltip: 'Download',
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () {},
            tooltip: 'Fullscreen',
          ),
          const SizedBox(width: 8.0),
        ],
      ),
      drawer: isMobile
          ? MobileDrawer(
              currentRoute: '/record_view',
              onNavigate: _navigate,
            )
          : null,
      bottomNavigationBar: isMobile
          ? MobileMenu(
              currentRoute: '/record_view',
              onNavigate: _navigate,
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            DesktopMenu(
              currentRoute: '/record_view',
              onNavigate: _navigate,
              isExpanded: _isMenuExpanded,
              onToggleExpand: _toggleMenu,
            ),
          Expanded(
            child: Column(
              children: [
                _buildControlBar(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildRecordingView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlBar(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF333333),
            width: 1.0,
          ),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                _buildCameraSelector(),
                const SizedBox(height: 16.0),
                _buildDateTimeControls(context),
                const SizedBox(height: 16.0),
                _buildPlaybackControls(),
              ],
            )
          : Row(
              children: [
                _buildCameraSelector(),
                const SizedBox(width: 24.0),
                _buildDateTimeControls(context),
                const Spacer(),
                _buildPlaybackControls(),
              ],
            ),
    );
  }
  
  Widget _buildCameraSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCamera,
          isDense: true,
          hint: const Text('Select Camera'),
          dropdownColor: AppTheme.darkSurface,
          icon: const Icon(Icons.arrow_drop_down),
          items: _cameraOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedCamera = newValue;
              });
            }
          },
        ),
      ),
    );
  }
  
  Widget _buildDateTimeControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Date Picker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: InkWell(
            onTap: () => _selectDate(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16.0,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8.0),
                Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 12.0),
        
        // Time Picker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: InkWell(
            onTap: () => _selectTime(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16.0,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8.0),
                Text(
                  _selectedTime.format(context),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPlaybackControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: () {},
          tooltip: 'Previous',
          splashRadius: 24.0,
        ),
        IconButton(
          icon: const Icon(Icons.fast_rewind),
          onPressed: () {},
          tooltip: 'Rewind',
          splashRadius: 24.0,
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.blueAccent,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {},
            tooltip: 'Play',
            color: Colors.white,
            splashRadius: 24.0,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.fast_forward),
          onPressed: () {},
          tooltip: 'Forward',
          splashRadius: 24.0,
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: () {},
          tooltip: 'Next',
          splashRadius: 24.0,
        ),
      ],
    );
  }
  
  Widget _buildRecordingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8.0),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off,
                  color: AppTheme.textSecondary,
                  size: 64.0,
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Recording for $_selectedCamera',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 18.0,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(_selectedDate)} at ${_selectedTime.format(context)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 32.0),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Playback'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        const Text(
          'Timeline',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          height: 80.0,
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Timeline scrubber
              Container(
                height: 40.0,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    const Text(
                      '00:00',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.0,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                          activeTrackColor: AppTheme.blueAccent,
                          inactiveTrackColor: AppTheme.textSecondary.withOpacity(0.3),
                          thumbColor: AppTheme.blueAccent,
                          overlayColor: AppTheme.blueAccent.withOpacity(0.3),
                        ),
                        child: Slider(
                          value: 0.3,
                          onChanged: (value) {},
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    const Text(
                      '24:00',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8.0),
              // Hour markers
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(13, (index) {
                    final hour = index * 2;
                    return Text(
                      hour.toString().padLeft(2, '0') + ':00',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10.0,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),
        if (!ResponsiveHelper.isMobile(context))
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildEventList(),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                flex: 1,
                child: _buildRecordingInfo(),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEventList(),
              const SizedBox(height: 16.0),
              _buildRecordingInfo(),
            ],
          ),
      ],
    );
  }
  
  Widget _buildEventList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Motion Events',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (context, index) => const Divider(height: 1.0),
            itemBuilder: (context, index) {
              return ListTile(
                leading: Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: const Icon(
                    Icons.motion_photos_on,
                    color: AppTheme.orangeAccent,
                  ),
                ),
                title: Text('Motion Event ${index + 1}'),
                subtitle: Text(
                  '${DateFormat('hh:mm a').format(DateTime.now().subtract(Duration(minutes: index * 15)))} - Duration: ${(index + 1) * 10}s',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.0,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                ),
                onTap: () {},
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildRecordingInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recording Info',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8.0),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(8.0),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildInfoRow('Camera', _selectedCamera),
              const SizedBox(height: 8.0),
              _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(_selectedDate)),
              const SizedBox(height: 8.0),
              _buildInfoRow('Time', _selectedTime.format(context)),
              const SizedBox(height: 8.0),
              _buildInfoRow('Resolution', '1080p'),
              const SizedBox(height: 8.0),
              _buildInfoRow('File Size', '254 MB'),
              const SizedBox(height: 8.0),
              _buildInfoRow('Duration', '24 hours'),
              const SizedBox(height: 8.0),
              _buildInfoRow('Motion Events', '5'),
              const SizedBox(height: 16.0),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text('Download Recording'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40.0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
