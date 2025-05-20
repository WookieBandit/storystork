// lib/library_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'content_detail_screen.dart'; // For navigating to content details

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  // Function to show delete confirmation dialog
  Future<void> _confirmDelete(BuildContext context, String docId, String contentTitle) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete "$contentTitle"?'),
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
                await _deleteContent(docId, contentTitle); // Proceed with delete
              },
            ),
          ],
        );
      },
    );
  }

  // Function to delete content from Firestore
  Future<void> _deleteContent(String docId, String contentTitle) async {
    if (_currentUser == null) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not logged in.')),
        );
      }
      return;
    }

    try {
      await _firestore.collection('content').doc(docId).delete();
      print('Content "$contentTitle" (ID: $docId) deleted successfully.');
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$contentTitle" deleted successfully!')),
        );
      }
    } catch (e) {
      print('Error deleting content "$contentTitle" (ID: $docId): $e');
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting "$contentTitle": ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Content Library'),
        centerTitle: true,
      ),
      body: _currentUser == null
          ? const Center(
              child: Text('Please log in to see your library.'),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('content')
                  .where('userId', isEqualTo: _currentUser!.uid)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                // Section: Handle stream errors
                if (snapshot.hasError) {
                  print('Error fetching library content: ${snapshot.error}');
                  return Center(child: Text('Something went wrong: ${snapshot.error}'));
                }

                // Section: Handle stream loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Section: Handle no data
                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Your library is empty. Go generate some content!'));
                }

                // Section: Build list if data exists
                return ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: snapshot.data!.docs.map((DocumentSnapshot document) {
// Inside _LibraryScreenState -> build -> StreamBuilder -> ListView -> .map((DocumentSnapshot document) { ...
// This is the return Card(child: ListTile(...)); block for library_screen.dart

                 Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                 String docId = document.id; 
                 String title = data['type'] ?? 'Untitled Content';
                 String synopsis = data['synopsis'] ?? 'No synopsis available.';
                 String fullTextFromDoc = data['fullText'] ?? 'Full content not available.';
                 List<String> themes = List<String>.from(data['selected_themes'] ?? []);
                 List<String> characters = List<String>.from(data['selected_characters'] ?? []);
                 String? persona = data['selected_persona'] as String?;
                 String length = data['selected_length'] ?? 'Medium';
                 bool isPublicStatus = data['isPublic'] ?? false;
                 String ownerUserId = data['userId'] ?? '';
                 // --- FETCH NEW FIELDS ---
                 String? ageRange = data['selected_age_range'] as String?;
                 List<String> lessons = List<String>.from(data['selected_lessons'] ?? []);
                 // --- END OF FETCH NEW FIELDS ---

                 return Card(
                   margin: const EdgeInsets.symmetric(vertical: 8.0),
                   child: ListTile(
                     title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                     subtitle: Text(synopsis, maxLines: 3, overflow: TextOverflow.ellipsis),
                     trailing: IconButton( 
                       icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                       tooltip: 'Delete Content',
                       onPressed: () => _confirmDelete(context, docId, title), 
                     ),
                     onTap: () { 
                       print('Tapped on content ID: $docId, isPublic: $isPublicStatus from user library');
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => ContentDetailScreen(
                             documentId: docId, 
                             title: title,
                             fullText: fullTextFromDoc,
                             selectedThemes: themes,
                             selectedCharacters: characters,
                             selectedPersona: persona,
                             selectedLength: length,
                             initialIsPublic: isPublicStatus, 
                             ownerUserId: ownerUserId, 
                             currentUserId: _currentUser?.uid,
                             // --- PASS NEW FIELDS ---
                             selectedAgeRange: ageRange,
                             selectedLessons: lessons,
                             // --- END OF PASS NEW FIELDS ---
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
    );
  }
}