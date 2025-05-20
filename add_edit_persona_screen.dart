// lib/add_edit_persona_screen.dart - v1.1 (Add Edit Persona functionality)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEditPersonaScreen extends StatefulWidget {
  final String? personaDocId; // Document ID of the persona if editing
  final Map<String, dynamic>? initialPersonaData; // Initial data if editing

  const AddEditPersonaScreen({
    super.key,
    this.personaDocId, // Null when adding a new persona
    this.initialPersonaData, // Null when adding a new persona
  });

  @override
  State<AddEditPersonaScreen> createState() => _AddEditPersonaScreenState();
}

class _AddEditPersonaScreenState extends State<AddEditPersonaScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isEditing; // To determine if we are in "add" or "edit" mode

  // Text Editing Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.personaDocId != null && widget.initialPersonaData != null;

    if (_isEditing) {
      // If editing, pre-fill the controllers with existing data
      _nameController.text = widget.initialPersonaData!['personaName'] ?? '';
      _relationshipController.text = widget.initialPersonaData!['personaRelationship'] ?? '';
      _ageController.text = widget.initialPersonaData!['personaAge']?.toString() ?? ''; // Age might be int or string
      // Interests are stored as a List, join them into a comma-separated string for editing
      List<String> interestsList = List<String>.from(widget.initialPersonaData!['personaInterests'] ?? []);
      _interestsController.text = interestsList.join(', ');
      _notesController.text = widget.initialPersonaData!['notes'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipController.dispose();
    _ageController.dispose();
    _interestsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Function to save (add new or update existing) persona
  Future<void> _savePersona() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showError('Error: No user logged in.');
        setState(() { _isLoading = false; });
        return;
      }

      List<String> interestsList = _interestsController.text.split(',')
          .map((interest) => interest.trim())
          .where((interest) => interest.isNotEmpty)
          .toList();

      Map<String, dynamic> personaData = {
        'userId': currentUser.uid, // Always ensure userId is set/remains correct
        'personaName': _nameController.text.trim(),
        'personaRelationship': _relationshipController.text.trim(),
        'personaAge': _ageController.text.trim(),
        'personaInterests': interestsList,
        'notes': _notesController.text.trim(),
        // 'createdAt' is only set on creation, not usually updated.
        // If editing, Firestore automatically keeps existing 'createdAt'.
      };

      try {
        if (_isEditing) {
          // Update existing document
          await FirebaseFirestore.instance
              .collection('personas')
              .doc(widget.personaDocId!) // Use the passed document ID
              .update(personaData);
          print('Persona updated successfully: ${personaData['personaName']}');
          if (mounted) {
            _showSuccess('Persona updated successfully!');
            Navigator.of(context).pop();
          }
        } else {
          // Add new document (include createdAt)
          personaData['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance.collection('personas').add(personaData);
          print('Persona saved successfully: ${personaData['personaName']}');
          if (mounted) {
            _showSuccess('Persona saved successfully!');
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        print('Error saving/updating persona: $e');
        _showError('Failed to save persona: ${e.toString()}');
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }


  @override
  Widget build(BuildContext context) {
    String appBarTitle = _isEditing ? 'Edit Persona' : 'Add New Persona';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: _isEditing ? 'Update Persona' : 'Save Persona',
            onPressed: _isLoading ? null : _savePersona,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Section: Persona Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Persona Name*',
                        hintText: 'e.g., Liam, Grandma Rose',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name for the persona.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Section: Relationship
                    TextFormField(
                      controller: _relationshipController,
                      decoration: const InputDecoration(
                        labelText: 'Relationship (Optional)',
                        hintText: 'e.g., Child, Grandparent, Pet',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Section: Age
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Age / Age Group (Optional)',
                        hintText: 'e.g., 5, Toddler, Teenager',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Section: Interests
                    TextFormField(
                      controller: _interestsController,
                      decoration: const InputDecoration(
                        labelText: 'Interests (Optional, comma-separated)',
                        hintText: 'e.g., dinosaurs, space, fairy tales',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Section: Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'e.g., Loves happy endings, afraid of spiders',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                    ),
                    // The SizedBox(height: 24.0) and alternative save button can be kept or removed
                    // based on whether you want the save action only in the AppBar.
                  ],
                ),
              ),
            ),
    );
  }
}