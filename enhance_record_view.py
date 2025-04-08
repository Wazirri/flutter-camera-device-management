#!/usr/bin/env python3

def enhance_record_view():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()

    # 1. İndirme fonksiyonu ekle
    download_func = '''
  // İndirme işlevini başlat
  void _downloadRecording(String recording) async {
    if (_selectedDay == null || _camera == null || _recordingsUrl == null) {
      return;
    }
    
    // Bildirimi göster
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
    
    // İndirme URL'sini oluştur
    final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
    final dayUrl = '$_recordingsUrl$dateStr/';
    final downloadUrl = '$dayUrl$recording';
    
    // Bu URL'yi paylaşmak veya tarayıcıda açmak için ilgili platform API'lerini kullanabilirsiniz
    // Örneğin: url_launcher paketi ile tarayıcıda açma
    print('İndirme URL: $downloadUrl');
  }'''

    # _hasRecordings fonksiyonundan sonra indirme fonksiyonu ekle
    content = content.replace(
        "  bool _hasRecordings(DateTime day) {\n    return _getRecordingsForDay(day).isNotEmpty;\n  }",
        "  bool _hasRecordings(DateTime day) {\n    return _getRecordingsForDay(day).isNotEmpty;\n  }" + download_func
    )

    # 2. _buildMarker fonksiyonunu geliştir
    old_marker = '''  Widget _buildMarker(int count) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryOrange,
      ),
      width: 8,
      height: 8,
    );
  }'''

    new_marker = '''  Widget _buildMarker(int count) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryOrange,
      ),
      width: 12,
      height: 12,
      child: Center(
        child: count > 1 
          ? Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      ),
    );
  }'''

    content = content.replace(old_marker, new_marker)

    # 3. ListTile'a indirme butonu ekle
    old_listtile = '''                                    return ListTile(
                                      title: Text(recording),
                                      selected: isSelected,
                                      leading: Icon(
                                        Icons.video_library,
                                        color: isSelected ? AppTheme.primaryOrange : null,
                                      ),
                                      selectedTileColor: AppTheme.primaryOrange.withOpacity(0.1),
                                      onTap: () => _selectRecording(recording),
                                    );'''

    new_listtile = '''                                    return ListTile(
                                      title: Text(recording),
                                      selected: isSelected,
                                      leading: Icon(
                                        Icons.video_library,
                                        color: isSelected ? AppTheme.primaryOrange : null,
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.download),
                                        tooltip: 'İndir',
                                        onPressed: () => _downloadRecording(recording),
                                      ),
                                      selectedTileColor: AppTheme.primaryOrange.withOpacity(0.1),
                                      onTap: () => _selectRecording(recording),
                                    );'''

    content = content.replace(old_listtile, new_listtile)

    # 4. Günleri daha belirgin göstermek için CalendarStyle güncellemesi
    old_calendar_style = '''                            calendarStyle: CalendarStyle(
                              // Customize the appearance based on app theme
                              todayDecoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: const BoxDecoration(
                                color: AppTheme.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: const BoxDecoration(
                                color: AppTheme.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                            ),'''

    new_calendar_style = '''                            calendarStyle: CalendarStyle(
                              // Customize the appearance based on app theme
                              todayDecoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: const BoxDecoration(
                                color: AppTheme.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: const BoxDecoration(
                                color: AppTheme.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                              markersMaxCount: 3,
                              markersAnchor: 0.7,
                              outsideDaysVisible: false,
                              weekendTextStyle: const TextStyle(color: Colors.red),
                              holidayTextStyle: const TextStyle(color: Colors.blue),
                            ),'''

    content = content.replace(old_calendar_style, new_calendar_style)

    with open('lib/screens/record_view_screen.dart', 'w') as file:
        file.write(content)

enhance_record_view()
print("Kayıt görüntüleme sayfası geliştirmeleri tamamlandı.")
