// parent_auth.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Dummy Routes class for navigation
class Routes {
  static const String personDetails = '/personDetails';
}

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
  String? _selectedIdType;
  dynamic _mobileImage;
  dynamic _webImage;
  final bool _verified = false;

  // Helper for web check
  bool get kIsWeb => identical(0, 0.0);

  // Dummy image picker
  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      if (kIsWeb) {
        _webImage = 'web_image_dummy';
      } else {
        _mobileImage = File('dummy_path');
      }
    });
  }

  Future<void> _submitAuthDetails(String imageUrl) async {
    try {
      final User? currentUser = _firebaseAuth.currentUser;
      await _firestore.collection('user_verifications').doc(currentUser!.uid).set({
        'user_email': currentUser.email,
        'id_type': _selectedIdType,
        'id_number': idNumberController.text.trim(),
        'id_photo_url': imageUrl,
        'verified_at': FieldValue.serverTimestamp(),
        'verification_status': 'Verified',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Verification submitted. Moving to Step 2...')),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushNamed(context, Routes.personDetails);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
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
                  Text('Parent Authentication (No OTP)', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  _buildDropdownField('Select Government ID Type', Icons.badge, ['Aadhaar Card', 'Voter ID', 'Ration Card', 'Passport'], (String? newValue) {
                    setState(() {
                      _selectedIdType = newValue;
                    });
                  }),
                  const SizedBox(height: 20),
                  _buildTextField('Enter Selected ID Number', Icons.credit_card, controller: idNumberController, keyboardType: TextInputType.number),
                  const SizedBox(height: 20),
                  _buildUploadButton('Upload ID Proof Photo', Icons.camera_alt, Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 10),
                  _buildImagePreview(context),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _verified ? () async {
                        await _submitAuthDetails('dummy_image_url');
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verified ? Theme.of(context).primaryColor : Colors.grey,
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
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Text('Web Image'))
                : const Center(child: Icon(Icons.image_search, size: 40, color: Colors.grey)))
            : (_mobileImage != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Text('Mobile Image'))
                : const Center(child: Icon(Icons.image_search, size: 40, color: Colors.grey))),
      ),
    );
  }
}