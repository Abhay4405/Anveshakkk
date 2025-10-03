// lib/services/storage_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ⚠️ APNE CLOUDINARY CREDENTIALS YAHAN DALEIN ⚠️
const String CLOUD_NAME = 'dz2ywqrmt'; // e.g., 'd****67g'
const String UPLOAD_PRESET = 'anveshak_preset'; // The Unsigned Preset Name you created

// Cloudinary's secure upload URL
const String CLOUDINARY_URL = 'https://api.cloudinary.com/v1_1/$CLOUD_NAME/image/upload';


// Function to upload image to Cloudinary
Future<String> uploadImage(File? mobileImage, Uint8List? webImage) async {
  if (mobileImage == null && webImage == null) {
    // If no image is available but function is called, return dummy status
    return "IMAGE_UPLOAD_SKIPPED";
  }

  try {
    var request = http.MultipartRequest('POST', Uri.parse(CLOUDINARY_URL));
    request.fields['upload_preset'] = UPLOAD_PRESET;

    if (kIsWeb && webImage != null) {
      // Web Upload (using Byte data)
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', 
          webImage,
          filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
    } else if (mobileImage != null) {
      // Mobile Upload (using File path)
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
    
    var response = await request.send();

    if (response.statusCode == 200) {
      // Success
      final responseData = await response.stream.bytesToString();
      final data = json.decode(responseData);
      
      // Return the secure URL
      return data['secure_url']; 
    } else {
      // Failure
      final responseData = await response.stream.bytesToString();
      throw Exception('Cloudinary Upload Failed with status ${response.statusCode}: $responseData');
    }

  } catch (e) {
    print('Cloudinary Error: $e');
    throw Exception('Failed to upload image due to network or API error: $e');
  }
}