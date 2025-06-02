import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../theme/app_theme.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({Key? key}) : super(key: key);

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  // FTP configuration data - device eşleştirmesi yapılmayacak
  final Map<String, Map<String, String>> _ftpConfigurations = {};
  
  // Activities data
  final Map<String, List<ActivityItem>> _ftpSourceActivities = {};
  bool _isLoadingActivities = false;
  String _loadingError = '';
  
  // UI state
  DateTime _selectedDate = DateTime.now();
  String? _selectedCameraFilter;
  String _selectedActivityType = 'All';
  
  @override
  void initState() {
    super.initState();
    _loadFtpConfigurations();
    _loadActivitiesForDate(_selectedDate);
  }
  
  void _loadFtpConfigurations() {
    // Sabit FTP konfigürasyonu - device bilgisi ile eşleştirme yapılmayacak
    _ftpConfigurations['main_server'] = {
      'host': '192.168.1.100',
      'port': '21',
      'username': 'ftpuser',
      'password': 'ftppass',
      'basePath': '/cameras',
    };
    
    debugPrint('[Activities] Loaded FTP configurations: ${_ftpConfigurations.keys.toList()}');
  }
  
  Future<void> _loadActivitiesForDate(DateTime date) async {
    setState(() {
      _isLoadingActivities = true;
      _loadingError = '';
      _ftpSourceActivities.clear();
    });

    try {
      final dateStr = DateFormat('yyyyMMdd').format(date); // FTP klasör formatı: 20241202
      debugPrint('[Activities] Loading activities for date: $dateStr');

      // FTP sunucularını tara - device eşleştirmesi yapılmayacak
      for (var ftpConfig in _ftpConfigurations.entries) {
        try {
          final activities = await _fetchActivitiesFromFtp(ftpConfig.value, dateStr);
          _ftpSourceActivities[ftpConfig.key] = activities;
        } catch (e) {
          debugPrint('[Activities] Error fetching from ${ftpConfig.key}: $e');
        }
      }
      
      debugPrint('[Activities] Loaded ${_ftpSourceActivities.length} FTP sources');
    } catch (e) {
      setState(() {
        _loadingError = 'Error loading activities: $e';
      });
      debugPrint('[Activities] Error: $e');
    } finally {
      setState(() {
        _isLoadingActivities = false;
      });
    }
  }

  Future<List<ActivityItem>> _fetchActivitiesFromFtp(Map<String, String> ftpConfig, String dateStr) async {
    List<ActivityItem> activities = [];
    
    try {
      final host = ftpConfig['host']!;
      final port = int.parse(ftpConfig['port']!);
      final username = ftpConfig['username']!;
      final password = ftpConfig['password']!;
      final basePath = ftpConfig['basePath']!;
      
      debugPrint('[Activities] Scanning FTP directory structure: $host:$port$basePath');
      
      // 1. Ana klasördeki kamera klasörlerini listele
      final cameraFolders = await _ftpListDirectory(host, port, username, password, basePath);
      
      for (final cameraFolderLine in cameraFolders) {
        if (cameraFolderLine.trim().isEmpty) continue;
        
        // FTP LIST çıktısını parse et
        final parts = cameraFolderLine.split(RegExp(r'\s+'));
        if (parts.isEmpty) continue;
        
        final permissions = parts[0];
        
        // Sadece klasörleri işle (d ile başlayanlar)
        if (permissions.startsWith('d')) {
          final cameraFolderName = parts.last;
          final cameraPath = '$basePath/$cameraFolderName';
          
          debugPrint('[Activities] Scanning camera folder: $cameraFolderName');
          
          // 2. Kamera klasöründeki tarih klasörlerini ara
          final dateFolders = await _ftpListDirectory(host, port, username, password, cameraPath);
          
          for (final dateFolderLine in dateFolders) {
            final dateParts = dateFolderLine.split(RegExp(r'\s+'));
            if (dateParts.isEmpty) continue;
            
            if (dateParts[0].startsWith('d')) { // Klasör ise
              final dateFolderName = dateParts.last;
              
              // Tarih kontrolü - dateStr ile eşleşen klasörü ara
              if (dateFolderName == dateStr) {
                final datePath = '$cameraPath/$dateFolderName';
                
                debugPrint('[Activities] Found date folder: $dateFolderName for camera: $cameraFolderName');
                
                // 3. Tarih klasöründeki alt klasörleri tara (pic_001, video_001 vb.)
                final subFolders = await _ftpListDirectory(host, port, username, password, datePath);
                
                for (final subFolderLine in subFolders) {
                  final subParts = subFolderLine.split(RegExp(r'\s+'));
                  if (subParts.isEmpty) continue;
                  
                  if (subParts[0].startsWith('d')) { // Alt klasör ise
                    final subFolderName = subParts.last;
                    final subPath = '$datePath/$subFolderName';
                    
                    debugPrint('[Activities] Scanning subfolder: $subFolderName');
                    
                    // 4. Alt klasördeki saat klasörlerini tara
                    final hourFolders = await _ftpListDirectory(host, port, username, password, subPath);
                    
                    for (final hourFolderLine in hourFolders) {
                      final hourParts = hourFolderLine.split(RegExp(r'\s+'));
                      if (hourParts.isEmpty) continue;
                      
                      if (hourParts[0].startsWith('d')) { // Saat klasörü ise
                        final hourFolderName = hourParts.last;
                        final hourPath = '$subPath/$hourFolderName';
                        
                        // 5. Saat klasöründeki dosyaları listele
                        final files = await _ftpListDirectory(host, port, username, password, hourPath);
                        
                        for (final fileLine in files) {
                          final fileParts = fileLine.split(RegExp(r'\s+'));
                          if (fileParts.isEmpty) continue;
                          
                          if (!fileParts[0].startsWith('d')) { // Dosya ise
                            final fileName = fileParts.last;
                            
                            // Aktivite tipini klasör ve dosya adından çıkar
                            String activityType = 'Unknown';
                            if (subFolderName.contains('pic') || fileName.toLowerCase().contains('jpg') || fileName.toLowerCase().contains('png')) {
                              activityType = 'Picture';
                            } else if (subFolderName.contains('video') || fileName.toLowerCase().contains('mp4') || fileName.toLowerCase().contains('avi')) {
                              activityType = 'Video';
                            }
                            
                            if (fileName.toLowerCase().contains('motion')) {
                              activityType = 'Motion';
                            } else if (fileName.toLowerCase().contains('person')) {
                              activityType = 'Person';
                            } else if (fileName.toLowerCase().contains('vehicle')) {
                              activityType = 'Vehicle';
                            } else if (fileName.toLowerCase().contains('face')) {
                              activityType = 'Face';
                            }
                            
                            // Dosya adından zaman damgasını çıkar
                            DateTime timestamp = _parseTimestampFromPath(dateStr, hourFolderName, fileName);
                            
                            activities.add(ActivityItem(
                              id: '${cameraFolderName}_${dateFolderName}_${subFolderName}_${hourFolderName}_${fileName}',
                              timestamp: timestamp,
                              type: activityType,
                              description: 'Detection in $subFolderName/$hourFolderName: $fileName',
                              imageUrl: (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.png')) 
                                  ? 'ftp://$host:$port$hourPath/$fileName' 
                                  : null,
                              confidence: _extractConfidenceFromFileName(fileName),
                              cameraName: cameraFolderName,
                            ));
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      
      debugPrint('[Activities] Found ${activities.length} activities from FTP');
      
    } catch (e) {
      debugPrint('[Activities] FTP Error: $e');
    }
    
    return activities;
  }

  Future<List<String>> _ftpListDirectory(String host, int port, String username, String password, String path) async {
    try {
      debugPrint('[Activities] Listing FTP directory: $path');
      
      // curl kullanarak FTP directory listing yap
      final result = await Process.run('curl', [
        '-s', // Silent mode
        '--user', '$username:$password',
        'ftp://$host:$port$path/',
      ]);
      
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        return lines.where((line) => line.trim().isNotEmpty).toList();
      } else {
        debugPrint('[Activities] FTP listing failed for $path: ${result.stderr}');
        return [];
      }
    } catch (e) {
      debugPrint('[Activities] Error listing directory $path: $e');
      return [];
    }
  }
  
  DateTime _parseTimestampFromPath(String dateStr, String hourStr, String fileName) {
    try {
      // dateStr: 20241202, hourStr: 14, fileName'dan dakika/saniye çıkar
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      int hour = int.parse(hourStr);
      
      // Dosya adından dakika/saniye çıkarmaya çalış
      int minute = 0;
      int second = 0;
      
      final timeMatch = RegExp(r'(\d{2})(\d{2})(\d{2})').firstMatch(fileName);
      if (timeMatch != null) {
        hour = int.parse(timeMatch.group(1)!);
        minute = int.parse(timeMatch.group(2)!);
        second = int.parse(timeMatch.group(3)!);
      }
      
      return DateTime(year, month, day, hour, minute, second);
    } catch (e) {
      debugPrint('[Activities] Error parsing timestamp: $e');
      return DateTime.now();
    }
  }
  
  double? _extractConfidenceFromFileName(String fileName) {
    // Dosya adından güven skorunu çıkarmaya çalış
    final match = RegExp(r'conf[_-]?(\d+)').firstMatch(fileName.toLowerCase());
    if (match != null) {
      return int.parse(match.group(1)!) / 100.0;
    }
    return null;
  }

  List<ActivityItem> get _filteredActivities {
    List<ActivityItem> allActivities = [];
    
    // Tüm FTP kaynaklarından aktiviteleri birleştir
    for (var activities in _ftpSourceActivities.values) {
      allActivities.addAll(activities);
    }
    
    // Filtreleme uygula
    if (_selectedCameraFilter != null && _selectedCameraFilter != 'All') {
      allActivities = allActivities.where((activity) => 
        activity.cameraName == _selectedCameraFilter).toList();
    }
    
    if (_selectedActivityType != 'All') {
      allActivities = allActivities.where((activity) => 
        activity.type == _selectedActivityType).toList();
    }
    
    // Timestamp'e göre sırala (en yeni önce)
    allActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return allActivities;
  }

  Set<String> get _availableCameras {
    Set<String> cameras = {'All'};
    for (var activities in _ftpSourceActivities.values) {
      for (var activity in activities) {
        if (activity.cameraName != null) {
          cameras.add(activity.cameraName!);
        }
      }
    }
    return cameras;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text(
          'Activities',
          style: TextStyle(
            color: AppTheme.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
            onPressed: () => _loadActivitiesForDate(_selectedDate),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _buildActivitiesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Date picker
          Row(
            children: [
              const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _showDatePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: const TextStyle(color: AppTheme.darkTextPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Camera and activity type filters
          Row(
            children: [
              // Camera filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCameraFilter ?? 'All',
                  decoration: const InputDecoration(
                    labelText: 'Camera',
                    border: OutlineInputBorder(),
                  ),
                  items: _availableCameras.map((camera) {
                    return DropdownMenuItem(
                      value: camera,
                      child: Text(camera),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCameraFilter = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              // Activity type filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedActivityType,
                  decoration: const InputDecoration(
                    labelText: 'Activity Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ['All', 'Motion', 'Person', 'Vehicle', 'Face', 'Picture', 'Video']
                      .map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedActivityType = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesList() {
    if (_isLoadingActivities) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_loadingError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Activities',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadingError,
              style: const TextStyle(color: AppTheme.darkTextSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadActivitiesForDate(_selectedDate),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredActivities = _filteredActivities;

    if (filteredActivities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.security,
              size: 64,
              color: AppTheme.darkTextSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Activities Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No security activities found for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
              style: const TextStyle(color: AppTheme.darkTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () => _loadActivitiesForDate(_selectedDate),
      child: ListView.builder(
        itemCount: filteredActivities.length,
        itemBuilder: (context, index) {
          final activity = filteredActivities[index];
          return _buildActivityCard(activity);
        },
      ),
    );
  }

  Widget _buildActivityCard(ActivityItem activity) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.darkSurface,
      child: ListTile(
        leading: _buildActivityIcon(activity.type),
        title: Text(
          activity.type,
          style: const TextStyle(
            color: AppTheme.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity.description,
              style: const TextStyle(color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Camera: ${activity.cameraName ?? 'Unknown'}',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 12,
              ),
            ),
            if (activity.confidence != null)
              Text(
                'Confidence: ${(activity.confidence! * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('HH:mm:ss').format(activity.timestamp),
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              DateFormat('MMM dd').format(activity.timestamp),
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: activity.imageUrl != null
            ? () => _showImagePreview(activity)
            : null,
      ),
    );
  }

  Widget _buildActivityIcon(String type) {
    IconData iconData;
    Color iconColor;

    switch (type.toLowerCase()) {
      case 'motion':
        iconData = Icons.directions_run;
        iconColor = AppTheme.warning;
        break;
      case 'person':
        iconData = Icons.person;
        iconColor = AppTheme.primaryColor;
        break;
      case 'vehicle':
        iconData = Icons.directions_car;
        iconColor = AppTheme.accent;
        break;
      case 'face':
        iconData = Icons.face;
        iconColor = AppTheme.success;
        break;
      case 'picture':
        iconData = Icons.image;
        iconColor = AppTheme.info;
        break;
      case 'video':
        iconData = Icons.videocam;
        iconColor = AppTheme.error;
        break;
      default:
        iconData = Icons.security;
        iconColor = AppTheme.darkTextSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  void _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.darkSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadActivitiesForDate(_selectedDate);
    }
  }

  void _showImagePreview(ActivityItem activity) {
    if (activity.imageUrl == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.darkSurface,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(activity.type),
                  backgroundColor: AppTheme.darkBackground,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.darkBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image,
                                    size: 64,
                                    color: AppTheme.darkTextSecondary,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Image Preview\n(FTP Connection Required)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.darkTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Camera: ${activity.cameraName ?? 'Unknown'}',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Time: ${DateFormat('MMM dd, yyyy HH:mm:ss').format(activity.timestamp)}',
                          style: const TextStyle(color: AppTheme.darkTextSecondary),
                        ),
                        if (activity.confidence != null)
                          Text(
                            'Confidence: ${(activity.confidence! * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(color: AppTheme.accent),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ActivityItem {
  final String id;
  final DateTime timestamp;
  final String type;
  final String description;
  final String? imageUrl;
  final double? confidence;
  final String? cameraName;
  
  ActivityItem({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.description,
    this.imageUrl,
    this.confidence,
    this.cameraName,
  });
}
