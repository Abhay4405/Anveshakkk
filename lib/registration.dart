// registration.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>(); // NEW: For validation
  final TextEditingController nameController = TextEditingController(); // NEW
  final TextEditingController emailController = TextEditingController(); // NEW
  final TextEditingController phoneController = TextEditingController(); // NEW
  final TextEditingController passwordController = TextEditingController(); // NEW
  bool _agreedToTerms = false; // NEW

  final FirebaseAuth _auth = FirebaseAuth.instance; // NEW: Firebase instance

  // NEW: Registration Function
  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate() && _agreedToTerms) {
      try {
        // 1. Create User with Email and Password
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // 2. Add User's Display Name
        await userCredential.user!.updateDisplayName(nameController.text.trim());

        // Success: Show message and navigate to Login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration Successful! Please Login.')),
        );
        Navigator.pop(context); // Go back to login
        
      } on FirebaseAuthException catch (e) {
        String message = 'Registration failed. Please try again.';
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'The account already exists for that email.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unknown error occurred.')),
        );
      }
    } else if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must agree to the Terms & Conditions.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double formWidth = MediaQuery.of(context).size.width > 600 ? 500.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: const Text('New User Registration')),
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
              key: _formKey, // NEW: Form Key added
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join Anveshak',
                    style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Create your secure account to report a lost person or a found person.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 30),

                  _buildTextField('Full Name', Icons.person, controller: nameController),
                  const SizedBox(height: 20),
                  _buildTextField('Email', Icons.email, controller: emailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 20),
                  _buildTextField('Phone Number', Icons.phone, controller: phoneController, keyboardType: TextInputType.phone),
                  const SizedBox(height: 20),
                  _buildTextField('Create Password', Icons.lock, controller: passwordController, isObscure: true),
                  const SizedBox(height: 30),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NEW: Checkbox logic uses state
                      Checkbox(
                        value: _agreedToTerms, 
                        onChanged: (val) {
                          setState(() {
                            _agreedToTerms = val ?? false;
                          });
                        }, 
                        activeColor: Theme.of(context).primaryColor
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(
                            'I agree to the Terms & Conditions and understand that any false claim may result in legal action.',
                            style: TextStyle(fontSize: 14, color: Colors.red[700], fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _registerUser, // NEW: Calls registration function
                      child: const Text('Complete Registration'),
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

  // UPDATED: Now uses TextFormField and requires controller
  Widget _buildTextField(
    String label, 
    IconData icon, 
    {
      required TextEditingController controller,
      TextInputType keyboardType = TextInputType.text, 
      bool isObscure = false
    }
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isObscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (label == 'Email' && !value.contains('@')) {
          return 'Enter a valid email';
        }
        if (label == 'Create Password' && value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }
}