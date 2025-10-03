// admin.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      appBar: AppBar(title: const Text('Admin Panel')),
      body: FutureBuilder<Map<String, int>>(
        future: _fetchAdminData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading data: ${snapshot.error}'));
          }

          final data = snapshot.data ?? {};
          final pendingVerifications = data['pendingVerifications'] ?? 0;
          final activeLost = data['activeLost'] ?? 0;
          final totalFeedback = data['totalFeedback'] ?? 0;

          return Padding(
            padding: EdgeInsets.all(screenWidth > 600 ? 40 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 10),
                Text(
                  'Manage user verifications, reports, and system integrity.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: screenWidth > 900 ? 3 : (screenWidth > 600 ? 2 : 1),
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: screenWidth > 900 ? 1.5 : (screenWidth > 600 ? 2.5 : 4),
                    children: [
                      _adminCard(context, 'Pending Verifications', '$pendingVerifications New', Icons.verified_user, Colors.orange),
                      _adminCard(context, 'Active Lost Reports', '$activeLost Awaiting Match', Icons.compare_arrows, Colors.redAccent),
                      _adminCard(context, 'Total Feedback', '$totalFeedback Records', Icons.rate_review, Colors.teal),
                      _adminCard(context, 'System Logs', 'View Activity', Icons.history, Colors.blueGrey),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _adminCard(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 30, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle, style: TextStyle(color: color)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigating to $title')));
        },
      ),
    );
  }
}