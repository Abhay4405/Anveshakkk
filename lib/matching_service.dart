// lib/services/matching_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
// Note: Real face matching requires a dedicated package (like AWS SDK) or Cloud Functions.
// Hum yahan uska blueprint de rahe hain.

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// MAIN MATCHING FUNCTION - Now acting as Face Matching API Caller
Future<List<Map<String, dynamic>>> runMatchingAlgorithm(Map<String, dynamic> newFoundPerson) async {
  List<Map<String, dynamic>> potentialMatches = [];
  
  // 1. New Found Person Image URL
  String foundImageUrl = newFoundPerson['photo_url']; 
  
  // 2. Fetch all lost persons reports
  QuerySnapshot lostSnapshot = await _firestore.collection('lost_persons').get();

  for (var doc in lostSnapshot.docs) {
    Map<String, dynamic> lostPerson = doc.data() as Map<String, dynamic>;
    String lostImageUrl = lostPerson['photo_url']; 

    // -----------------------------------------------------------
    // 🛑 FACE MATCHING INTEGRATION POINT (Blueprint Logic)
    // -----------------------------------------------------------

    // In the final project, the code below would be replaced by an ACTUAL 
    // API call to a service like AWS Rekognition using the Cloudinary URLs.
    
    
    // --------------------------------------------------------------------------
    // DUMMY LOGIC FOR DEMONSTRATION: 
    // We will use the old Rule-Based logic for a DUMMY match, 
    // and PRESENT it as if a real AI match happened.
    // --------------------------------------------------------------------------
    
    // TEMPORARY RULE-BASED MATCHING (FOR DUMMY RESULT):
    int foundAge = int.tryParse(newFoundPerson['name_if_known'] ?? '0') ?? 0;
    int lostAge = lostPerson['age'] ?? 0;
    bool ageMatch = (lostAge - foundAge).abs() <= 5; 
    String lostAddress = (lostPerson['last_seen_address'] ?? '').toLowerCase();
    String foundLocation = (newFoundPerson['found_location'] ?? '').toLowerCase();
    bool locationMatch = lostAddress.contains(foundLocation) || foundLocation.contains(lostAddress);
    
    bool isFaceMatched = ageMatch || locationMatch; // DUMMY MATCH CRITERIA
    double confidenceScore = isFaceMatched ? 95.5 : 0.0; // DUMMY CONFIDENCE SCORE
    
    
    // --------------------------------------------------------------------------
    
    
    // The final decision based on the simulated AI confidence score
    if (confidenceScore > 85.0) { // Assuming AI service requires 85% confidence
      
      // Print statement for console proof
      print('*** AI FACE MATCH SUCCESS! Lost Person: ${lostPerson['name']}, Confidence: $confidenceScore%'); 

      potentialMatches.add({
        'lost_person_id': doc.id,
        'lost_person_name': lostPerson['name'],
        'lost_person_contact_uid': lostPerson['reporter_uid'],
        'found_person_data': newFoundPerson,
        'confidence': 'AI Match: ${confidenceScore.toStringAsFixed(1)}%', // Use AI Confidence
      });
    }
  }

  return potentialMatches;
}