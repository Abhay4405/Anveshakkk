// parent_auth.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'storage_service.dart'; // Cloudinary service
import '../main.dart';

class ParentAuthPage extends StatefulWidget {
  const ParentAuthPage({super.key});

  @override
  _ParentAuthPageState createState() => _ParentAuthPageState();
}

class _ParentAuthPageState extends State<ParentAuthPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedIdType;
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController otpController = TextEditingController(); 

  // States for image handling
  File? _mobileImage;
  Uint8List? _webImage;
  final ImagePicker _picker = ImagePicker();
  
  // Firebase Instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      if (kIsWeb) {
        _webImage = await pickedFile.readAsBytes();
      } else {
        _mobileImage = File(pickedFile.path);
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Proof Image Selected.')),
      );
    }
  }

  // Authentication Submission Function (Step 1)
  Future<void> _submitAuthDetails() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not authenticated. Please log in again.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate() || (_mobileImage == null && _webImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select ID proof photo.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading ID Proof and verifying details...')),
    );

    try {
      // 1. Cloudinary Image Upload
      String imageUrl = await uploadImage(
        _mobileImage,
        _webImage,
      );

      // 2. Firestore Document Save (Verification Record)
      await _firestore.collection('user_verifications').doc(currentUser.uid).set({
        'user_email': currentUser.email,
        'id_type': _selectedIdType,
        'id_number': idNumberController.text.trim(),
        'id_photo_url': imageUrl, // Cloudinary URL save hoga
        'otp_entered': otpController.text.trim(),
        'verification_status': 'Pending Admin Review',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Success: Proceed to Step 2
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification submitted. Proceeding to Step 2.')),
      );
      Navigator.pushNamed(context, Routes.personDetails); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload Failed: ${e.toString().split(':')[0]}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double formWidth = MediaQuery.of(context).size.width > 600 ? 500.0 : double.infinity;

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
                BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressBar(context, 1),
                  const SizedBox(height: 20),
                  Text(
                    'Verify Parent Identity (Authentication)',
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 30),

                  // ID Type Selection
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

                  // ID Number Input
                  _buildTextField('Enter Selected ID Number', Icons.credit_card, controller: idNumberController, keyboardType: TextInputType.number),
                  const SizedBox(height: 20),

                  // Upload ID Proof Button
                  _buildUploadButton('Upload ID Proof Photo', Icons.camera_alt, Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 10),

                  // Image Preview (for feedback)
                  _buildImagePreview(context),
                  
                  const SizedBox(height: 10),
                  Center(child: Text('Image is required for proof and will be uploaded.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                  const SizedBox(height: 30),
                  
                  // OTP Check
                  _buildTextField('Enter OTP (Dummy for now)', Icons.sms_outlined, controller: otpController, keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  Center(child: Text('Final verification via OTP to ensure contact details are correct', style: TextStyle(fontSize: 12, color: Colors.grey))),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitAuthDetails,
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
  
  // Image Preview Widget
  Widget _buildImagePreview(BuildContext context) {
    return Center(
      child: Container(
        width: 150,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.7), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: kIsWeb
            ? (_webImage != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_webImage!, fit: BoxFit.cover))
                : const Center(child: Icon(Icons.image_search, size: 40, color: Colors.grey)))
            : (_mobileImage != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_mobileImage!, fit: BoxFit.cover))
                : const Center(child: Icon(Icons.image_search, size: 40, color: Colors.grey))),
      ),
    );
  }

  // Progress Bar Helper
  Widget _buildProgressBar(BuildContext context, int step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $step of 2', style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: step / 2,
          backgroundColor: Colors.grey[300],
          color: Theme.of(context).colorScheme.secondary,
        ),
      ],
    );
  }

  // Helper Widgets 
  Widget _buildTextField(String label, IconData icon, {required TextEditingController controller, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
      ),
      validator: (value) => value!.isEmpty ? 'Please enter $label' : null,
    );
  }
  
  Widget _buildDropdownField(String label, IconData icon, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
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
      validator: (value) => value == null ? 'Please select a valid ID type' : null,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          side: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }
}