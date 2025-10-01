import 'package:flutter/foundation.dart';

class CameraGroup {
  final String name;
  final List<String> cameraMacs; // Bu gruptaki kameraların MAC adresleri
  final List<String> users; // Bu gruba atanmış kullanıcılar
  final Map<String, dynamic> permissions; // Grup yetkileri

  CameraGroup({
    required this.name,
    List<String>? cameraMacs,
    List<String>? users,
    Map<String, dynamic>? permissions,
  }) : cameraMacs = cameraMacs ?? [],
       users = users ?? [],
       permissions = permissions ?? {};

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
      users: (json['users'] as List<dynamic>?)?.cast<String>() ?? [],
      permissions: (json['permissions'] as Map<String, dynamic>?) ?? {},
    );
  }

  // CameraGroup nesnesini JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cameraMacs': cameraMacs,
      'users': users,
      'permissions': permissions,
    };
  }

  // Kullanıcı ekle
  void addUser(String username) {
    if (!users.contains(username)) {
      users.add(username);
    }
  }

  // Kullanıcı çıkar
  void removeUser(String username) {
    users.remove(username);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CameraGroup &&
        other.name == name &&
        listEquals(other.cameraMacs, cameraMacs) &&
        listEquals(other.users, users) &&
        mapEquals(other.permissions, permissions);
  }

  @override
  int get hashCode => name.hashCode ^ 
      Object.hashAll(cameraMacs) ^ 
      Object.hashAll(users) ^ 
      Object.hashAll(permissions.entries);
}
