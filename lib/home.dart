import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth > 600 ? 200 : (screenWidth - 60) / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anveshak - Home'),
        automaticallyImplyLeading: false, // Hide back button after login
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Welcome, User!',
                style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 5),
              Text(
                'Select an action to continue.',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 40),
              Center(
                child: Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    // Route updated to new name
                    _featureCard(context, 'Person Lost', Icons.person_off, Routes.parentAuth, cardWidth, Theme.of(context).colorScheme.primary),
                    _featureCard(context, 'Person Found', Icons.person_search, Routes.personFound, cardWidth, Theme.of(context).colorScheme.secondary),
                    _featureCard(context, 'Admin Panel', Icons.admin_panel_settings, Routes.adminPanel, cardWidth, Colors.green),
                    _featureCard(context, 'Reports & Stats', Icons.bar_chart, Routes.report, cardWidth, Colors.orange),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Our Mission',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                'Anveshak aims to bridge the communication gap between families of missing persons and finders. We use technology to ensure quick and secure reunifications for those who cannot express their identity.',
                style: TextStyle(fontSize: 15, color: Colors.grey[800]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard(BuildContext context, String title, IconData icon, String route, double cardWidth, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      child: Container(
        width: cardWidth,
        height: cardWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            )
          ],
        ),
      ),
    );
  }
}