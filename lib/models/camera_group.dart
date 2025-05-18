import 'package:flutter/foundation.dart';

class CameraGroup {
  final String name;
  final List<String> cameraMacs; // Bu gruptaki kameraların MAC adresleri

  CameraGroup({
    required this.name,
    List<String>? cameraMacs,
  }) : cameraMacs = cameraMacs ?? [];

  // Gruba kamera ekle
  void addCamera(String cameraMac) {
    if (!cameraMacs.contains(cameraMac)) {
      cameraMacs.add(cameraMac);
    }
  }

  // Gruptan kamera çıkar
  void removeCamera(String cameraMac) {
    cameraMacs.remove(cameraMac);
  }

  // Grup boş mu kontrol et
  bool get isEmpty => cameraMacs.isEmpty;

  // Gruptaki kamera sayısı
  int get cameraCount => cameraMacs.length;

  // JSON'dan CameraGroup nesnesi oluştur
  factory CameraGroup.fromJson(Map<String, dynamic> json) {
    return CameraGroup(
      name: json['name'] as String,
      cameraMacs: (json['cameraMacs'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  // CameraGroup nesnesini JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cameraMacs': cameraMacs,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraGroup &&
        other.name == name &&
        listEquals(other.cameraMacs, cameraMacs);
  }

  @override
  int get hashCode => name.hashCode ^ Object.hashAll(cameraMacs);
}
