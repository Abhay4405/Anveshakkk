// main.dart (Poori file)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:firebase_core/firebase_core.dart'; // NEW
import 'firebase_options.dart'; // NEW: Yeh file 'flutterfire configure' se aayegi

import 'home.dart';
import 'splash.dart';
import 'login.dart';
import 'found.dart';
import 'admin.dart';
import 'report.dart';
import 'registration.dart';
import 'parent_auth.dart';
import 'person_details.dart'; 

void main() async { // NEW: added async
  WidgetsFlutterBinding.ensureInitialized();
  
  // NEW: Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const AnveshakApp());
}

class Routes {
  static const splash = '/';
  static const home = '/home';
  static const login = '/login';
  static const register = '/register';
  static const parentAuth = '/parentAuth';
  static const personDetails = '/personDetails';
  static const personFound = '/personFound';
  static const adminPanel = '/adminPanel';
  static const report = '/report';
}

class AnveshakApp extends StatelessWidget {
  const AnveshakApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Primary color: Trustworthy Indigo
    final MaterialColor primaryBlue = MaterialColor(
      0xFF3F51B5, 
      <int, Color>{
        50: Color(0xFFE8EAF6), 100: Color(0xFFC5CAE9), 200: Color(0xFF9FA8DA),
        300: Color(0xFF7986CB), 400: Color(0xFF5C6BC0), 500: Color(0xFF3F51B5),
        600: Color(0xFF3949AB), 700: Color(0xFF303F9F), 800: Color(0xFF283593),
        900: Color(0xFF1A237E),
      },
    );

    return MaterialApp(
      title: 'Anveshak - The Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: primaryBlue,
        colorScheme: ColorScheme.light(
          primary: primaryBlue,
          secondary: const Color(0xFFFFC107), // Amber for highlights/actions
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryBlue,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white,
          ),
          elevation: 0,
        ),
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.0),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 5,
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (context) => const SplashScreen(),
        Routes.home: (context) => const HomePage(),
        Routes.login: (context) => const LoginPage(),
        Routes.register: (context) => const RegistrationPage(),
        Routes.parentAuth: (context) => const ParentAuthPage(),
        Routes.personDetails: (context) => const PersonDetailsPage(),
        Routes.personFound: (context) => const PersonFoundPage(),
        Routes.adminPanel: (context) => const AdminPanelPage(),
        Routes.report: (context) => const ReportPage(),
      },
    );
  }
}