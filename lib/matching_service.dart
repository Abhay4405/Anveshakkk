import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'backend_config.dart';

final String BASE_URL = getFaceBackendUrl();
const int TIMEOUT_SECONDS = 120;  // Increased for model loading

class MatchingService {
  /// Calls Python FastAPI face-matching backend
  /// Returns: {"matched": bool, "confidence": double, "distance": double}
  static Future<Map<String, dynamic>> runFaceMatching({
    required String foundImageUrl,
    required String lostImageUrl,
    double? minConfidence, // optional percentage (e.g., 40.0)
  }) async {
    try {
      developer.log('═══════════════════════════════════════');
      developer.log('🔍 Starting face matching...');
      developer.log('Lost Image: $lostImageUrl');
      developer.log('Found Image: $foundImageUrl');
      developer.log('Backend URL: $BASE_URL');
      
      final requestBody = <String, dynamic>{
        "img1_url": lostImageUrl,
        "img2_url": foundImageUrl,
      };
      if (minConfidence != null) {
        requestBody['min_confidence'] = minConfidence;
      }
      
      developer.log('Request body: ${jsonEncode(requestBody)}');
      
      // Try to make the request directly
      final response = await http.post(
        Uri.parse("$BASE_URL/match-face"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: TIMEOUT_SECONDS),
        onTimeout: () => throw Exception('Face matching timeout after ${TIMEOUT_SECONDS}s'),
      );

      developer.log('✓ Response status: ${response.statusCode}');
      developer.log('✓ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log('✓ Face matching successful: $result');
        developer.log('═══════════════════════════════════════');
        return result;
      } else {
        final errorMsg = 'Face matching failed with status ${response.statusCode}: ${response.body}';
        developer.log('❌ $errorMsg');
        developer.log('═══════════════════════════════════════');
        throw Exception(errorMsg);
      }
    } catch (e) {
      developer.log('❌ Face matching error: $e');
      developer.log('═══════════════════════════════════════');
      throw Exception('Face matching error: $e');
    }
  }
  
  
  /// Check if backend is running
  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse("$BASE_URL/health"),
      ).timeout(const Duration(seconds: 5));
      
      final isHealthy = response.statusCode == 200;
      developer.log('💚 Backend health check: ${isHealthy ? "✓ RUNNING" : "✗ DOWN"} (Status: ${response.statusCode})');
      return isHealthy;
    } catch (e) {
      developer.log('💔 Health check failed: $e');
      return false;
    }
  }
}
