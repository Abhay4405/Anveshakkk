import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../main.dart';
import 'storage_service.dart';

class ParentAuthPage extends StatefulWidget {
  const ParentAuthPage({super.key});

  @override
  State<ParentAuthPage> createState() => _ParentAuthPageState();
}

class _ParentAuthPageState extends State<ParentAuthPage> {

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  String? _selectedIdType;

  File? _mobileImage;
  Uint8List? _webImage;

  bool _verified = false;

  final ImagePicker _imagePicker = ImagePicker();

  // OTP related
  String? _registeredPhone;
  String? _verificationId;
  bool _otpSent = false;
  DateTime? _lastOtpRequestTime; // Track rate limiting
  static const int _otpRateLimitSeconds = 30; // Minimum 30 seconds between requests

  // WEB specific
  ConfirmationResult? _webConfirmationResult;
  bool _useWebOtpFallback = false; // Flag for web fallback
  
  // Development/Testing mode - for demo purposes
  static const bool _isDevelopmentMode = true; // Set to false in production
  static const String _developmentOtp = '123456'; // Test OTP code

  @override
  void initState() {
    super.initState();
    _loadRegisteredPhone();
  }

  @override
  void dispose() {
    idNumberController.dispose();
    otpController.dispose();
    super.dispose();
  }

  // ---------------- Load registered phone from Firestore ----------------
  Future<void> _loadRegisteredPhone() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('users').doc(user.uid).get();

    if (doc.exists && doc.data()!.containsKey('phone')) {
      setState(() {
        _registeredPhone = doc['phone'];
      });
    }
  }

  // ---------------- Pick ID image ----------------
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          _webImage = await pickedFile.readAsBytes();
          _mobileImage = null;
        } else {
          _mobileImage = File(pickedFile.path);
          _webImage = null;
        }
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // ---------------- SEND OTP (WEB + MOBILE) ----------------
  Future<void> _sendOtp() async {

    if (_registeredPhone == null || _registeredPhone!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered phone number not found')),
      );
      return;
    }

    // Rate limiting check
    if (_lastOtpRequestTime != null) {
      final secondsSinceLastRequest =
          DateTime.now().difference(_lastOtpRequestTime!).inSeconds;
      if (secondsSinceLastRequest < _otpRateLimitSeconds) {
        final waitSeconds = _otpRateLimitSeconds - secondsSinceLastRequest;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait ${waitSeconds}s before requesting OTP again'),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    final String phoneNumber = "+91${_registeredPhone!.trim()}";

    try {
      if (kIsWeb) {
        // 🔴 WEB FLOW - With fallback for unsupported browsers
        
        // In development/testing mode on web, skip real OTP and show test code
        if (_isDevelopmentMode) {
          print('📝 DEVELOPMENT MODE: Showing test OTP');
          if (!mounted) return;
          
          setState(() {
            _otpSent = true;
            _useWebOtpFallback = false;
            _lastOtpRequestTime = DateTime.now();
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📝 TEST MODE: Use OTP: $_developmentOtp'),
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
        
        try {
          final confirmationResult =
              await FirebaseAuth.instance.signInWithPhoneNumber(phoneNumber);

          _webConfirmationResult = confirmationResult;

          setState(() {
            _otpSent = true;
            _useWebOtpFallback = false;
            _lastOtpRequestTime = DateTime.now();
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ OTP sent to $phoneNumber')),
          );
        } on FirebaseAuthException catch (webError) {
          print('❌ Web OTP Error: ${webError.code} - ${webError.message}');

          // Check if it's a browser support issue or rate limiting
          if (webError.code == 'unsupported-user-agent' ||
              webError.code == 'web-storage-unsupported' ||
              webError.message?.contains('web-context') == true) {
            // Browser doesn't support OTP
            _showWebOtpFallback();
          } else if (webError.code == 'too-many-requests' ||
              webError.message?.contains('too-many-requests') == true) {
            // Rate limited by Firebase - automatically show fallback
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⏱️ Too many OTP requests. Showing alternative verification...',
                ),
                duration: Duration(seconds: 2),
              ),
            );
            // Auto-show fallback after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              _showWebOtpFallback();
            });
          } else {
            // Other web errors
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Browser Error: ${webError.message}'),
                duration: const Duration(seconds: 4),
              ),
            );
            _showWebOtpFallback();
          }
        }
      } else {
        // 🔴 MOBILE FLOW
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          timeout: const Duration(seconds: 60),

          verificationCompleted: (PhoneAuthCredential credential) async {
            print('✓ Phone verification completed automatically');
            try {
              await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);

              if (!mounted) return;
              setState(() {
                _verified = true;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Phone verified automatically')),
              );
            } catch (e) {
              print('❌ Link credential error: $e');
            }
          },

          verificationFailed: (FirebaseAuthException e) {
            print('❌ Verification failed: ${e.code} - ${e.message}');
            if (!mounted) return;
            
            // Check if rate limited
            if (e.code == 'too-many-requests' ||
                e.message?.contains('too-many-requests') == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⏱️ Too many requests. Please try again later.'),
                  duration: Duration(seconds: 3),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('OTP Error: ${e.message ?? 'Verification failed'}')),
              );
            }
          },

          codeSent: (String verificationId, int? resendToken) {
            print('✓ OTP code sent');
            if (!mounted) return;
            setState(() {
              _verificationId = verificationId;
              _otpSent = true;
              _lastOtpRequestTime = DateTime.now();
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✓ OTP sent to $phoneNumber')),
            );
          },

          codeAutoRetrievalTimeout: (String verificationId) {
            print('⏱️ Auto retrieval timeout');
            _verificationId = verificationId;
          },
        );
      }
    } catch (e) {
      print('❌ Send OTP Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending OTP: $e')),
      );
    }
  }

  // Fallback for web browsers that don't support OTP
  void _showWebOtpFallback() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ OTP Not Supported'),
        content: const Text(
          'Your browser does not support phone OTP authentication. '
          'Please:\n\n'
          '1. Try using Chrome, Firefox, or a mobile browser\n'
          '2. Or proceed without OTP verification (manual admin review)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _useWebOtpFallback = true);
            },
            child: const Text('Proceed Without OTP'),
          ),
        ],
      ),
    );
  }

  // ---------------- VERIFY OTP (WEB + MOBILE) ----------------
  Future<void> _verifyOtp() async {
    final otp = otpController.text.trim();

    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter OTP')),
      );
      return;
    }

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP must be 6 digits')),
      );
      return;
    }

    // In development mode on web, accept test OTP
    if (kIsWeb && _isDevelopmentMode) {
      if (otp == _developmentOtp) {
        print('✓ Development mode: Test OTP accepted');
        if (!mounted) return;
        setState(() {
          _verified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ OTP verified (Development Mode)')),
        );
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid OTP. Use: $_developmentOtp')),
        );
        return;
      }
    }

    try {
      if (kIsWeb) {
        if (_webConfirmationResult == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please send OTP first')),
          );
          return;
        }

        try {
          final userCredential =
              await _webConfirmationResult!.confirm(otp);

          if (userCredential.credential != null) {
            await FirebaseAuth.instance.currentUser!
                .linkWithCredential(userCredential.credential!);
          }
        } catch (webVerifyError) {
          print('❌ Web OTP Verification Error: $webVerifyError');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid OTP: $webVerifyError')),
          );
          return;
        }
      } else {
        if (_verificationId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please send OTP first')),
          );
          return;
        }

        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );

        await FirebaseAuth.instance.currentUser!
            .linkWithCredential(credential);
      }

      if (!mounted) return;
      setState(() {
        _verified = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Phone verified successfully')),
      );
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      if (!mounted) return;
      String message = 'Invalid OTP';
      if (e.code == 'invalid-verification-code') {
        message = 'Incorrect OTP. Please try again.';
      } else if (e.code == 'code-expired') {
        message = 'OTP expired. Please request a new one.';
      } else if (e.code == 'credential-already-in-use') {
        message = 'This phone number is already linked';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      print('❌ Verification Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ---------------- Submit verification details ----------------
  Future<void> _submitAuthDetails() async {
    try {

      if (!_formKey.currentState!.validate()) return;

      if (_mobileImage == null && _webImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload ID proof image')),
        );
        return;
      }

      final User? currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) return;

      // Upload ID image to Cloudinary
      final String idImageUrl = await uploadImage(
        _mobileImage,
        _webImage,
      );

      await _firestore
          .collection('user_verifications')
          .doc(currentUser.uid)
          .set({

        'user_email': currentUser.email,
        'id_type': _selectedIdType,
        'id_number': idNumberController.text.trim(),
        'id_photo_url': idImageUrl,

        // OTP verified only → admin verification pending
        'verification_status': 'Pending Admin Review',

        'verified_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification submitted. Proceeding...')),
      );

      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;
      Navigator.pushNamed(context, Routes.personDetails);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {

    final double formWidth =
        MediaQuery.of(context).size.width > 600 ? 500.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Lost: Step 1/2')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Container(
            width: formWidth,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    'Parent Authentication (OTP + ID)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 20),

                  _buildDropdownField(
                    'Select Government ID Type',
                    Icons.badge,
                    ['Aadhaar Card', 'Voter ID', 'Ration Card', 'Passport'],
                    (String? newValue) {
                      setState(() {
                        _selectedIdType = newValue;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  _buildTextField(
                    'Enter Selected ID Number',
                    Icons.credit_card,
                    controller: idNumberController,
                    keyboardType: TextInputType.text,
                  ),

                  const SizedBox(height: 20),

                  _buildUploadButton(
                    'Upload ID Proof Photo',
                    Icons.camera_alt,
                    Theme.of(context).colorScheme.secondary,
                  ),

                  const SizedBox(height: 10),

                  _buildImagePreview(context),

                  const SizedBox(height: 25),

                  // ---------------- OTP SECTION ----------------

                  if (_registeredPhone != null) ...[
                    Text(
                      'Registered Mobile : $_registeredPhone',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),

                    if (!_otpSent && !_useWebOtpFallback)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _sendOtp,
                          child: const Text('Send OTP'),
                        ),
                      ),

                    if (_useWebOtpFallback)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '⚠️ OTP not supported in this browser',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'You can proceed without OTP verification. '
                              'Your submission will be reviewed by admin.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() => _useWebOtpFallback = false);
                              },
                              child: const Text('Try OTP Again'),
                            ),
                          ],
                        ),
                      ),

                    if (_otpSent && !_useWebOtpFallback) ...[
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'Enter 6-digit OTP',
                          prefixIcon: Icon(Icons.lock),
                          counterText: '',
                          hintText: '000000',
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _verifyOtp,
                          child: const Text('Verify OTP'),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: _sendOtp,
                        child: const Text('Resend OTP'),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      'Registered mobile number not found.',
                      style: TextStyle(color: Colors.red),
                    )
                  ],

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_verified || _useWebOtpFallback) ? _submitAuthDetails : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_verified || _useWebOtpFallback)
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Proceed to Step 2 (Person Details)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Widgets ----------------

  Widget _buildTextField(
    String label,
    IconData icon, {
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).primaryColor.withOpacity(0.7),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        // Specific validation for ID number
        if (label.contains('ID Number') && value.length < 6) {
          return 'ID number should be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildDropdownField(
    String label,
    IconData icon,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).primaryColor.withOpacity(0.7),
        ),
      ),
      initialValue: _selectedIdType,
      hint: Text(label),
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) =>
          value == null ? 'Please select a valid ID type' : null,
    );
  }

  Widget _buildUploadButton(String label, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Photo Library'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Camera'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        icon: Icon(icon, color: color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          side: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    return Center(
      child: Container(
        width: 150,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .secondary
                .withOpacity(0.7),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: kIsWeb
            ? (_webImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _webImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image_search,
                        size: 40, color: Colors.grey),
                  ))
            : (_mobileImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _mobileImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image_search,
                        size: 40, color: Colors.grey),
                  )),
      ),
    );
  }
}
