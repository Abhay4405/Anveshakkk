import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: Padding(
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
                  _statCard(context, 'Total Reports Lost', '1,250', Icons.person_off_outlined, Colors.red),
                  _statCard(context, 'Successful Reunions', '785', Icons.check_circle_outline, Colors.green),
                  _statCard(context, 'Match Rate', '62.8%', Icons.percent, Colors.indigo),
                  _statCard(context, 'Active Reports', '465', Icons.pending_actions, Colors.blue),
                ],
              ),
            ),
          ],
        ),
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