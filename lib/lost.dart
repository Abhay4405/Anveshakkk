import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb

class PersonLostPage extends StatefulWidget {
  const PersonLostPage({super.key});

  @override
  _PersonLostPageState createState() => _PersonLostPageState();
}

class _PersonLostPageState extends State<PersonLostPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController genderController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  File? _mobileImage;
  Uint8List? _webImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        if (kIsWeb) {
          _webImage = await pickedFile.readAsBytes();
        } else {
          _mobileImage = File(pickedFile.path);
        }
        setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;
    final double paddingValue = isWeb ? 80.0 : 20.0;
    final double formWidth = isWeb ? 600.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: Text('Report Person Lost')),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(paddingValue),
          child: Container(
            width: formWidth,
            padding: EdgeInsets.all(isWeb ? 40 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
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
                  Text(
                    'Missing Person Details (Database 1)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                  SizedBox(height: 25),

                  _buildTextField('Full Name', nameController, Icons.person),
                  SizedBox(height: 15),
                  _buildTextField('Age', ageController, Icons.calendar_today, TextInputType.number),
                  SizedBox(height: 15),
                  _buildTextField('Gender', genderController, Icons.transgender),
                  SizedBox(height: 15),
                  _buildTextField('Last Seen Address', addressController, Icons.location_on),
                  SizedBox(height: 15),
                  _buildTextField('Your Contact Number', contactController, Icons.phone, TextInputType.phone),
                  SizedBox(height: 15),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description / Distinctive Features',
                      prefixIcon: Icon(Icons.description),
                    ),
                  ),
                  SizedBox(height: 30),

                  Text('Upload Recent Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 15),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImagePickerButton(Icons.camera_alt, 'Camera', () => _pickImage(ImageSource.camera)),
                      _buildImagePickerButton(Icons.photo, 'Gallery', () => _pickImage(ImageSource.gallery)),
                    ],
                  ),
                  SizedBox(height: 20),
                  
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
                              : Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)))
                          : (_mobileImage != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_mobileImage!, fit: BoxFit.cover))
                              : Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey))),
                    ),
                  ),

                  SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Missing Person Report Submitted!')),
                          );
                        }
                      },
                      child: Text('Submit Report'),
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

  // HELPER FUNCTIONS 
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

  Widget _buildImagePickerButton(IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}