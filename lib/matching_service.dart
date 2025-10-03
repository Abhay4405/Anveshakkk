// lib/services/matching_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// MAIN MATCHING FUNCTION
Future<List<Map<String, dynamic>>> runMatchingAlgorithm(Map<String, dynamic> newFoundPerson) async {
  List<Map<String, dynamic>> potentialMatches = [];
  
  // TEMPORARY FIX: Since Found Report form does not have an Age field, 
  // we are using the 'name_if_known' field's value as a number for testing.
  // When testing, enter the approximate age of the found person in the Name field.
  int foundAge = int.tryParse(newFoundPerson['name_if_known'] ?? '0') ?? 0;
  
  // 1. Fetch all lost persons reports
  QuerySnapshot lostSnapshot = await _firestore.collection('lost_persons').get();

  for (var doc in lostSnapshot.docs) {
    Map<String, dynamic> lostPerson = doc.data() as Map<String, dynamic>;
    
    // --- MATCHING CRITERIA (Simple Logic) ---
    
    // A. Age Match (Within 5 years range)
    int lostAge = lostPerson['age'] ?? 0;
    bool ageMatch = (lostAge - foundAge).abs() <= 5; 

    // B. Location Match (Check if one address contains the other, case-insensitive)
    String lostAddress = (lostPerson['last_seen_address'] ?? '').toLowerCase();
    String foundLocation = (newFoundPerson['found_location'] ?? '').toLowerCase();
    bool locationMatch = lostAddress.contains(foundLocation) || foundLocation.contains(lostAddress);
    
    // --- FINAL DECISION LOGIC (Softened to OR) ---
    // Match will occur if Age OR Location is similar.
    if (ageMatch || locationMatch) { 
      String confidence = "Medium (Rules Match)";
      if (ageMatch && locationMatch) {
          confidence = "High (Age & Location Match)";
      }
      
      // Print statement for debugging in the console
      print('*** POTENTIAL MATCH FOUND! Lost Person: ${lostPerson['name']}, Age Match: $ageMatch, Location Match: $locationMatch, Confidence: $confidence'); 

      potentialMatches.add({
        'lost_person_id': doc.id,
        'lost_person_name': lostPerson['name'],
        'lost_person_contact_uid': lostPerson['reporter_uid'],
        'found_person_data': newFoundPerson,
        'confidence': confidence,
        // You can add more data here if needed
      });
    }
  }

  return potentialMatches;
}