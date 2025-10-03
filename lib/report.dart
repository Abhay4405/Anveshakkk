// report.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  // Function to fetch data from Firestore
  Future<Map<String, int>> _fetchReportData() async {
    final firestore = FirebaseFirestore.instance;
    
    // 1. Total Reports Lost
    final lostSnapshot = await firestore.collection('lost_persons').get();
    int totalLost = lostSnapshot.docs.length;
    
    // 2. Successful Reunions (is_found = true)
    final foundSnapshot = await firestore.collection('lost_persons')
        .where('is_found', isEqualTo: true)
        .get();
    int successfulReunions = foundSnapshot.docs.length;

    // 3. Active Reports (is_found = false)
    int activeReports = totalLost - successfulReunions;

    return {
      'totalLost': totalLost,
      'successfulReunions': successfulReunions,
      'activeReports': activeReports,
    };
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: FutureBuilder<Map<String, int>>(
        future: _fetchReportData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading data: ${snapshot.error}'));
          }
          
          final data = snapshot.data ?? {};
          final totalLost = data['totalLost'] ?? 0;
          final successfulReunions = data['successfulReunions'] ?? 0;
          final activeReports = data['activeReports'] ?? 0;
          final matchRate = totalLost > 0 ? ((successfulReunions / totalLost) * 100).toStringAsFixed(1) : '0.0';

          return Padding(
            padding: EdgeInsets.all(screenWidth > 600 ? 40 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Performance',
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 10),
                Text(
                  'Key statistics and insights on reunification success.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: screenWidth > 900 ? 3 : (screenWidth > 600 ? 2 : 1),
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: screenWidth > 900 ? 1.0 : (screenWidth > 600 ? 1.5 : 1.0),
                    children: [
                      _statCard(context, 'Total Reports Lost', totalLost.toString(), Icons.person_off_outlined, Colors.red),
                      _statCard(context, 'Successful Reunions', successfulReunions.toString(), Icons.check_circle_outline, Colors.green),
                      _statCard(context, 'Match Rate', '$matchRate%', Icons.percent, Colors.indigo),
                      _statCard(context, 'Active Reports', activeReports.toString(), Icons.pending_actions, Colors.blue),
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

  Widget _statCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}