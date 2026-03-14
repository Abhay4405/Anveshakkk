// admin.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

  Future<Map<String, int>> _fetchAdminData() async {
    final firestore = FirebaseFirestore.instance;
    
    // 1. Pending Verifications (user_verifications status)
    final verificationSnapshot = await firestore.collection('user_verifications')
        .where('verification_status', isEqualTo: 'Pending Admin Review')
        .get();
    int pendingVerifications = verificationSnapshot.docs.length;
    
    // 2. Potential Matches (Lost reports not yet found)
    final activeLostSnapshot = await firestore.collection('lost_persons')
        .where('is_found', isEqualTo: false)
        .get();
    int activeLost = activeLostSnapshot.docs.length;

    // 3. User Grievances (Using feedback for general issues count)
    final feedbackSnapshot = await firestore.collection('reunification_feedback').get();
    int totalFeedback = feedbackSnapshot.docs.length;

    return {
      'pendingVerifications': pendingVerifications,
      'activeLost': activeLost,
      'totalFeedback': totalFeedback,
    };
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade50,
              Colors.purple.shade50,
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade500],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'System management & analytics',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
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
              child: FutureBuilder<Map<String, int>>(
                future: _fetchAdminData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final data = snapshot.data ?? {};
                  final pendingVerifications = data['pendingVerifications'] ?? 0;
                  final activeLost = data['activeLost'] ?? 0;
                  final totalFeedback = data['totalFeedback'] ?? 0;

                  return Padding(
                    padding: EdgeInsets.all(screenWidth > 600 ? 24 : 16),
                    child: GridView.count(
                      crossAxisCount: screenWidth > 900 ? 3 : (screenWidth > 600 ? 2 : 1),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: screenWidth > 900 ? 1.4 : (screenWidth > 600 ? 2 : 2.2),
                      children: [
                        _adminCard(
                          context,
                          'Pending Verifications',
                          pendingVerifications.toString(),
                          Icons.verified_user,
                          Colors.orange,
                        ),
                        _adminCard(
                          context,
                          'Active Lost Reports',
                          activeLost.toString(),
                          Icons.compare_arrows,
                          Colors.red,
                        ),
                        _adminCard(
                          context,
                          'Total Feedback',
                          totalFeedback.toString(),
                          Icons.rate_review,
                          Colors.teal,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminCard(BuildContext context, String title, String count, IconData icon, Color color) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Navigating to $title')),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: color.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}