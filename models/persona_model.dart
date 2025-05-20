// lib/models/persona_model.dart - v1.0 (Initial Persona Model)
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for DocumentSnapshot

class Persona {
  final String id; // Firestore document ID
  final String personaName;
  final String? personaRelationship;
  final String? personaAge;
  final List<String> personaInterests;
  final String? notes;
  // userId and createdAt are stored in Firestore but not always needed in the model for display/selection.
  // If needed, they can be added here too.

  Persona({
    required this.id,
    required this.personaName,
    this.personaRelationship,
    this.personaAge,
    this.personaInterests = const [], // Default to an empty list
    this.notes,
  });

  // Factory constructor to create a Persona instance from a Firestore document
  factory Persona.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Persona(
      id: doc.id,
      personaName: data['personaName'] ?? 'Unnamed Persona',
      personaRelationship: data['personaRelationship'] as String?,
      personaAge: data['personaAge']?.toString(), // Ensure age is treated as string for flexibility
      personaInterests: List<String>.from(data['personaInterests'] ?? []),
      notes: data['notes'] as String?,
    );
  }

  // Optional: A method to convert Persona instance to a Map for saving to Firestore
  // This would typically be used in AddEditPersonaScreen, but we're handling map creation there directly for now.
  // Map<String, dynamic> toFirestore() {
  //   return {
  //     'personaName': personaName,
  //     'personaRelationship': personaRelationship,
  //     'personaAge': personaAge,
  //     'personaInterests': personaInterests,
  //     'notes': notes,
  //     // 'userId' and 'createdAt' would be added here or directly in the save function
  //   };
  // }
}