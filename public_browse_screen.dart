// lib/public_browse_screen.dart - v1.1 (Fetches public content, navigates to detail or login)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To check if user is logged in
import 'content_detail_screen.dart'; // To navigate to view full content
import 'login_screen.dart'; // To navigate to login if not authenticated

class PublicBrowseScreen extends StatelessWidget {
  const PublicBrowseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final User? currentUser = FirebaseAuth.instance.currentUser; // Get current user

    return Scaffold(
      appBar: AppBar(
        title: const Text('Public Stories & Poems'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Section: Firestore Query for Public Content
        // Fetches documents from the 'content' collection where 'isPublic' is true.
        // Orders them by 'created_at' timestamp in descending order (newest first).
        stream: firestore
            .collection('content')
            .where('isPublic', isEqualTo: true)
            .orderBy('created_at', descending: true)
            .snapshots(),
        
        // Section: StreamBuilder Builder Function
        // Builds the UI based on the state of the Firestore stream.
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          // Subsection: Handle stream errors
          if (snapshot.hasError) {
            print('Error fetching public content: ${snapshot.error}');
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }

          // Subsection: Handle stream loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Subsection: Handle no public content found
          if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No public content available at the moment.'));
          }

          // Subsection: Display public content in a ListView if data exists
          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;

              // Extract all necessary data for display and navigation
              String docId = document.id;
              String title = data['type'] ?? 'Untitled Content';
              String synopsis = data['synopsis'] ?? 'No synopsis available.';
              String fullTextFromDoc = data['fullText'] ?? 'Full content not available.';
              List<String> themes = List<String>.from(data['selected_themes'] ?? []);
              List<String> characters = List<String>.from(data['selected_characters'] ?? []);
              String? persona = data['selected_persona'] as String?;
              String length = data['selected_length'] ?? 'Medium';
              bool isPublicStatus = data['isPublic'] ?? false; // Should always be true here
              String ownerUserId = data['userId'] ?? ''; 
              String? ageRange = data['selected_age_range'] as String?; // Fetch age range
              List<String> lessons = List<String>.from(data['selected_lessons'] ?? []); // Fetch lessons


              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    synopsis,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    // Subsection: Handle tap on a list item
                    if (currentUser != null) {
                      // User is logged in, navigate to content detail screen
                      print('Logged-in user tapping public content ID: $docId');
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
                            currentUserId: currentUser.uid, 
                            selectedAgeRange: ageRange, // Pass age range
                            selectedLessons: lessons,   // Pass lessons
                          ),
                        ),
                      );
                    } else {
                      // User is not logged in, show a dialog prompting them to login/signup
                      print('Non-logged-in user tapping public content ID: $docId. Prompting login.');
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: const Text('View Full Story'),
                            content: const Text('Please log in or create an account to view the full story and access more features.'),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(); // Dismiss dialog
                                },
                              ),
                              TextButton(
                                child: const Text('Login/Sign Up'),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(); // Dismiss dialog
                                  Navigator.push( // Navigate to LoginScreen
                                    context,
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      );
                    }
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