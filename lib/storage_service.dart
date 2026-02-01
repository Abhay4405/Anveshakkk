// lib/storage_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

// ⚠️ CLOUDINARY CREDENTIALS ⚠️
const String CLOUD_NAME = 'dz2ywqrmt'; // e.g., 'd****67g'
const String UPLOAD_PRESET = 'anveshak_preset'; // The Unsigned Preset Name created

// Cloudinary's secure upload URL
const String CLOUDINARY_URL = 'https://api.cloudinary.com/v1_1/$CLOUD_NAME/image/upload';

// Upload timeout - increased for large images
const int UPLOAD_TIMEOUT_SECONDS = 120;
const int MAX_RETRIES = 3;

// Function to upload image to Cloudinary with retry logic
Future<String> uploadImage(File? mobileImage, Uint8List? webImage, {int retryCount = 0}) async {
  if (mobileImage == null && webImage == null) {
    throw Exception("No image provided for upload");
  }

  try {
    developer.log('📤 Uploading image (Attempt ${retryCount + 1}/$MAX_RETRIES)...');
    
    var request = http.MultipartRequest('POST', Uri.parse(CLOUDINARY_URL));
    request.fields['upload_preset'] = UPLOAD_PRESET;

    if (kIsWeb && webImage != null) {
      // Web Upload (using Byte data)
      developer.log('📤 Web upload: ${webImage.length} bytes');
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', 
          webImage,
          filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
    } else if (mobileImage != null) {
      // Mobile Upload (using File path)
      final fileSize = await mobileImage.length();
      developer.log('📤 Mobile upload: ${fileSize ~/ (1024 * 1024)} MB');
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          mobileImage.path,
          filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
    } else {
      throw Exception("Invalid image state for upload.");
    }
    
    var response = await request.send().timeout(
      const Duration(seconds: UPLOAD_TIMEOUT_SECONDS),
      onTimeout: () => throw Exception('Upload timeout after ${UPLOAD_TIMEOUT_SECONDS}s'),
    );

    if (response.statusCode == 200) {
      // Success
      final responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);
      
      developer.log('✓ Upload successful: ${data['secure_url']}');
      // Return the secure URL
      return data['secure_url']; 
    } else {
      // Failure
      final responseData = await response.stream.bytesToString();
      developer.log('❌ Upload failed: ${response.statusCode}');
      throw Exception('Cloudinary Upload Failed: ${response.statusCode} - $responseData');
    }

  } catch (e) {
    developer.log('❌ Cloudinary Error (Attempt ${retryCount + 1}): $e');
    
    // Retry logic
    if (retryCount < MAX_RETRIES - 1) {
      developer.log('🔄 Retrying upload...');
      await Future.delayed(Duration(seconds: 2 * (retryCount + 1))); // Exponential backoff
      return uploadImage(mobileImage, webImage, retryCount: retryCount + 1);
    }
    
    throw Exception('Failed to upload image after $MAX_RETRIES attempts: $e');
  }
}