#!/usr/bin/env python3

def update_download_method():
    with open('lib/screens/record_view_screen.dart', 'r') as file:
        content = file.read()
    
    # Find and replace the _downloadRecording method
    old_method = '''  // İndirme işlevini başlat (Download function)
  void _downloadRecording(String recording) async {
    if (_selectedDay == null || _camera == null || _recordingsUrl == null) {
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
    
    // İndirme URL'sini oluştur
    final dateStr = DateFormat('yyyy_MM_dd').format(_selectedDay!);
    final dayUrl = '$_recordingsUrl$dateStr/';
    final downloadUrl = '$dayUrl$recording';
    
    // Bu URL'yi paylaşmak veya tarayıcıda açmak için ilgili platform API'lerini kullanabilirsiniz
    // Örneğin: url_launcher paketi ile tarayıcıda açma
    print('İndirme URL: $downloadUrl');'''
    
    new_method = '''  // İndirme işlevini başlat (Download function)
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
  }'''
    
    if old_method in content:
        content = content.replace(old_method, new_method)
        
        with open('lib/screens/record_view_screen.dart', 'w') as file:
            file.write(content)
        
        return "Download method updated successfully."
    else:
        return "Download method not found as expected. No changes made."

print(update_download_method())
