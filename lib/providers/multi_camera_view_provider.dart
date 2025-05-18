import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/camera_device.dart';
import '../models/camera_layout_config.dart';

/// Multi Camera View için Provider sınıfı
/// Bu provider, çoklu kamera görünümü için gerekli state'i yönetir
class MultiCameraViewProvider with ChangeNotifier {
  // Tüm mevcut layout şablonları
  List<CameraLayoutConfig> _layouts = [];
  
  // Aktif sayfa dizini
  int _activePageIndex = 0;
  
  // Her sayfa için seçilen layout'lar (layoutCode değeri)
  List<int> _pageLayouts = [5]; // Varsayılan olarak 5 (2x2 grid) ile başla
  
  // Her sayfa için kamera mapping'i (sayfa indeksi -> konum -> kamera)
  // Map<Sayfa İndeksi, Map<Kamera Konumu, Kamera Kodu>>
  Map<int, Map<int, int>> _cameraAssignments = {};
  
  // Otomatik kamera atama modu
  bool _isAutoAssignmentMode = true;
  
  // Kameralar listesi (CameraDevice listesi)
  List<Camera> _availableCameras = [];

  // Constructor
  MultiCameraViewProvider() {
    // Başlangıçta layout dosyasını yükle
    _loadCameraLayouts();
    
    // İlk sayfa için boş bir kamera atama haritası oluştur
    _cameraAssignments[0] = {};
  }

  // Getters
  List<CameraLayoutConfig> get layouts => _layouts;
  int get activePageIndex => _activePageIndex;
  List<int> get pageLayouts => _pageLayouts;
  bool get isAutoAssignmentMode => _isAutoAssignmentMode;
  List<Camera> get availableCameras => _availableCameras;
  
  // Aktif layout getter'ı
  CameraLayoutConfig? get activeLayout {
    if (_layouts.isEmpty || _pageLayouts.isEmpty || _activePageIndex >= _pageLayouts.length) {
      return null;
    }
    
    int layoutCode = _pageLayouts[_activePageIndex];
    return _layouts.firstWhere(
      (layout) => layout.layoutCode == layoutCode,
      orElse: () => _layouts.first,
    );
  }
  
  // Aktif sayfadaki kamera atamaları
  Map<int, int> get activeCameraAssignments {
    return _cameraAssignments[_activePageIndex] ?? {};
  }

  // JSON dosyasından kamera layout'larını yükle
  Future<void> _loadCameraLayouts() async {
    try {
      final String jsonContent = await rootBundle.loadString('assets/layouts/cameraLayout.json');
      final List<dynamic> layoutsJson = jsonDecode(jsonContent);
      
      _layouts = layoutsJson.map((json) => CameraLayoutConfig.fromJson(json)).toList();
      
      // Layoutları layoutCode'a göre sırala
      _layouts.sort((a, b) => a.layoutCode.compareTo(b.layoutCode));
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading camera layouts: $e');
    }
  }
  
  // Kameraları ayarla
  void setAvailableCameras(List<Camera> cameras) {
    _availableCameras = cameras;
    
    // Eğer otomatik atama modu aktifse, kameraları otomatik olarak ata
    if (_isAutoAssignmentMode) {
      _autoAssignCameras();
    }
    
    notifyListeners();
  }
  
  // Otomatik kamera atama
  void _autoAssignCameras() {
    if (_availableCameras.isEmpty || activeLayout == null) return;
    
    final Map<int, int> assignments = {};
    final locations = activeLayout!.cameraLoc;
    
    // Her lokasyon için, mevcut kameralardan birini ata
    for (int i = 0; i < locations.length; i++) {
      if (i < _availableCameras.length) {
        int cameraPosition = locations[i].cameraCode;
        // index+1 değerini kullan (varsayılan CameraCode değil)
        assignments[cameraPosition] = i + 1;
      }
    }
    
    _cameraAssignments[_activePageIndex] = assignments;
    notifyListeners();
  }
  
  // Manuel kamera atama
  void assignCamera(int cameraPosition, int cameraIndex) {
    if (_cameraAssignments[_activePageIndex] == null) {
      _cameraAssignments[_activePageIndex] = {};
    }
    
    // Eğer cameraIndex 0 ise, kamerayı kaldır
    if (cameraIndex == 0) {
      _cameraAssignments[_activePageIndex]!.remove(cameraPosition);
    } else {
      _cameraAssignments[_activePageIndex]![cameraPosition] = cameraIndex;
    }
    
    notifyListeners();
  }
  
  // Aktif sayfa layout'unu değiştir
  void setActivePageLayout(int layoutCode) {
    if (_pageLayouts.length <= _activePageIndex) {
      // Eksik sayfalar için varsayılan layout ekle
      while (_pageLayouts.length <= _activePageIndex) {
        _pageLayouts.add(5); // Varsayılan 2x2 grid (layoutCode 5)
      }
    }
    
    _pageLayouts[_activePageIndex] = layoutCode;
    
    // Eğer otomatik atama modundaysak, kameraları otomatik olarak yeniden ata
    if (_isAutoAssignmentMode) {
      _autoAssignCameras();
    }
    
    notifyListeners();
  }
  
  // Aktif sayfa değiştir
  void setActivePage(int pageIndex) {
    if (pageIndex < 0) return;
    
    // Eğer yeni bir sayfa ise, varsayılan değerleri ayarla
    if (pageIndex >= _pageLayouts.length) {
      _pageLayouts.add(5); // Varsayılan 2x2 grid
      _cameraAssignments[pageIndex] = {};
    }
    
    _activePageIndex = pageIndex;
    
    // Eğer otomatik atama modundaysak, kameraları otomatik olarak yeniden ata
    if (_isAutoAssignmentMode) {
      _autoAssignCameras();
    }
    
    notifyListeners();
  }
  
  // Sayfa ekle
  void addPage() {
    int newPageIndex = _pageLayouts.length;
    _pageLayouts.add(5); // Varsayılan 2x2 grid
    _cameraAssignments[newPageIndex] = {};
    
    // Yeni sayfaya geç
    _activePageIndex = newPageIndex;
    
    notifyListeners();
  }
  
  // Sayfayı sil (aktif sayfa)
  void removePage() {
    if (_pageLayouts.length <= 1) return; // En az bir sayfa kalmalı
    
    _pageLayouts.removeAt(_activePageIndex);
    _cameraAssignments.remove(_activePageIndex);
    
    // Kalan sayfalardaki atama indekslerini güncelle
    final Map<int, Map<int, int>> updatedAssignments = {};
    
    _cameraAssignments.forEach((pageIndex, assignments) {
      if (pageIndex > _activePageIndex) {
        updatedAssignments[pageIndex - 1] = assignments;
      } else if (pageIndex < _activePageIndex) {
        updatedAssignments[pageIndex] = assignments;
      }
    });
    
    _cameraAssignments = updatedAssignments;
    
    // Aktif sayfayı güncelle
    if (_activePageIndex >= _pageLayouts.length) {
      _activePageIndex = _pageLayouts.length - 1;
    }
    
    notifyListeners();
  }
  
  // Otomatik/manuel atama modunu değiştir
  void toggleAssignmentMode() {
    _isAutoAssignmentMode = !_isAutoAssignmentMode;
    
    // Eğer otomatik moda geçildiyse, kameraları otomatik olarak yeniden ata
    if (_isAutoAssignmentMode) {
      _autoAssignCameras();
    }
    
    notifyListeners();
  }
}
