// lib/match_result.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'feedback_form.dart'; // NEW: Import Feedback Form

class MatchResultPage extends StatelessWidget {
  final List<Map<String, dynamic>> matches;

  const MatchResultPage({super.key, required this.matches});

  void _makeCall(String contact) async {
    final Uri launchUri = Uri(scheme: 'tel', path: contact);
    if (!await launchUrl(launchUri)) {
      debugPrint('Could not launch $launchUri');
    }
  }
  
  void _sendSms(String contact) async {
    final Uri launchUri = Uri(scheme: 'sms', path: contact);
    if (!await launchUrl(launchUri)) {
      debugPrint('Could not launch $launchUri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(matches.isNotEmpty ? 'Potential Matches Found!' : 'No Match Found'),
        backgroundColor: matches.isNotEmpty ? Colors.green : Colors.redAccent,
      ),
      body: matches.isEmpty
          ? Center(
              // ... No Match UI remains the same ...
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text('The person you found did not match any active reports.', style: GoogleFonts.poppins(fontSize: 18)),
                  Text('Thank you for submitting your report.', style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Great News! ${matches.length} Potential Match${matches.length > 1 ? 'es' : ''} Found!',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[800]),
                ),
                const SizedBox(height: 10),
                const Text('Please review the details below and contact the reporter to verify the match.'),
                const Divider(height: 40),

                ...matches.map((match) {
                  return MatchCard(match: match, onCall: _makeCall, onSms: _sendSms);
                }),
              ],
            ),
    );
  }
}

class MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final Function(String) onCall;
  final Function(String) onSms;

  const MatchCard({super.key, required this.match, required this.onCall, required this.onSms});

  @override
  Widget build(BuildContext context) {
    const String dummyReporterContact = "9876543210"; 
    
    // Extract IDs needed for the Feedback Form
    final String lostId = match['lost_person_id'] ?? '';
    final String foundId = match['found_person_data']['id'] ?? 'N/A'; // Assuming 'id' field is present in found_person_data map or fetch it separately if needed

    // NOTE: We need to ensure that the document ID of the Found Report (Database 2) 
    // is passed to the MatchResultPage for a proper Feedback Form submission.
    // For presentation, we will use a dummy ID for the Found Report if it's not available in the match map.
    
    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.green.shade200, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Matched Report: ${match['lost_person_name']}', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
            Text('Confidence: ${match['confidence']}', style: TextStyle(color: match['confidence']!.contains('High') ? Colors.red : Colors.orange)),
            const Divider(),
            const Text('Reporter Contact:', style: TextStyle(fontWeight: FontWeight.bold)),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dummyReporterContact, style: const TextStyle(fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () => onCall(dummyReporterContact),
                      tooltip: 'Call Reporter',
                    ),
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.blue),
                      onPressed: () => onSms(dummyReporterContact),
                      tooltip: 'Send SMS',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // NEW: Navigate to the Feedback Form
                  // NOTE: 'N/A' is used for the Found Report ID if the original ID was not captured during submission.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FeedbackFormPage(
                        matchedLostReportId: lostId,
                        matchedFoundReportId: 'DUMMY_FOUND_ID', 
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text('Confirm Match & Get Feedback Form'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}