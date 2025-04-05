import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Utility class to determine the current platform
class PlatformUtils {
  // Check if running on desktop platform (Windows, macOS, Linux)
  static bool isDesktop() {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }
  
  // Check if running on mobile platform (Android, iOS)
  static bool isMobile() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
  
  // Check if running on web
  static bool isWeb() {
    return kIsWeb;
  }
  
  // Get platform name as string
  static String platformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isFuchsia) return 'Fuchsia';
    return 'Unknown';
  }
}
