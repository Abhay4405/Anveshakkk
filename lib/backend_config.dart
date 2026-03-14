import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// Shared backend configuration for all API calls
/// 
/// 📱 FOR DIFFERENT SCENARIOS:
/// 1. Android Emulator → 10.0.2.2:9000 (special IP for host machine)
/// 2. Physical Android Device → CHANGE TO YOUR PC'S IP (e.g., 192.168.x.x:9000)
/// 3. Web Browser (localhost) → http://localhost:9000
/// 4. iOS Device → CHANGE TO YOUR PC'S IP (e.g., 192.168.x.x:9000)
/// 
/// 🔧 TO FIND YOUR PC'S IP ON WINDOWS:
///    Command: ipconfig
///    Look for "IPv4 Address" (usually something like 192.168.x.x)
///
/// ⚠️ IMPORTANT: Make sure port 9000 is accessible from your network!

String getBackendUrl() {
  // Web platform check first (kIsWeb doesn't use dart:io)
  if (kIsWeb) {
    return "http://localhost:9000";
  }
  
  // Mobile/Desktop platforms (only available on native)
  if (Platform.isAndroid) {
    // Android Emulator uses 10.0.2.2 to refer to host machine's localhost
    return "http://192.168.43.159:9000";
  } else if (Platform.isIOS) {
    // For iOS Simulator, use localhost; for physical iOS, use your PC's IP
    return "http://localhost:9000"; // Change to your PC's IP for physical device (e.g., 192.168.x.x)
  } else {
    // Desktop platforms (Windows, Linux, macOS)
    return "http://localhost:9000";
  }
}

/// Get backend URL for specific route
String getBackendRoute(String route) {
  return "${getBackendUrl()}$route";
}
