import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'storage_service.dart';
import 'matching_service.dart';
import 'match_result.dart';

class PersonFoundPage extends StatefulWidget {
  const PersonFoundPage({super.key});

  @override
  State<PersonFoundPage> createState() => _PersonFoundPageState();
}

class _PersonFoundPageState extends State<PersonFoundPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController locationController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  File? _mobileImage;
  Uint8List? _webImage;

  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------- IMAGE PICK ----------------
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        _webImage = await pickedFile.readAsBytes();
      } else {
        _mobileImage = File(pickedFile.path);
      }
      setState(() {});
    }
  }

  // ---------------- SUBMIT FOUND REPORT ----------------
  Future<void> _submitFoundReport() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null ||
        !_formKey.currentState!.validate() ||
        (_mobileImage == null && _webImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all details and upload photo')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading & running face matching...')),
      );

      // 1️⃣ Upload image to Cloudinary
      String foundImageUrl = await uploadImage(_mobileImage, _webImage);

      // 2️⃣ Save FOUND person (DB-2)
      DocumentReference foundDoc =
          await _firestore.collection('found_persons').add({
        'photo_url': foundImageUrl,
        'found_location': locationController.text.trim(),
        'contact': contactController.text.trim(),
        'finder_uid': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3️⃣ Fetch LOST persons (DB-1)
      QuerySnapshot lostSnapshot =
          await _firestore.collection('lost_persons').get();

      List<Map<String, dynamic>> matches = [];

      // 4️⃣ Run face matching against each lost person
      for (var doc in lostSnapshot.docs) {
        final lostData = doc.data() as Map<String, dynamic>;
        final String lostImageUrl = lostData['photo_url'] ?? '';

        // Skip invalid/simulated URLs
        if (lostImageUrl.isEmpty || 
            lostImageUrl.contains('SIMULATED') || 
            !lostImageUrl.startsWith('http')) {
          print('Skipping ${lostData['name']} - invalid URL');
          continue;
        }

        try {
          print('Matching with ${lostData['name']}...');
          final result = await MatchingService.runFaceMatching(
            foundImageUrl: foundImageUrl,
            lostImageUrl: lostImageUrl,
          );

          print('Result for ${lostData['name']}: ${result['matched']}, Confidence: ${result['confidence']}%');

          if (result['matched'] == true &&
              (result['confidence'] ?? 0) >= 40) {  // Reduced to match backend threshold
            print('✅ MATCH FOUND: ${lostData['name']}');
            
            // Get contact or use placeholder for testing
            String contactNumber = lostData['contact'] ?? '';
            if (contactNumber.isEmpty) {
              // Fallback for testing if contact is missing
              contactNumber = '9876543210'; // Default test number
            }
            
            matches.add({
              'lost_person_id': doc.id,
              'lost_report_id': doc.id,  // Add lost report ID
              'lost_person_name': lostData['name'],
              'lost_person_contact': contactNumber,
              'lost_person_age': lostData['age'] ?? 'N/A',
              'lost_person_gender': lostData['gender'] ?? 'N/A',
              'confidence': result['confidence'],
              'contact': contactNumber,
              'found_id': foundDoc.id,
              'found_report_id': foundDoc.id,  // Add found report ID
            });
          }
        } catch (matchError) {
          // Log matching error for this person, continue with next
          print('Matching error for ${lostData['name']}: $matchError');
          continue;
        }
      }

      // 5️⃣ Navigate to Match Result Page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchResultPage(matches: matches),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Person Found')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(
                  'Found Location',
                  locationController,
                  Icons.location_on,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  'Your Contact Number',
                  contactController,
                  Icons.phone,
                  TextInputType.phone,
                ),
                const SizedBox(height: 15),
                _buildDateField(),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: 200,
                  height: 200,
                  child: kIsWeb
                      ? (_webImage != null
                          ? Image.memory(_webImage!, fit: BoxFit.cover)
                          : const Icon(Icons.image))
                      : (_mobileImage != null
                          ? Image.file(_mobileImage!, fit: BoxFit.cover)
                          : const Icon(Icons.image)),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitFoundReport,
                    child: const Text('Submit & Match'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- HELPERS ----------------
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, [
    TextInputType keyboardType = TextInputType.text,
  ]) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Enter $label' : null,
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: dateController,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'Date Found',
        prefixIcon: Icon(Icons.calendar_today),
      ),
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          dateController.text =
              "${picked.day}/${picked.month}/${picked.year}";
        }
      },
      validator: (value) =>
          value == null || value.isEmpty ? 'Select date' : null,
    );
  }
}
