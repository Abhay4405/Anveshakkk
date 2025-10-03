// login.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // NEW: For validation

  final FirebaseAuth _auth = FirebaseAuth.instance; // NEW: Firebase instance

  // NEW: Login Function
  Future<void> _loginUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 1. Sign In
        await _auth.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Success: Navigate to Home and clear navigation stack
        Navigator.pushReplacementNamed(context, Routes.home);
        
      } on FirebaseAuthException catch (e) {
        String message = 'Login failed. Check your email and password.';
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          message = 'Invalid email or password.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form( // NEW: Added Form widget
            key: _formKey, // NEW: Form key
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 100, color: Theme.of(context).primaryColor),
                const SizedBox(height: 20),
                Text(
                  'Welcome Back',
                  style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                ),
                Text(
                  'Login to Anveshak',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),
                _buildTextField(context, 'Email', emailController, Icons.email, false),
                const SizedBox(height: 20),
                _buildTextField(context, 'Password', passwordController, Icons.lock, true),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Functionality not yet implemented.')),
                      );
                    },
                    child: Text('Forgot Password?', style: TextStyle(color: Theme.of(context).primaryColor)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loginUser, // NEW: Calls login function
                    child: const Text('Login'),
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, Routes.register);
                      },
                      child: Text('Register Now', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // UPDATED: Now uses TextFormField with validation and controller
  Widget _buildTextField(BuildContext context, String label, TextEditingController controller, IconData icon, bool obscureText) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: label == 'Email' ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        labelText: label,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }
}