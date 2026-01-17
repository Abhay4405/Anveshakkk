import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'feedback_form.dart';

class MatchResultPage extends StatefulWidget {
  final List<Map<String, dynamic>> matches;

  const MatchResultPage({super.key, required this.matches});

  @override
  State<MatchResultPage> createState() => _MatchResultPageState();
}

class _MatchResultPageState extends State<MatchResultPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.matches.isNotEmpty ? 'Match Found' : 'No Match Found',
        ),
        backgroundColor:
            widget.matches.isNotEmpty ? Colors.green : Colors.redAccent,
      ),
      body: widget.matches.isEmpty
          ? _noMatchUI()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.matches.length,
              itemBuilder: (context, index) {
                final match = widget.matches[index];
                return _matchCard(context, match);
              },
            ),
    );
  }

  // ---------------- NO MATCH UI ----------------
  Widget _noMatchUI() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'No matching person found',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 5),
          Text(
            'Your report has been saved.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ---------------- MATCH CARD ----------------
  Widget _matchCard(BuildContext context, Map<String, dynamic> match) {
    final String name =
        match['lost_person_name']?.toString() ?? 'Unknown';
    final double confidence =
        (match['confidence'] is num)
            ? match['confidence'].toDouble()
            : 0.0;
    
    // Get photo URL from match data - try multiple field names
    String photoUrl = '';
    if (match['found_person_photo_url'] != null) {
      photoUrl = match['found_person_photo_url'].toString();
    } else if (match['photo_url'] != null) {
      photoUrl = match['photo_url'].toString();
    } else if (match['found_photo_url'] != null) {
      photoUrl = match['found_photo_url'].toString();
    } else if (match['image_url'] != null) {
      photoUrl = match['image_url'].toString();
    }
    
    // Try multiple fields for contact - lost_person_contact or contact
    String contact = 'N/A';
    if (match['lost_person_contact'] != null && 
        match['lost_person_contact'].toString().trim().isNotEmpty) {
      contact = match['lost_person_contact'].toString().trim();
    } else if (match['contact'] != null && 
               match['contact'].toString().trim().isNotEmpty) {
      contact = match['contact'].toString().trim();
    }
    
    // Get report IDs from match data
    String lostReportId = match['lost_report_id']?.toString() ?? '';
    String foundReportId = match['found_report_id']?.toString() ?? '';
    
    final String age = match['lost_person_age']?.toString() ?? 'N/A';
    final String gender = match['lost_person_gender']?.toString() ?? 'N/A';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with matched person name
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Match Found!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This person matches your report',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Matched Person's Photo
            if (photoUrl.isNotEmpty) ...[
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl,
                      width: 200,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.image_not_supported,
                                color: Colors.grey, size: 40),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${confidence.toStringAsFixed(2)}%',
              style: TextStyle(
                color: confidence >= 85
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            // Age and Gender info
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Age: $age | Gender: $gender'),
              ],
            ),
            const Divider(height: 30),
            // Contact info section
            if (contact != 'N/A' && contact.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.phone, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      contact,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Call and Message buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _callContact(contact),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendMessage(contact),
                    icon: const Icon(Icons.sms),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.phone, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Contact not available',
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            
            // Feedback and Confirmation Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  print('Button Pressed! Lost ID: $lostReportId, Found ID: $foundReportId');
                  if (lostReportId.isEmpty || foundReportId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Report IDs not available. Please try again.'),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FeedbackFormPage(
                        matchedLostReportId: lostReportId,
                        matchedFoundReportId: foundReportId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Confirm Match & Provide Feedback'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Call contact
  Future<void> _callContact(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      print('Error launching call: $e');
    }
  }

  // Send SMS message
  Future<void> _sendMessage(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {
        'body': 'Hi, we found a match for the person you reported as lost. Please contact us for more details.',
      },
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      print('Error launching SMS: $e');
    }
  }
}
