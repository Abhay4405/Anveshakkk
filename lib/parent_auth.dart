import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'storage_service.dart';
import 'backend_config.dart';

class ParentAuthPage extends StatefulWidget {
  const ParentAuthPage({super.key});

  @override
  State<ParentAuthPage> createState() => _ParentAuthPageState();
}

class _ParentAuthPageState extends State<ParentAuthPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController emailOtpController = TextEditingController();
  final TextEditingController emailInputController = TextEditingController();

  String? _selectedIdType;

  File? _mobileImage;
  Uint8List? _webImage;

  bool _verified = false;
  bool _isProcessingImage = false;
  // MLKit is only supported on Android/iOS, not Web
  TextRecognizer? _textRecognizer;

  final ImagePicker _imagePicker = ImagePicker();

  String? _currentEmailForOtp;
  bool _emailOtpSent = false;

  // ================= SEND OTP =================
  Future<void> _sendEmailOtp() async {
    try {
      final email = emailInputController.text.trim();

      if (email.isEmpty || !email.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid email')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse("${getOtpBackendUrl()}/send-otp"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          _emailOtpSent = true;
          _currentEmailForOtp = email;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent to $email')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to send OTP')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server error')),
      );
    }
  }

  // ================= VERIFY OTP =================
  Future<void> _verifyEmailOtp() async {
    try {
      final response = await http.post(
        Uri.parse("${getOtpBackendUrl()}/verify-otp"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _currentEmailForOtp,
          'otp': emailOtpController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          _verified = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email OTP verified successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Invalid OTP')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server error')),
      );
    }
  }

  // ================= IMAGE UPLOAD =================
  Future<void> _uploadIdPhoto({bool fromGallery = false}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        setState(() {
          _isProcessingImage = true;
        });

        File imageFile;
        if (kIsWeb) {
          _webImage = await pickedFile.readAsBytes();
          setState(() {});
        } else {
          imageFile = File(pickedFile.path);
          _mobileImage = imageFile;
          setState(() {});

          // Run OCR on the captured/picked image
          await _extractTextFromImage(imageFile);
        }

        setState(() {
          _isProcessingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _extractTextFromImage(File imageFile) async {
    try {
      if (kIsWeb) return; // OCR not supported on web
      // Lazily initialise the recogniser only when needed on mobile
      _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);

      // Log the raw OCR output for debugging
      String extractedText = recognizedText.text;
      debugPrint("=== OCR RAW TEXT ===\n$extractedText\n===================");

      String? foundId;

      if (_selectedIdType == 'Aadhar') {
        // Aadhar: 12 digits, possibly with spaces or dashes between groups of 4
        // Handles: "1234 5678 9012" or "1234-5678-9012" or "123456789012"
        final aadharRegExp = RegExp(r'\d{4}[\s\-]?\d{4}[\s\-]?\d{4}');
        final match = aadharRegExp.firstMatch(extractedText);
        if (match != null) {
          foundId = match.group(0)?.replaceAll(RegExp(r'[\s\-]'), '');
        }
      } else if (_selectedIdType == 'Pan Card') {
        // PAN: 5 letters + 4 digits + 1 letter, case-insensitive OCR output
        final panRegExp = RegExp(r'[A-Za-z]{5}[0-9]{4}[A-Za-z]{1}');
        final match = panRegExp.firstMatch(extractedText);
        if (match != null) {
          foundId = match.group(0)?.toUpperCase();
        }
      } else if (_selectedIdType == 'Driving License') {
        // DL format varies by state: e.g. MH0120230001234
        // Broad pattern: 2 letters + digits, total length 10-16
        final dlRegExp = RegExp(r'[A-Za-z]{2}[\s\-]?\d{2}[\s\-]?\d{4}[\s\-]?\d{7}');
        final match = dlRegExp.firstMatch(extractedText);
        if (match != null) {
          foundId = match.group(0)?.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
        }
      } else if (_selectedIdType == 'Passport') {
        // Passport: 1 letter + 7 digits (Indian passport)
        final passportRegExp = RegExp(r'[A-Za-z]\d{7}');
        final match = passportRegExp.firstMatch(extractedText);
        if (match != null) {
          foundId = match.group(0)?.toUpperCase();
        }
      }

      // If still not found, try a smart fallback: pick the longest alphanumeric token
      if (foundId == null) {
        final fallbackRegExp = RegExp(r'[A-Za-z0-9]{8,16}');
        final matches = fallbackRegExp.allMatches(extractedText).toList();
        if (matches.isNotEmpty) {
          // Pick the longest match, likely to be the ID
          matches.sort((a, b) => b.group(0)!.length.compareTo(a.group(0)!.length));
          foundId = matches.first.group(0)?.toUpperCase();
        }
      }

      debugPrint("=== OCR EXTRACTED ID: $foundId ===");

      if (foundId != null && mounted) {
        setState(() {
          idNumberController.text = foundId!;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ID auto-filled: $foundId'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } else if (mounted) {
        // Show what OCR read so user knows what happened
        _showOcrResultDialog(extractedText);
      }
    } catch (e) {
      debugPrint("OCR Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    }
  }

  void _showOcrResultDialog(String rawText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OCR Could Not Find ID'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The text detected in the image:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  rawText.isEmpty ? '(No text detected)' : rawText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please type your ID number in the field below, or retake with a clearer image.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, I\'ll type it'),
          ),
        ],
      ),
    );
  }

  // ================= SUBMIT =================
  Future<void> _submitAuthDetails() async {
    try {
      if (!_formKey.currentState!.validate()) return;

      if (!_verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify OTP first')),
        );
        return;
      }

      final idNumber = idNumberController.text;
      final email = _currentEmailForOtp;

      // Save to Firestore immediately (without photo URL) so nav is instant
      await _firestore.collection('users').doc(idNumber).set({
        'verified': true,
        'verificationTime': DateTime.now(),
        'email': email,
        'idPhoto': null,
      }, SetOptions(merge: true));

      // Navigate immediately — don't wait for upload
      if (mounted) {
        Navigator.of(context).pushNamed(
          '/personLost',
          arguments: idNumber,
        );
      }

      // Upload image in background after navigation
      if (_mobileImage != null || _webImage != null) {
        final mobileImg = _mobileImage;
        final webImg = _webImage;
        uploadImage(mobileImg, webImg).then((photoUrl) {
          _firestore.collection('users').doc(idNumber).update({
            'idPhoto': photoUrl,
          });
          debugPrint('✅ Background photo upload done: $photoUrl');
        }).catchError((e) {
          debugPrint('⚠️ Background photo upload failed: $e');
          // Non-critical — user can still proceed
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _textRecognizer?.close();
    idNumberController.dispose();
    emailOtpController.dispose();
    emailInputController.dispose();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child:
                            const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Parent Auth',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Secure Verification',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ================= STEP 1: ID VERIFICATION =================
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.card_membership,
                                      color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Step 1: ID Verification',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedIdType,
                              decoration: InputDecoration(
                                labelText: 'Select ID Type',
                                prefixIcon: Icon(Icons.card_membership,
                                    color: Colors.blue[700]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.blue[700]!, width: 2),
                                ),
                              ),
                              items: [
                                'Aadhar',
                                'Pan Card',
                                'Driving License',
                                'Passport'
                              ]
                                  .map((e) => DropdownMenuItem(
                                      value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedIdType = val),
                              validator: (val) =>
                                  val == null ? 'Select ID type' : null,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                              // Image preview / loading / placeholder
                              Builder(builder: (context) {
                                if (_isProcessingImage) {
                                  return Container(
                                    height: 150,
                                    color: Colors.blue.shade50,
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 10),
                                          Text('Reading ID...', style: TextStyle(fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (_webImage != null) {
                                  return Image.memory(_webImage!, height: 150);
                                } else if (_mobileImage != null) {
                                  return Image.file(_mobileImage!, height: 150);
                                } else {
                                  return Column(
                                    children: [
                                      Icon(Icons.image_not_supported, size: 48, color: Colors.blue[700]),
                                      const SizedBox(height: 8),
                                      const Text('No image selected'),
                                    ],
                                  );
                                }
                              }),
                                  const SizedBox(height: 12),
                                  // OCR hint text
                                  if (!kIsWeb && (_mobileImage != null || _webImage != null) && !_isProcessingImage)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.auto_fix_high, size: 14, color: Colors.blue[600]),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'OCR reading done — check the ID Number field below',
                                              style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isProcessingImage ? null : () => _uploadIdPhoto(fromGallery: false),
                                          icon: const Icon(Icons.camera_alt, size: 18),
                                          label: const Text('Camera'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[700],
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isProcessingImage ? null : () => _uploadIdPhoto(fromGallery: true),
                                          icon: const Icon(Icons.photo_library, size: 18),
                                          label: const Text('Gallery'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[100],
                                            foregroundColor: Colors.blue[900],
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: idNumberController,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                labelText: 'ID Number',
                                prefixIcon: Icon(Icons.numbers,
                                    color: Colors.blue[700]),
                                hintText: 'Enter your ID number',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.blue[700]!, width: 2),
                                ),
                              ),
                              validator: (val) => val == null || val.isEmpty
                                  ? 'Enter ID number'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ================= STEP 2: EMAIL OTP =================
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.email,
                                      color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Step 2: Email Verification',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Email Address',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: emailInputController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Enter your email',
                                prefixIcon:
                                    Icon(Icons.email, color: Colors.blue[700]),
                                hintText: 'example@example.com',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.blue[700]!, width: 2),
                                ),
                              ),
                              validator: (val) =>
                                  val == null || !val.contains('@')
                                      ? 'Enter valid email'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            if (!_emailOtpSent)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _sendEmailOtp,
                                  icon: const Icon(Icons.mark_email_unread),
                                  label: const Text('Send OTP to Email'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            if (_emailOtpSent) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.green.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        color: Colors.green[700], size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'OTP sent to $_currentEmailForOtp',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Enter 6-digit OTP',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: emailOtpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 10,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'OTP',
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.blue[700]!, width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _verifyEmailOtp,
                                  icon: const Icon(Icons.verified),
                                  label: const Text('Verify OTP'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[700],
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ================= SUBMIT =================
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: _verified
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.25),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _verified ? _submitAuthDetails : null,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Proceed to Profile Creation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _verified
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[400],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
