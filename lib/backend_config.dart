import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

// 🔥 Face Matching (FastAPI)
String getFaceBackendUrl() {
  if (kIsWeb) return "http://localhost:9000";

  if (Platform.isAndroid) {
    return "http://192.168.43.159:9000";
  } else {
    return "http://localhost:9000";
  }
}

// 🔥 OTP Backend (Node.js)
String getOtpBackendUrl() {
  if (kIsWeb) return "http://localhost:8000";

  if (Platform.isAndroid) {
    return "http://192.168.43.159:8000";
  } else {
    return "http://localhost:8000";
  }
}

/// Get backend URL for specific route
String getFaceRoute(String route) {
  return "${getFaceBackendUrl()}$route";
}

String getOtpRoute(String route) {
  return "${getOtpBackendUrl()}$route";
}
