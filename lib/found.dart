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
  
  String? selectedGender = 'Unknown'; // Default gender for found person

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
        'gender': selectedGender ?? 'Unknown',
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
              (result['confidence'] ?? 0) >= 60) {  // Stricter threshold - 60%+
            print('✅ MATCH FOUND: ${lostData['name']}');
            
            // Get contact from lost person's registration
            String contactNumber = lostData['contact']?.toString().trim() ?? '';
            if (contactNumber.isEmpty) contactNumber = 'N/A';
            
            matches.add({
              'lost_person_id': doc.id,
              'lost_report_id': doc.id,  // Add lost report ID
              'lost_person_name': lostData['name'],
              'lost_person_contact': contactNumber,
              'lost_person_age': lostData['age'] ?? 'N/A',
              'lost_person_gender': lostData['gender'] ?? 'Unknown',
              'lost_person_photo_url': lostImageUrl,  // Lost person's original photo
              'found_person_photo_url': foundImageUrl,  // Found person's photo
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade50, Colors.green.shade100],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, Colors.green.shade500],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Report Person Found',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Form Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
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
                            _buildTextField(
                              'Found Location',
                              locationController,
                              Icons.location_on,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              'Your Contact Number',
                              contactController,
                              Icons.phone,
                              TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: selectedGender,
                              decoration: InputDecoration(
                                labelText: 'Found Person Gender (Approx.)',
                                prefixIcon: Icon(Icons.transgender, color: Colors.green[700]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                                DropdownMenuItem(value: 'Unknown', child: Text('Unknown')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedGender = value;
                                });
                              },
                              validator: (value) => value == null ? 'Please select gender' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildDateField(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Photo Buttons
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
                            Text(
                              'Capture Photo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Camera'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                    icon: const Icon(Icons.photo),
                                    label: const Text('Gallery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Photo Preview
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 400),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!, width: 2),
                              ),
                              child: kIsWeb
                                  ? (_webImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.memory(_webImage!, fit: BoxFit.contain),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.image, size: 60, color: Colors.grey[400]),
                                            const SizedBox(height: 8),
                                            Text(
                                              'No image selected',
                                              style: TextStyle(color: Colors.grey[500]),
                                            ),
                                          ],
                                        ))
                                  : (_mobileImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.file(_mobileImage!, fit: BoxFit.contain),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.image, size: 60, color: Colors.grey[400]),
                                            const SizedBox(height: 8),
                                            Text(
                                              'No image selected',
                                              style: TextStyle(color: Colors.grey[500]),
                                            ),
                                          ],
                                        )),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submitFoundReport,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Submit & Match'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
        prefixIcon: Icon(icon, color: Colors.green[700]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green[700]!, width: 2),
        ),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Enter $label' : null,
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: dateController,
      readOnly: true,
      decoration: InputDecoration(
        labelText: 'Date Found',
        prefixIcon: Icon(Icons.calendar_today, color: Colors.green[700]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green[700]!, width: 2),
        ),
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
