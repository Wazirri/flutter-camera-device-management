#!/usr/bin/env python3

def add_build_method():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()
    
    # Add helper methods for recordings and fullscreen toggle
    methods = '''
  // Calendar recordings helper methods
  List<String> _getRecordingsForDay(DateTime day) {
    return _recordingEvents[day] ?? [];
  }
  
  void _updateRecordingsForSelectedDay() async {
    if (_selectedDay == null || _recordingsUrl == null) {
      return;
    }
    
    setState(() {
      _isLoadingDates = true;
      _availableRecordings = [];
      _loadingError = '';
    });
    
    try {
      // Format date for URL
      final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
      final url = '$_recordingsUrl$dateStr/';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final html = utf8.decode(response.bodyBytes);
        
        // Parse recording files from HTML
        final recordingRegex = RegExp(r'href="([^"]+\.mkv)"');
        final recordingMatches = recordingRegex.allMatches(html);
        
        final recordings = recordingMatches
            .map((match) => match.group(1)!)
            .toList();
        
        setState(() {
          _availableRecordings = recordings;
          _isLoadingDates = false;
          
          // If we have recordings and none selected, select the first one
          if (recordings.isNotEmpty && _selectedRecording == null) {
            _selectRecording(recordings.first);
          }
        });
      } else {
        setState(() {
          _loadingError = 'Failed to fetch recordings: HTTP ${response.statusCode}';
          _isLoadingDates = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingError = 'Error loading recordings: $e';
        _isLoadingDates = false;
      });
    }
  }
  
  void _selectRecording(String recording) {
    setState(() {
      _selectedRecording = recording;
      _isBuffering = true;
      _hasError = false;
      _errorMessage = '';
    });
    
    // Play the recording
    _loadRecording('$_recordingsUrl${DateFormat('yyyy_MM_dd').format(_selectedDay!)}/$recording');
  }
  
  void _loadRecording(String uri) async {
    print('Loading: $uri');
    
    setState(() {
      _isBuffering = true;
      _hasError = false;
    });
    
    try {
      await _player.open(Media(uri));
      setState(() {
        _isPlaying = true;
        _isBuffering = false;
      });
    } catch (e) {
      print('Error loading recording: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load video: $e';
        _isBuffering = false;
      });
    }
  }
  
  // Toggle fullscreen mode
  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }
  
  // İndirme işlevini başlat (Download function)
  void _downloadRecording(String recording) async {
    if (_selectedDay == null || _camera == null || _recordingsUrl == null) {
      return;
    }
    
    // İndirme için izinleri kontrol et ve iste
    bool hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İndirme için izinler reddedildi. Ayarlardan izinleri etkinleştirin.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Bildirimi göster (Show notification)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('İndiriliyor: $recording'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Tamam',
          onPressed: () {},
        ),
      ),
    );
    
    try {
      // İndirme URL'sini oluştur
      final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
      final dayUrl = '$_recordingsUrl$dateStr/';
      final downloadUrl = '$dayUrl$recording';
      
      // HTTP isteği ile dosyayı indir
      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode == 200) {
        // İndirilen dosyayı kaydet
        final directory = await _getDownloadDirectory();
        if (directory == null) {
          throw Exception("İndirme dizini bulunamadı");
        }
        
        final filePath = '${directory.path}/$recording';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Başarılı bildirim göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İndirme tamamlandı: $recording'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Aç',
              textColor: Colors.white,
              onPressed: () => _openDownloadedFile(filePath),
            ),
          ),
        );
      } else {
        throw Exception("Dosya indirilemedi: ${response.statusCode}");
      }
    } catch (e) {
      // Hata bildirimini göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İndirme hatası: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      print('İndirme hatası: $e');
    }
  }
  
  // İzinleri kontrol et ve gerekirse iste
  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.storage.status;
      if (status.isGranted) {
        return true;
      }
      
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    
    // Masaüstü platformlarda genellikle izin gerekmez
    return true;
  }
  
  // Dosyayı açma fonksiyonu (platform bağımlı)
  void _openDownloadedFile(String filePath) {
    // Bu kısım uygulamanın desteklediği platformlara göre genişletilebilir
    print('Dosya konumu: $filePath');
    
    // Burada platform tabanlı dosya açma mantığı eklenebilir
    // Örneğin, url_launcher paketi ile açılabilir
  }
  
  // İndirme dizinini alma fonksiyonu (platform bağımlı)
  Future<Directory?> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Android için indirme klasörünü al
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      // iOS için belge klasörünü kullan
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Masaüstü için belge klasörünü kullan
      return await getDownloadsDirectory();
    }
    // Desteklenmeyen platformlar için null döndür
    return null;
  }
'''
    
    # Add build method
    build_method = '''
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.darkBackgroundColor,
              AppTheme.darkBackgroundColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (!_isFullScreen)
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                    onPressed: _toggleFullScreen,
                  ),
                  title: Text(_camera != null 
                    ? 'Recordings: ${_camera!.name}' 
                    : 'Camera Recordings',
                    style: TextStyle(color: Colors.white)
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.fullscreen, color: AppTheme.primaryColor),
                      onPressed: _selectedRecording != null ? _toggleFullScreen : null,
                    ),
                  ],
                ),
              
              // Camera Selector (horizontal list)
              if (!_isFullScreen && _availableCameras.length > 1)
                Container(
                  height: 80,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _availableCameras.length,
                    itemBuilder: (context, index) {
                      final camera = _availableCameras[index];
                      final isSelected = index == _selectedCameraIndex;
                      
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          color: isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.3) 
                            : Colors.grey.shade800.withOpacity(0.3),
                          border: Border.all(
                            color: isSelected 
                              ? AppTheme.primaryColor 
                              : Colors.transparent,
                            width: 2.0,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _selectCamera(index),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                camera.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected 
                                    ? AppTheme.primaryColor 
                                    : Colors.white,
                                  fontWeight: isSelected 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              
              // Main content (with recordings selector and player)
              Expanded(
                child: _isFullScreen
                  ? _buildVideoPlayer()
                  : Row(
                      children: [
                        // Left side - Calendar and Recordings
                        Expanded(
                          flex: ResponsiveHelper.isDesktop(context) ? 1 : 2,
                          child: SlideTransition(
                            position: _calendarSlideAnimation,
                            child: FadeTransition(
                              opacity: _fadeInAnimation,
                              child: Card(
                                margin: const EdgeInsets.all(8.0),
                                color: Colors.grey.shade900.withOpacity(0.7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    // Calendar
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: TableCalendar(
                                        firstDay: kFirstDay,
                                        lastDay: kLastDay,
                                        focusedDay: _focusedDay,
                                        selectedDayPredicate: (day) {
                                          return isSameDay(_selectedDay, day);
                                        },
                                        onDaySelected: (selectedDay, focusedDay) {
                                          setState(() {
                                            _selectedDay = selectedDay;
                                            _focusedDay = focusedDay; // update focused day
                                          });
                                          _updateRecordingsForSelectedDay();
                                        },
                                        onPageChanged: (focusedDay) {
                                          _focusedDay = focusedDay;
                                        },
                                        eventLoader: _getRecordingsForDay,
                                        calendarStyle: CalendarStyle(
                                          outsideDaysVisible: false,
                                          weekendTextStyle: TextStyle(color: Colors.red[200]),
                                          holidayTextStyle: TextStyle(color: Colors.red[200]),
                                          markersMaxCount: 3,
                                          markersAnchor: 1.7,
                                          markerDecoration: BoxDecoration(
                                            color: AppTheme.accentColor,
                                            shape: BoxShape.circle,
                                          ),
                                          todayDecoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          selectedDecoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        headerStyle: HeaderStyle(
                                          formatButtonVisible: false,
                                          titleCentered: true,
                                          titleTextStyle: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
                                          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white70),
                                          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white70),
                                        ),
                                      ),
                                    ),
                                    
                                    // Loading indicator for dates
                                    if (_isLoadingDates)
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Loading recordings...',
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    
                                    // Error message
                                    if (_loadingError.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(_loadingError, 
                                            style: TextStyle(color: Colors.white),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    
                                    // Recordings list
                                    if (_availableRecordings.isNotEmpty)
                                      Expanded(
                                        child: FadeTransition(
                                          opacity: _fadeInAnimation,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                  child: Text(
                                                    'Recordings for ${_selectedDay != null ? DateFormat('MMMM d, yyyy').format(_selectedDay!) : "Today"}',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.zero,
                                                    itemCount: _availableRecordings.length,
                                                    itemBuilder: (context, index) {
                                                      final recording = _availableRecordings[index];
                                                      final isSelected = recording == _selectedRecording;
                                                      
                                                      return Card(
                                                        margin: const EdgeInsets.only(bottom: 8),
                                                        color: isSelected 
                                                          ? AppTheme.primaryColor.withOpacity(0.2)
                                                          : Colors.grey.shade800.withOpacity(0.5),
                                                        child: ListTile(
                                                          title: Text(recording, style: TextStyle(color: Colors.white)),
                                                          trailing: IconButton(
                                                            icon: Icon(Icons.download, color: Colors.white70),
                                                            onPressed: () => _downloadRecording(recording),
                                                          ),
                                                          selected: isSelected,
                                                          onTap: () => _selectRecording(recording),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    
                                    // Loading indicator for recordings
                                    if (_isLoadingRecordings)
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0),
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        // Right side - Video player
                        Expanded(
                          flex: ResponsiveHelper.isDesktop(context) ? 2 : 3,
                          child: SlideTransition(
                            position: _playerSlideAnimation,
                            child: FadeTransition(
                              opacity: _fadeInAnimation,
                              child: _buildVideoPlayer(),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
              
              // Show live view button when no recordings
              if (_availableRecordings.isEmpty && _camera != null && !_isLoadingRecordings)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No recordings available for this date',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          icon: const Icon(Icons.live_tv),
                          label: const Text('Show Live View'),
                          onPressed: () => _loadRecording(_camera!.rtspUri),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildVideoPlayer() {
    return Stack(
      children: [
        // Video Player
        Card(
          margin: _isFullScreen ? EdgeInsets.zero : const EdgeInsets.all(8.0),
          color: Colors.black,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: _isFullScreen ? BorderRadius.zero : BorderRadius.circular(12),
          ),
          child: Video(
            controller: _controller,
            fill: Colors.black,
            controls: false,
          ),
        ),
        
        // Buffering indicator
        if (_isBuffering)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        
        // Error message
        if (_hasError)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_camera != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Live View'),
                      onPressed: () => _loadRecording(_camera!.rtspUri),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  // Video Controls at the bottom
  Widget _buildVideoControls() {
    if (_camera != null)
      return VideoControls(
        player: _player,
        hasFullScreenButton: true,
        onFullScreenToggle: _toggleFullScreen,
      );
    return const SizedBox.shrink();
  }
'''
    
    # Add methods to the file
    if "class _RecordViewScreenState extends State<RecordViewScreen> with SingleTickerProviderStateMixin {" in content:
        # Find where to insert the methods
        # Try to find a good position after all variable declarations
        position = content.find("class _RecordViewScreenState extends State<RecordViewScreen> with SingleTickerProviderStateMixin {")
        
        # Find the first closing brace after the class declaration, where we'd add methods
        if position != -1:
            # Skip to end of the existing code
            last_brace_position = content.rfind("}")
            
            if last_brace_position != -1:
                # Insert before the last brace
                content = content[:last_brace_position] + methods + build_method + content[last_brace_position:]
    
    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.write(content)
    
    return "Added build method and related code to record_view_screen.dart"

print(add_build_method())
