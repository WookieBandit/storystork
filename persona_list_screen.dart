// lib/persona_list_screen.dart - v1.4 (Fetch and display saved personas)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_edit_persona_screen.dart'; // For the FAB navigation

class PersonaListScreen extends StatefulWidget {
  const PersonaListScreen({super.key});

  @override
  State<PersonaListScreen> createState() => _PersonaListScreenState();
}

class _PersonaListScreenState extends State<PersonaListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  // Method to show delete confirmation dialog for personas
  Future<void> _confirmDeletePersona(BuildContext context, String docId, String personaName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete Persona'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete the persona "$personaName"?'),
                const Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Dismiss the dialog
                await _deletePersona(docId, personaName); // Proceed with delete
              },
            ),
          ],
        );
      },
    );
  }

  // Method to delete a persona from Firestore
  Future<void> _deletePersona(String docId, String personaName) async {
    if (_currentUser == null) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Error: Not logged in.')));
        }
      return;
    }

    try {
      await _firestore.collection('personas').doc(docId).delete();
      print('Persona "$personaName" (ID: $docId) deleted successfully.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Persona "$personaName" deleted!')),
        );
      }
    } catch (e) {
      print('Error deleting persona "$personaName" (ID: $docId): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting persona: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Personas'),
        centerTitle: true,
      ),
      body: _currentUser == null
          ? const Center(
              child: Text('Please log in to manage your personas.'),
            )
          : StreamBuilder<QuerySnapshot>(
              // Section: Firestore Stream Query for personas
              stream: _firestore
                  .collection('personas')
                  .where('userId', isEqualTo: _currentUser!.uid)
                  .orderBy('personaName', descending: false)
                  .snapshots(),

              // Section: StreamBuilder Builder Function
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                // Handle stream errors
                if (snapshot.hasError) {
                  print('Error fetching personas: ${snapshot.error}');
                  return Center(child: Text('Something went wrong: ${snapshot.error}'));
                }
                // Handle stream loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Handle no data (empty list)
                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('You haven\'t created any personas yet. Tap "+" to add one!'));
                }

                // Build ListView if data exists
                return ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: snapshot.data!.docs.map((DocumentSnapshot document) {
                    Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                    String docId = document.id;
                    String personaName = data['personaName'] ?? 'Unnamed Persona';
                    String personaRelationship = data['personaRelationship'] ?? 'No relationship specified';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      child: ListTile(
                        title: Text(personaName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(personaRelationship),
                        trailing: IconButton( // Delete button for each persona
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Delete Persona',
                          onPressed: () {
                            _confirmDeletePersona(context, docId, personaName);
                          },
                        ),
                        onTap: () { // Navigate to edit screen
                          print('Tapped on persona: $personaName (ID: $docId) for editing.');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditPersonaScreen(
                                personaDocId: docId,
                                initialPersonaData: data,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print('Add new persona FAB pressed - navigating to AddEditPersonaScreen (add mode)');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditPersonaScreen()),
          );
        },
        tooltip: 'Add Persona',
        child: const Icon(Icons.add),
      ),
    );
  }
}