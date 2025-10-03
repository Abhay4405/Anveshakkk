// found.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'storage_service.dart'; 
import 'matching_service.dart'; // IMPORTANT
import '../main.dart';
import 'match_result.dart'; // IMPORTANT

class PersonFoundPage extends StatefulWidget {
  const PersonFoundPage({super.key});

  @override
  _PersonFoundPageState createState() => _PersonFoundPageState();
}

class _PersonFoundPageState extends State<PersonFoundPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController(); // TEMPORARY Age input
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController contactController = TextEditingController();  

  File? _mobileImage;
  Uint8List? _webImage;
  final ImagePicker _picker = ImagePicker();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      if (kIsWeb) {
        _webImage = await pickedFile.readAsBytes();
      } else {
        _mobileImage = File(pickedFile.path);
      }
      setState(() {});
    }
  }

  // SUBMISSION FUNCTION (DB 2) - Now runs matching
  Future<void> _submitFoundReport() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null || !_formKey.currentState!.validate() || (_mobileImage == null && _webImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in, fill all details, and upload a photo.')),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading report and running matching algorithm...')),
    );

    try {
      // 1. Cloudinary Image Upload
      String imageUrl = await uploadImage(_mobileImage, _webImage);

      // 2. Prepare data for Firestore and Matching
      Map<String, dynamic> newFoundPersonData = {
        'name_if_known': nameController.text.trim(),
        'contact': contactController.text.trim(),
        'found_location': locationController.text.trim(),
        'date_found': dateController.text.trim(),
        'photo_url': imageUrl,
        'finder_uid': currentUser.uid, 
        'is_matched': false, 
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 3. Firestore Document Save (Database 2)
      await _firestore.collection('found_persons').add(newFoundPersonData);
      
      // 4. Run Matching Algorithm 
      List<Map<String, dynamic>> matches = await runMatchingAlgorithm(newFoundPersonData);

      // Success
      if (matches.isNotEmpty) {
        // Navigate to the Match Result Screen
        Navigator.push(context, MaterialPageRoute(builder: (context) => MatchResultPage(matches: matches)));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. No immediate match found.')),
        );
        Navigator.pop(context); 
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission Error: ${e.toString().split(':')[0]}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;
    const double paddingValue = 20.0;
    final double formWidth = isWeb ? 600.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Person Found')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(paddingValue),
          child: Container(
            width: formWidth,
            padding: EdgeInsets.all(isWeb ? 40 : 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, spreadRadius: 5),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NOTE: Name field is used as Age input for matching test
                  _buildTextField('Full Name / Approx. Age (Testing)', nameController, Icons.person_pin), 
                  const SizedBox(height: 15),
                  _buildTextField('Your Contact (for follow-up)', contactController, Icons.phone, TextInputType.phone),
                  const SizedBox(height: 15),
                  _buildTextField('Found Location', locationController, Icons.my_location),
                  const SizedBox(height: 15),
                  _buildDateField('Date Found', dateController, Icons.calendar_today),
                  const SizedBox(height: 30),

                  const Text('Upload Current Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Photo is required for matching and will be uploaded to Cloudinary.', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImagePickerButton(Icons.camera_alt, 'Camera', () => _pickImage(ImageSource.camera), context),
                      _buildImagePickerButton(Icons.photo, 'Gallery', () => _pickImage(ImageSource.gallery), context),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5), width: 2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: kIsWeb
                          ? (_webImage != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.memory(_webImage!, fit: BoxFit.cover))
                              : const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)))
                          : (_mobileImage != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_mobileImage!, fit: BoxFit.cover))
                              : const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey))),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitFoundReport,
                      child: const Text('Submit Report'),
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

  // Helper functions... (same as before)
  Widget _buildTextField(String label, TextEditingController controller, IconData icon, [TextInputType keyboardType = TextInputType.text]) {
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

  Widget _buildDateField(String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now());
        if (pickedDate != null) {
          controller.text = "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7)),
      ),
      validator: (value) => value!.isEmpty ? 'Please select $label' : null,
    );
  }

  Widget _buildImagePickerButton(IconData icon, String label, VoidCallback onPressed, BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), width: 1),
        ),
      ),
    );
  }
}