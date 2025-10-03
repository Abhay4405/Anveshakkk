// lib/feedback_form.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // For Routes.home

class FeedbackFormPage extends StatefulWidget {
  final String matchedLostReportId;
  final String matchedFoundReportId;

  const FeedbackFormPage({
    super.key,
    required this.matchedLostReportId,
    required this.matchedFoundReportId,
  });

  @override
  _FeedbackFormPageState createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<FeedbackFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController commentController = TextEditingController();
  double _reunionRating = 4.0;
  bool _isMatchConfirmed = true; // Assume user confirmed match from previous screen

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _submitFeedback() async {
    if (currentUser == null || !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in and fill out the form.')),
      );
      return;
    }

    if (!_isMatchConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm the match status.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitting feedback...')),
    );

    try {
      // 1. Save Feedback to a new collection
      await _firestore.collection('reunification_feedback').add({
        'lost_report_id': widget.matchedLostReportId,
        'found_report_id': widget.matchedFoundReportId,
        'submitted_by_uid': currentUser!.uid,
        'is_match_confirmed': _isMatchConfirmed,
        'rating': _reunionRating,
        'comments': commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update Lost Report status to 'Found'
      await _firestore.collection('lost_persons').doc(widget.matchedLostReportId).update({
        'is_found': true,
        'reunification_timestamp': FieldValue.serverTimestamp(),
      });

      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback submitted successfully! Reunification process complete.'),
          duration: Duration(seconds: 3),
        ),
      );
      // Navigate back to Home screen
      Navigator.pushNamedAndRemoveUntil(context, Routes.home, (route) => false);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit feedback: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double formWidth = MediaQuery.of(context).size.width > 600 ? 600.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(title: const Text('Reunification Feedback')),
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
                  Text(
                    'Confirm Reunification',
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 10),
                  const Text('Your feedback helps us track successful reunifications and improve the system.'),
                  const SizedBox(height: 30),

                  // 1. Match Confirmation
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: _isMatchConfirmed ? Colors.green : Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        'Was the reunification successful?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: _isMatchConfirmed,
                        onChanged: (val) => setState(() => _isMatchConfirmed = val!),
                        activeColor: Colors.green,
                      ),
                      const Text('Yes, match was correct.'),
                      Radio<bool>(
                        value: false,
                        groupValue: _isMatchConfirmed,
                        onChanged: (val) => setState(() => _isMatchConfirmed = val!),
                        activeColor: Colors.red,
                      ),
                      const Text('No, match was incorrect.'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Rating
                  Text(
                    'Rate your experience (${_reunionRating.toStringAsFixed(1)})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _reunionRating,
                    min: 1,
                    max: 5,
                    divisions: 8,
                    label: _reunionRating.toStringAsFixed(1),
                    onChanged: (double value) {
                      setState(() {
                        _reunionRating = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. Comments
                  TextFormField(
                    controller: commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Any comments or suggestions?',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitFeedback,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: const Text('Submit Feedback', style: TextStyle(fontSize: 18)),
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
}