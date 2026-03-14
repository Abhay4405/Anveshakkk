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
      backgroundColor: Colors.grey.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade50,
              Colors.teal.shade50,
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.matches.isNotEmpty
                      ? [Colors.green.shade700, Colors.green.shade500]
                      : [Colors.orange.shade700, Colors.orange.shade500],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.matches.isNotEmpty
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.matches.isNotEmpty ? '✓ Match Found' : '✗ No Matches',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.matches.isNotEmpty
                              ? '${widget.matches.length} possible match${widget.matches.length > 1 ? 'es' : ''} found'
                              : 'Keep us updated',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: widget.matches.isEmpty
                  ? _noMatchUI()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.matches.length,
                      itemBuilder: (context, index) {
                        final match = widget.matches[index];
                        return _matchCard(context, match);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // No match UI
  Widget _noMatchUI() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 60,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Match Found Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your report has been saved and will be matched with future reports.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'What happens next?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• We\'ll continuously scan new reports\n• You\'ll be notified if a match is found\n• Check back regularly for updates',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    
    // Get both photo URLs
    String lostPhotoUrl = '';
    String foundPhotoUrl = '';
    
    if (match['lost_person_photo_url'] != null) {
      lostPhotoUrl = match['lost_person_photo_url'].toString();
    }
    
    if (match['found_person_photo_url'] != null) {
      foundPhotoUrl = match['found_person_photo_url'].toString();
    } else if (match['photo_url'] != null) {
      foundPhotoUrl = match['photo_url'].toString();
    } else if (match['found_photo_url'] != null) {
      foundPhotoUrl = match['found_photo_url'].toString();
    } else if (match['image_url'] != null) {
      foundPhotoUrl = match['image_url'].toString();
    }
    
    // Try multiple fields for contact - lost_person_contact or contact
    String contact = 'N/A';
    if (match['lost_person_contact'] != null) {
      String temp = match['lost_person_contact'].toString().trim();
      if (temp.isNotEmpty && temp != 'N/A') {
        contact = temp;
      }
    }
    if (contact == 'N/A' && match['contact'] != null) {
      String temp = match['contact'].toString().trim();
      if (temp.isNotEmpty && temp != 'N/A') {
        contact = temp;
      }
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
            
            // Display both Lost and Found Photos
            if (lostPhotoUrl.isNotEmpty || foundPhotoUrl.isNotEmpty) ...[
              Column(
                children: [
                  // Photo Comparison Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '📸 Photo Comparison',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Lost Person's Photo
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Lost Report',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (lostPhotoUrl.isNotEmpty)
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          lostPhotoUrl,
                                          width: 140,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 140,
                                              height: 180,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.image_not_supported,
                                                    color: Colors.grey, size: 30),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 140,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.image_not_supported,
                                            color: Colors.grey, size: 30),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Center Divider with Match Icon
                            Column(
                              children: [
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                            // Found Person's Photo
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    'Found Report',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (foundPhotoUrl.isNotEmpty)
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          foundPhotoUrl,
                                          width: 140,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 140,
                                              height: 180,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.image_not_supported,
                                                    color: Colors.grey, size: 30),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 140,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.image_not_supported,
                                            color: Colors.grey, size: 30),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
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
            if (contact.isNotEmpty && contact != 'N/A') ...[
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
