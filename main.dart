// lib/main.dart - v3.3.7 (UI Cleanup - Labels & Whitespace)
import 'dart:convert';
import 'dart:math'; 
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'firebase_options.dart'; 
import 'login_screen.dart';
import 'library_screen.dart';
import 'public_browse_screen.dart';
import 'persona_list_screen.dart';
import 'models/persona_model.dart';
import 'api_config.dart'; 
import 'lesson_examples.dart'; 
import 'upgrade_screen.dart';
import 'content_detail_screen.dart'; // For pre-curated story navigation

Map<String, String?> _processAiResponse(String responseBody) {
  try {
    final jsonResponse = jsonDecode(responseBody);
    if (jsonResponse['candidates'] != null && jsonResponse['candidates'].isNotEmpty) {
      final parts = jsonResponse['candidates'][0]['content']['parts'];
      if (parts != null && parts.isNotEmpty && parts[0]['text'] != null) {
        String rawText = parts[0]['text'] as String;
        String? storyTitle; String? synopsis; String fullContent = rawText; 
        const titleMarker = "STORY_TITLE:"; const synopsisMarker = "SYNOPSIS_TEXT:";
        int titleStartIndex = rawText.indexOf(titleMarker); int titleEndIndex = -1;
        if (titleStartIndex != -1) {
          titleStartIndex += titleMarker.length;
          titleEndIndex = rawText.indexOf('\n', titleStartIndex);
          if (titleEndIndex != -1) { storyTitle = rawText.substring(titleStartIndex, titleEndIndex).trim(); } 
          else { storyTitle = rawText.substring(titleStartIndex).trim(); }
          fullContent = titleEndIndex != -1 ? rawText.substring(titleEndIndex).trim() : '';
        }
        int synopsisStartIndex = fullContent.indexOf(synopsisMarker);
        if (synopsisStartIndex != -1) {
          String contentPreSynopsis = fullContent.substring(0, synopsisStartIndex).trim();
          synopsis = fullContent.substring(synopsisStartIndex + synopsisMarker.length).trim();
          fullContent = contentPreSynopsis; 
        } else if (storyTitle != null && fullContent.trim().isEmpty) {
          int originalSynopsisIndex = rawText.indexOf(synopsisMarker);
          if (originalSynopsisIndex != -1 && (titleEndIndex == -1 || originalSynopsisIndex > titleEndIndex)) {
             synopsis = rawText.substring(originalSynopsisIndex + synopsisMarker.length).trim();
             if (titleEndIndex != -1) { fullContent = rawText.substring(titleEndIndex, originalSynopsisIndex).trim(); } 
             else { fullContent = rawText.substring(0, originalSynopsisIndex).trim(); }
          }
        }
        if (synopsis == null || synopsis.isEmpty) {
          var sentences = fullContent.trim().split(RegExp(r'(?<=[.!?])\s+'));
          synopsis = sentences.take(3).join(' ').trim();
          if (synopsis.isEmpty && fullContent.isNotEmpty) { synopsis = fullContent.substring(0, (fullContent.length > 150 ? 150 : fullContent.length)) + "..."; } 
          else if (synopsis.isEmpty && fullContent.isEmpty && storyTitle == null) { synopsis = "AI returned minimal or empty response.";}
        }
        fullContent = fullContent.replaceAll("TITLE:", "").trim();
        if (storyTitle != null && fullContent.startsWith(storyTitle)) { fullContent = fullContent.substring(storyTitle.length).trim(); }
        return {'storyTitle': storyTitle, 'synopsis': synopsis, 'fullText': fullContent.isEmpty ? "(Content may be brief or primarily in title/synopsis)" : fullContent};
      }
    }
    if (jsonResponse['promptFeedback'] != null && jsonResponse['promptFeedback']['blockReason'] != null) {
        String reason = jsonResponse['promptFeedback']['blockReason']; String safetyRatingsInfo = jsonResponse['promptFeedback']['safetyRatings']?.toString() ?? "";
        return {'storyTitle': 'Blocked', 'synopsis': 'Blocked by AI', 'fullText': 'Content generation was blocked. Reason: $reason. Details: $safetyRatingsInfo'};
    }
    return {'storyTitle': null, 'synopsis': 'Error parsing', 'fullText': 'Failed to parse AI response or no content structure found.'};
  } catch (e) {
    print("Error processing AI response in compute: $e");
    return {'storyTitle': null, 'synopsis': 'Error (catch)', 'fullText': 'Exception during AI response processing: $e'};
  }
}

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget { 
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'StoryStork', theme: ThemeData(primarySwatch: Colors.teal, visualDensity: VisualDensity.adaptivePlatformDensity, colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(secondary: Colors.orangeAccent, primaryContainer: Colors.teal[100],), elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.teal[600],),), snackBarTheme: SnackBarThemeData(backgroundColor: Colors.teal[700], contentTextStyle: const TextStyle(color: Colors.white),),),
      home: StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) { return const Scaffold(body: Center(child: CircularProgressIndicator())); } if (snapshot.hasData) { return const HomePage(); } return const LoginScreen(); },),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _promptController = TextEditingController();
  List<String> _selectedThemes = [];
  final int _maxThemes = 2;
  final List<String> _availableThemes = const ['Fantasy', 'Science Fiction', 'Mystery', 'Historical', 'Adventure', 'Humor', 'Friendship', 'Courage', 'Kindness', 'Discovery'];
  List<String> _selectedCharacters = [];
  final int _maxCharacters = 2;
  final List<String> _availableCharacters = const ['Dragon', 'Wizard', 'Alien', 'Robot', 'Detective', 'Knight', 'Goblin', 'Orc', 'Space Pirate', 'Robot Companion', 'Fairy', 'Unicorn', 'Talking Animal', 'Child Explorer', 'Lost Kitten', 'Brave Squirrel'];
  Persona? _selectedPersonaObject;
  final String _noPersonaOptionText = 'No Persona';
  String _selectedLength = '< 1 Minute'; 
  final List<String> _availableLengths = const ['< 1 Minute', '< 3 Minutes', '3+ Minutes'];
  String _contentType = 'Story'; 
  String? _selectedAgeRange; 
  final List<String> _availableAgeRanges = const ['Not Specified', '1-3 years', '3-5 years', '5-7 years', '7-10 years', '10+ years'];
  List<String> _selectedLessons = [];
  final List<String> _availableLessons = lessonExamples.keys.toList(); 
  final int _maxLessons = 1;

  String _displayStoryTitle = 'Title will appear here...';
  String _synopsis = 'Synopsis will appear here...';
  String _fullText = 'Full content will appear here...';
  String _appVersion = 'Loading version...';
  List<Persona> _userPersonas = [];
  bool _isLoadingPersonas = true;
  bool _isGenerating = false;
  int _storiesGeneratedThisWeek = 0; 
  Timestamp? _weeklyGenerationLimitLastReset; 
  final Map<String, int> _tierGenerationLimits = const { 'free': 7, 'premium': 30, 'unlimited': 1000000 };
  String _currentUserTier = 'free'; 

  String _lastSuccessfulPrompt = '';
  List<String> _lastSuccessfulThemes = [];
  List<String> _lastSuccessfulCharacters = [];
  Persona? _lastSuccessfulPersonaObject;
  String _lastSuccessfulLength = '< 1 Minute'; 
  String _lastSuccessfulContentType = 'Story'; 
  String? _lastSuccessfulAgeRange;
  List<String> _lastSuccessfulLessons = [];

  bool _contentHasBeenGenerated = false; 
  String? _generatedStoryTitleInternal; 

  final Random _random = Random();
  List<DocumentSnapshot> _precuratedStories = [];
  bool _isLoadingPrecurated = true;

  @override
  void initState() { 
    super.initState();
    _loadAppVersion();
    _fetchUserPersonas(); 
    _fetchCurrentUserTier(); 
    _fetchPrecuratedStories(); 
    if (_availableAgeRanges.isNotEmpty) { _selectedAgeRange = _availableAgeRanges[0]; }
    _selectedLength = _availableLengths.first; 
    _lastSuccessfulAgeRange = _selectedAgeRange;
    _lastSuccessfulLength = _selectedLength;
    _lastSuccessfulContentType = _contentType;
  }

  Future<void> _fetchPrecuratedStories() async { 
    if (!mounted) return; setState(() => _isLoadingPrecurated = true); try { QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('content').where('isPrecurated', isEqualTo: true).where('isPublic', isEqualTo: true).limit(5).get(); if (mounted) { setState(() { _precuratedStories = snapshot.docs; _isLoadingPrecurated = false; }); } } catch (e) { print("Error fetching pre-curated stories: $e"); if (mounted) { setState(() => _isLoadingPrecurated = false); _showSnackBar("Could not load featured stories.", isError: true); } }
  }
  Widget _buildPrecuratedStoryCard(BuildContext context, DocumentSnapshot doc) { 
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {}; String? storyTitle = data['storyTitle'] as String?; String contentType = data['type'] as String? ?? 'Content'; String displayTitle = storyTitle != null && storyTitle.isNotEmpty ? storyTitle : contentType; String synopsis = data['synopsis'] as String? ?? 'Tap to read more!';
    return Card(elevation: 2.0, margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), child: InkWell(onTap: () {Navigator.push(context, MaterialPageRoute(builder: (context) => ContentDetailScreen(documentId: doc.id, title: data['type'] as String? ?? 'Content', storyTitle: data['storyTitle'] as String?, synopsis: data['synopsis'] as String?, fullText: data['fullText'] as String? ?? 'Content not available.', selectedThemes: List<String>.from(data['selected_themes'] as List? ?? []), selectedCharacters: List<String>.from(data['selected_characters'] as List? ?? []), selectedPersona: data['selected_persona'] as String?, selectedLength: data['selected_length'] as String? ?? '< 3 Minutes', initialIsPublic: data['isPublic'] as bool? ?? true, ownerUserId: data['userId'] as String? ?? 'storystork_admin', currentUserId: FirebaseAuth.instance.currentUser?.uid, selectedAgeRange: data['selected_age_range'] as String?, selectedLessons: List<String>.from(data['selected_lessons'] as List? ?? []))));}, child: Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis,), const SizedBox(height: 4), Text(synopsis, style: TextStyle(fontSize: 12, color: Colors.grey[700]), maxLines: 3, overflow: TextOverflow.ellipsis,)],),),),);
  }
  Future<void> _fetchCurrentUserTier() async { 
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (mounted && userDoc.exists && userDoc.data() != null) { 
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() { _currentUserTier = data['currentTier'] as String? ?? 'free'; }); 
        }
      } catch (e) { print("Error fetching user tier: $e"); }
    }
  }
  @override
  void dispose() { _promptController.dispose(); super.dispose(); }
  void setStateIfMounted(void Function() fn) { if (mounted) { setState(fn); } }
  Future<void> _loadAppVersion() async { final PackageInfo packageInfo = await PackageInfo.fromPlatform(); if (mounted) setStateIfMounted(() => _appVersion = packageInfo.version); }
  Future<void> _fetchUserPersonas() async { if (mounted) setStateIfMounted(() => _isLoadingPersonas = true); User? currentUser = FirebaseAuth.instance.currentUser; if (currentUser == null) { if (mounted) setStateIfMounted(() { _isLoadingPersonas = false; _userPersonas = []; _selectedPersonaObject = null; }); return; } try { QuerySnapshot personaSnapshot = await FirebaseFirestore.instance.collection('personas').where('userId', isEqualTo: currentUser.uid).orderBy('personaName', descending: false).get(); List<Persona> fetchedPersonas = personaSnapshot.docs.map((doc) => Persona.fromFirestore(doc)).toList(); if (mounted) { setStateIfMounted(() { _userPersonas = fetchedPersonas; _isLoadingPersonas = false; if (_selectedPersonaObject != null && !_userPersonas.any((p) => p.id == _selectedPersonaObject!.id)) { _selectedPersonaObject = null; } }); } } catch (e) { print('Error fetching personas: $e'); if (mounted) { setStateIfMounted(() => _isLoadingPersonas = false); _showSnackBar('Error fetching personas: ${e.toString()}', isError: true); } } }
  void _showSnackBar(String message, {bool isError = false}) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent : Theme.of(context).snackBarTheme.backgroundColor, duration: const Duration(seconds: 3) )); }
  
  Future<void> _showThemeSelectionDialog() async { 
    List<String> tempSelectedThemes = List<String>.from(_selectedThemes); 
    await showDialog<List<String>>( context: context, builder: (BuildContext context) { 
      return StatefulBuilder(builder: (context, setDialogState) { 
        return AlertDialog( title: Text('Select Themes (Up to $_maxThemes)'), content: SingleChildScrollView(child: ListBody(children: _availableThemes.map((theme) { 
          final bool isSelected = tempSelectedThemes.contains(theme); 
          return CheckboxListTile( title: Text(theme), value: isSelected, onChanged: (bool? newValue) { 
            if (!mounted) return; 
            setDialogState(() { 
              if (newValue == true) { 
                if (tempSelectedThemes.length < _maxThemes) tempSelectedThemes.add(theme); 
                else { ScaffoldMessenger.of(this.context).removeCurrentSnackBar(); ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('You can select up to $_maxThemes themes only.'))); } 
              } else tempSelectedThemes.remove(theme); 
            }); 
          }, ); 
        }).toList())), actions: <Widget>[ TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()), TextButton(child: const Text('Done'), onPressed: () => Navigator.of(context).pop(tempSelectedThemes)), ], ); 
      }, ); 
    }, ).then((returnedSelectedThemes) { if (returnedSelectedThemes != null) { if (mounted) setStateIfMounted(() => _selectedThemes = returnedSelectedThemes); } }); 
  }

  Future<void> _showCharacterSelectionDialog() async { 
    List<String> tempSelectedCharacters = List<String>.from(_selectedCharacters); 
    await showDialog<List<String>>( context: context, builder: (BuildContext context) { 
      return StatefulBuilder( builder: (context, setDialogState) { 
        return AlertDialog( title: Text('Select Characters (Up to $_maxCharacters)'), content: SingleChildScrollView(child: ListBody(children: _availableCharacters.map((character) { 
          final bool isSelected = tempSelectedCharacters.contains(character); 
          return CheckboxListTile( title: Text(character), value: isSelected, onChanged: (bool? newValue) { 
            if (!mounted) return;
            setDialogState(() { 
              if (newValue == true) { 
                if (tempSelectedCharacters.length < _maxCharacters) tempSelectedCharacters.add(character); 
                else { ScaffoldMessenger.of(this.context).removeCurrentSnackBar(); ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('You can select up to $_maxCharacters characters only.'))); } 
              } else tempSelectedCharacters.remove(character); 
            }); 
          }, ); 
        }).toList())), actions: <Widget>[ TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()), TextButton(child: const Text('Done'), onPressed: () => Navigator.of(context).pop(tempSelectedCharacters)), ], ); 
      }, ); 
    }, ).then((returnedSelectedCharacters) { if (returnedSelectedCharacters != null) { if (mounted) setStateIfMounted(() => _selectedCharacters = returnedSelectedCharacters); } }); 
  }

  void _showPersonaDialog() async { 
    if (_isLoadingPersonas) { _showSnackBar("Personas still loading..."); return; } 
    if (_userPersonas.isEmpty) { _showSnackBar("No personas created yet. Add one from the menu!"); return; } 
    String? currentPersonaId = _selectedPersonaObject?.id; 
    Persona? result = await showDialog<Persona>(context: context, builder: (BuildContext context) { 
      return AlertDialog( title: const Text('Select Persona'), content: SizedBox(width: double.maxFinite, child: ListView.builder( shrinkWrap: true, itemCount: _userPersonas.length + 1, itemBuilder: (BuildContext context, int index) { 
        if (index == 0) { return RadioListTile<String?>(title: Text(_noPersonaOptionText), value: null, groupValue: currentPersonaId, onChanged: (String? value) { if(mounted) { Navigator.of(context).pop(null); }});} 
        final persona = _userPersonas[index - 1]; return RadioListTile<Persona>(title: Text(persona.personaName), value: persona, groupValue: _selectedPersonaObject, onChanged: (Persona? value) { if(mounted) { Navigator.of(context).pop(value); } });},),), 
        actions: [TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(_selectedPersonaObject))],);
    });
    // Check if mounted before calling setState after an async gap (showDialog)
    if (mounted && (result != null || (currentPersonaId != null && result == null))) { 
        setState(() => _selectedPersonaObject = result);
    }
  }

  void _showAgeRangeDialog() async { 
    String? currentAgeRange = _selectedAgeRange;
    String? result = await showDialog<String>(context: context, builder: (BuildContext context) { 
      return AlertDialog(title: const Text('Target Age Range'), content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: _availableAgeRanges.length, itemBuilder: (BuildContext context, int index) { 
        final age = _availableAgeRanges[index]; return RadioListTile<String>(title: Text(age), value: age, groupValue: currentAgeRange, onChanged: (String? value) { if(mounted) { Navigator.of(context).pop(value); } });})), 
        actions: [TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(currentAgeRange))],);
    });
    if (result != null && mounted) { setState(() => _selectedAgeRange = result); }
  }
  
  void _showLessonDialog() async { 
    String? currentLesson = _selectedLessons.isNotEmpty ? _selectedLessons.first : null; 
    String? result = await showDialog<String>(context: context, builder: (BuildContext context) { 
      return AlertDialog(title: Text('Lesson/Moral (Max $_maxLessons)'), content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: _availableLessons.length + 1, itemBuilder: (BuildContext context, int index) { 
        if (index == 0) { return RadioListTile<String?>(title: const Text('No Lesson'), value: null, groupValue: currentLesson, onChanged: (String? value) { if(mounted) {Navigator.of(context).pop(null); }}); } 
        final lessonKey = _availableLessons[index - 1]; return RadioListTile<String?>(title: Text(lessonKey), value: lessonKey, groupValue: currentLesson, onChanged: (String? value) { if(mounted) { Navigator.of(context).pop(value); } });})), 
        actions: [TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(currentLesson))],);
    });
    if (mounted) { setState(() => _selectedLessons = result != null ? [result] : []); }
  }

  String _buildFullPrompt() { 
    String prompt = _promptController.text; String contentTypeString = _contentType; String personaDetails = ""; if (_selectedPersonaObject != null) { personaDetails = " Involve a character based on this persona: Name: ${_selectedPersonaObject!.personaName}."; if (_selectedPersonaObject!.personaRelationship != null && _selectedPersonaObject!.personaRelationship!.isNotEmpty) personaDetails += " Relationship to main character/reader: ${_selectedPersonaObject!.personaRelationship}."; if (_selectedPersonaObject!.personaAge != null && _selectedPersonaObject!.personaAge!.isNotEmpty) personaDetails += " Age: ${_selectedPersonaObject!.personaAge}."; if (_selectedPersonaObject!.personaInterests.isNotEmpty) personaDetails += " Interests: ${_selectedPersonaObject!.personaInterests.join(', ')}."; if (_selectedPersonaObject!.notes != null && _selectedPersonaObject!.notes!.isNotEmpty) personaDetails += " Notes: ${_selectedPersonaObject!.notes}.";}
    String themesString = _selectedThemes.isNotEmpty ? " Themes: ${_selectedThemes.join(' and ')}." : ""; String charactersString = _selectedCharacters.isNotEmpty ? " Main Characters: ${_selectedCharacters.join(' and ')}." : ""; String lengthInstruction; if (_selectedLength == '< 1 Minute') { lengthInstruction = " Keep the ${contentTypeString.toLowerCase()} very short, like a brief anecdote or a very short poem, suitable for less than a minute of reading time.";} else if (_selectedLength == '< 3 Minutes') { lengthInstruction = " Make the ${contentTypeString.toLowerCase()} a short piece, suitable for about 1 to 3 minutes of reading time, with a concise plot or theme.";} else { lengthInstruction = " Develop the ${contentTypeString.toLowerCase()} with more detail and depth, suitable for 3 minutes or more of reading time, allowing for a more involved plot or exploration of themes.";}
    String ageInstruction = (_selectedAgeRange != null && _selectedAgeRange != 'Not Specified') ? " The target age range for this ${contentTypeString.toLowerCase()} is $_selectedAgeRange." : ""; String lessonInstruction = ""; if (_selectedLessons.isNotEmpty) { String selectedLessonKey = _selectedLessons.first; if (lessonExamples.containsKey(selectedLessonKey)) { String exampleSummary = lessonExamples[selectedLessonKey]!['summary']!; lessonInstruction = " The ${contentTypeString.toLowerCase()} should subtly incorporate the lesson or moral: '${exampleSummary.replaceAll("'", "\\'")}'.";} else { lessonInstruction = " The ${contentTypeString.toLowerCase()} should subtly incorporate a lesson about $selectedLessonKey."; } }
    String titleRequestInstruction = "At the very beginning of your response, before any other content, provide a short, catchy title for the story/poem, labeled exactly as 'STORY_TITLE:'."; String synopsisRequestInstruction = "After the main content, provide a 2-3 sentence synopsis labeled exactly as 'SYNOPSIS_TEXT:'.";
    return "$titleRequestInstruction\n\nGenerate a children's ${contentTypeString.toLowerCase()}. Main idea: \"$prompt\". $themesString$charactersString$personaDetails$lengthInstruction$ageInstruction$lessonInstruction Ensure the ${contentTypeString.toLowerCase()} has a clear beginning, middle, and end. Do not use explicit structural labels like 'Beginning:', 'Middle:', or 'End:' in the main content.\n\n$synopsisRequestInstruction";
  }

  Future<Map<String, String?>> _callAiToGenerateContent({ 
    required String userPrompt, required String contentType, required List<String> selectedThemes, required List<String> selectedCharacters, required Persona? selectedPersonaObject, required String? selectedAgeRange, required List<String> selectedLessons, required String selectedLength,
  }) async { 
      final String combinedPrompt = _buildFullPrompt(); 
      print('--- Sending Combined Prompt to AI (v3.3.5) ---'); // Updated version
      print(combinedPrompt);
      int currentMaxTokens;
      if (selectedLength == '< 1 Minute') { currentMaxTokens = 300; } 
      else if (selectedLength == '< 3 Minutes') { currentMaxTokens = 700; } 
      else { currentMaxTokens = 1500; }
      Uri uri = Uri.parse('$googleAiApiEndpoint?key=$googleAiApiKey');
      Map<String, dynamic> requestBody = { "contents": [{"parts": [{"text": combinedPrompt}]}], "generationConfig": { "maxOutputTokens": currentMaxTokens },};
      Map<String, String?> resultFromAI = {'storyTitle': null, 'synopsis': 'Error generating content.', 'fullText': 'An unexpected error occurred.'};
      try { http.Response response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(requestBody)); if (response.statusCode == 200) { resultFromAI = await compute(_processAiResponse, response.body); } else { String responseBodyError = response.body; try { final decodedBody = jsonDecode(responseBodyError); if (decodedBody['error'] != null && decodedBody['error']['message'] != null) { responseBodyError = decodedBody['error']['message']; }} catch(_){} resultFromAI = {'storyTitle': null, 'synopsis': 'Error: API Request Failed', 'fullText': 'Error generating content: ${response.statusCode}\n$responseBodyError'}; if(mounted) _showSnackBar('Error generating content: ${response.statusCode}', isError: true); }} catch (e) { print('Error making API request or during compute: $e'); resultFromAI = {'storyTitle': null, 'synopsis': 'Error: Network or Processing', 'fullText': 'Network error or exception: Could not connect to AI service or process response.\n$e'}; if(mounted) _showSnackBar('Network error or processing issue. Please try again.', isError: true); }
      return resultFromAI;
  }

  Future<void> _handleGenerateButtonPressed() async { 
    if (!mounted) return;
    final String currentPrompt = _promptController.text.trim();
    final String currentContentType = _contentType;
    final List<String> currentThemes = List.from(_selectedThemes);
    final List<String> currentCharacters = List.from(_selectedCharacters);
    final Persona? currentPersonaObject = _selectedPersonaObject;
    final String? currentAgeRange = _selectedAgeRange;
    final List<String> currentLessons = List.from(_selectedLessons);
    final String currentLength = _selectedLength; 

    setStateIfMounted(() { _isGenerating = true; _displayStoryTitle = 'Generating title...'; _synopsis = 'Generating synopsis...'; _fullText = 'Generating content, please wait...'; _contentHasBeenGenerated = false; });
    User? currentUser = FirebaseAuth.instance.currentUser; if (currentUser == null) { if(mounted) _showSnackBar("You must be logged in to generate content.", isError: true); setStateIfMounted(() => _isGenerating = false); return;}
    
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
    Map<String, dynamic> userData = {}; 
    try {
      DocumentSnapshot userDocSnapshot = await userDocRef.get();
      userData = userDocSnapshot.data() as Map<String, dynamic>? ?? {};
      if (mounted) { setState(() { _currentUserTier = userData['currentTier'] as String? ?? 'free';}); }
    } catch (e) { print("Error fetching user tier for _handleGenerateButtonPressed: $e"); if(mounted) _showSnackBar('Could not verify your user plan. Please try again.', isError: true); setStateIfMounted(() => _isGenerating = false); return;}

    if (currentLength == '3+ Minutes' && _currentUserTier != 'unlimited') { 
      if (mounted) { showDialog( context: context, builder: (BuildContext dialogContext) { return AlertDialog( title: const Text('Upgrade Required'), content: const Text('The "3+ Minutes" story length is an exclusive feature for our Unlimited plan subscribers. Please upgrade to create longer stories!'), actions: <Widget>[ TextButton(child: const Text('Upgrade Options'), onPressed: () {Navigator.of(dialogContext).pop(); Navigator.push(context, MaterialPageRoute(builder: (context) => const UpgradeScreen())); },), TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),],);},);}
      setStateIfMounted(() { _isGenerating = false; _displayStoryTitle = 'Title will appear here...'; _synopsis = 'Synopsis will appear here...'; _fullText = 'Full content will appear here...';}); return; 
    }

    bool canGenerate = false; bool wasResetForGeneration = false; 
    int generationLimitForTier = _tierGenerationLimits[_currentUserTier] ?? _tierGenerationLimits['free']!; 
    _storiesGeneratedThisWeek = userData['storiesGeneratedThisWeek'] as int? ?? 0; 
    _weeklyGenerationLimitLastReset = userData['weeklyGenerationLimitLastReset'] as Timestamp?;
    DateTime lastResetDate = _weeklyGenerationLimitLastReset?.toDate() ?? DateTime.now().subtract(const Duration(days: 8));
    DateTime now = DateTime.now();
    if (now.difference(lastResetDate).inDays >= 7) { wasResetForGeneration = true; } 
    int currentGenerationCountForCheck = wasResetForGeneration ? 0 : _storiesGeneratedThisWeek; 
    if (currentGenerationCountForCheck < generationLimitForTier) { canGenerate = true; } 
    else { canGenerate = false; }
    
    if (!canGenerate) { if (mounted) {showDialog(context: context, builder: (BuildContext dialogContext) { return AlertDialog(title: const Text('Generation Limit Reached'), content: Text('You\'ve reached your weekly limit of $generationLimitForTier story generations for your "$_currentUserTier" plan. Please upgrade for more!'), actions: <Widget>[ TextButton( child: const Text('Upgrade Options'), onPressed: () { Navigator.of(dialogContext).pop(); Navigator.push(context, MaterialPageRoute(builder: (context) => const UpgradeScreen())); },), TextButton( child: const Text('OK'), onPressed: () { Navigator.of(dialogContext).pop(); }),],);},);} setStateIfMounted(() { _isGenerating = false; _displayStoryTitle = 'Title will appear here...'; _synopsis = 'Synopsis will appear here...'; _fullText = 'Full content will appear here...'; }); return;}
    
    Map<String, String?> generatedContentResult = await _callAiToGenerateContent( 
      userPrompt: currentPrompt, contentType: currentContentType, selectedThemes: currentThemes, selectedCharacters: currentCharacters, selectedPersonaObject: currentPersonaObject, selectedAgeRange: currentAgeRange, selectedLessons: currentLessons, 
      selectedLength: currentLength, 
    );
    
    if (mounted) { setStateIfMounted(() { _generatedStoryTitleInternal = generatedContentResult['storyTitle']; _displayStoryTitle = _generatedStoryTitleInternal ?? 'Title not generated'; _synopsis = generatedContentResult['synopsis'] ?? 'Synopsis error.'; _fullText = generatedContentResult['fullText'] ?? 'Content error.'; String currentSynopsisVal = generatedContentResult['synopsis'] ?? ''; String currentFullTextVal = generatedContentResult['fullText'] ?? ''; bool synopsisIndicatesSuccess = currentSynopsisVal.isNotEmpty && currentSynopsisVal != 'Error' && currentSynopsisVal != 'Blocked by AI'; bool fullTextIndicatesSuccess = currentFullTextVal.isNotEmpty && !currentFullTextVal.startsWith('Error:') && !currentFullTextVal.startsWith('Network error:') && !currentFullTextVal.contains("Content generation was blocked"); _contentHasBeenGenerated = synopsisIndicatesSuccess && fullTextIndicatesSuccess && (_generatedStoryTitleInternal != null && _generatedStoryTitleInternal != "Blocked"); });}
    
    if (_contentHasBeenGenerated) { 
        _lastSuccessfulPrompt = currentPrompt;
        _lastSuccessfulContentType = currentContentType;
        _lastSuccessfulThemes = List.from(currentThemes);
        _lastSuccessfulCharacters = List.from(currentCharacters);
        _lastSuccessfulPersonaObject = currentPersonaObject; 
        _lastSuccessfulAgeRange = currentAgeRange;
        _lastSuccessfulLessons = List.from(currentLessons);
        _lastSuccessfulLength = currentLength;

        Map<String, dynamic> contentData = { 'userId': currentUser.uid, 'type': currentContentType, 'storyTitle': _generatedStoryTitleInternal, 'synopsis': _synopsis, 'fullText': _fullText, 'prompt': currentPrompt, 'created_at': FieldValue.serverTimestamp(), 'isPublic': false, 'selected_themes': currentThemes, 'selected_characters': currentCharacters, 'selected_persona': currentPersonaObject?.personaName, 'selected_length': currentLength, 'selected_age_range': currentAgeRange == 'Not Specified' ? null : currentAgeRange, 'selected_lessons': currentLessons, 'viewCount': 0, 'upvoteCount': 0}; 
        try { await FirebaseFirestore.instance.collection('content').add(contentData); if(mounted) _showSnackBar('Content saved successfully!'); Map<String, dynamic> userUpdates = {}; if (wasResetForGeneration) { userUpdates['storiesGeneratedThisWeek'] = 1; userUpdates['weeklyGenerationLimitLastReset'] = FieldValue.serverTimestamp(); } else { userUpdates['storiesGeneratedThisWeek'] = FieldValue.increment(1); } await userDocRef.update(userUpdates); if(mounted) setStateIfMounted(() { _storiesGeneratedThisWeek = wasResetForGeneration ? 1 : _storiesGeneratedThisWeek + 1; if(wasResetForGeneration) _weeklyGenerationLimitLastReset = Timestamp.now(); }); 
        } catch (e) { print('Error saving content to Firestore or updating user count: $e'); if(mounted) _showSnackBar('Error saving content or updating usage: ${e.toString()}', isError: true); } 
    }
    if(mounted) setStateIfMounted(() => _isGenerating = false);
  }

  void _randomizeSelectionsAndUpdateUI() {
    if (_isGenerating) return; 
    _promptController.clear(); 
    List<String> randomThemes = []; int numThemes = _random.nextInt(_maxThemes + 1); List<String> shuffledThemes = List.from(_availableThemes)..shuffle(_random); if (numThemes > 0 && shuffledThemes.isNotEmpty) { randomThemes = shuffledThemes.take(numThemes).toList();}
    List<String> randomCharacters = []; int numChars = _random.nextInt(_maxCharacters + 1); List<String> shuffledChars = List.from(_availableCharacters)..shuffle(_random); if (numChars > 0 && shuffledChars.isNotEmpty) { randomCharacters = shuffledChars.take(numChars).toList();}
    String randomAgeRange = _availableAgeRanges[_random.nextInt(_availableAgeRanges.length)];
    List<String> randomLessons = []; if (_availableLessons.isNotEmpty && _random.nextBool()) { randomLessons.add(_availableLessons[_random.nextInt(_availableLessons.length)]);}
    Persona? randomPersona; if (_userPersonas.isNotEmpty && _random.nextBool()) { randomPersona = _userPersonas[_random.nextInt(_userPersonas.length)];}
    String randomContentType = _random.nextBool() ? 'Story' : 'Poem';
    List<String> accessibleLengths = List.from(_availableLengths); if (_currentUserTier != 'unlimited') { accessibleLengths.remove('3+ Minutes');}
    String randomLength = accessibleLengths.isNotEmpty ? accessibleLengths[_random.nextInt(accessibleLengths.length)] : _availableLengths.first; 
    setStateIfMounted(() { _selectedThemes = randomThemes; _selectedCharacters = randomCharacters; _selectedAgeRange = randomAgeRange; _selectedLessons = randomLessons; _selectedPersonaObject = randomPersona; _contentType = randomContentType; _selectedLength = randomLength; _displayStoryTitle = 'Title will appear here...'; _synopsis = 'Synopsis will appear here...'; _fullText = 'Full content will appear here...'; _contentHasBeenGenerated = false; });
    if(mounted) _showSnackBar('Inputs have been randomized! Press "Generate Content".', isError: false);
  }

  void _handleRegenerateButtonPressed() {
    if (_isGenerating) return;
    if (_lastSuccessfulPrompt.isEmpty && !_contentHasBeenGenerated) { 
        if(mounted) _showSnackBar('Generate a story successfully first to use Regenerate.', isError: true); return;
    }
    setStateIfMounted(() {
        _promptController.text = _lastSuccessfulPrompt; _contentType = _lastSuccessfulContentType; _selectedThemes = List.from(_lastSuccessfulThemes); _selectedCharacters = List.from(_lastSuccessfulCharacters); _selectedPersonaObject = _lastSuccessfulPersonaObject; _selectedAgeRange = _lastSuccessfulAgeRange; _selectedLessons = List.from(_lastSuccessfulLessons); _selectedLength = _lastSuccessfulLength;
        _displayStoryTitle = 'Regenerating title...'; _synopsis = 'Regenerating synopsis...'; _fullText = 'Regenerating content...'; _contentHasBeenGenerated = false; 
    });
    if(mounted) _showSnackBar('Regenerating with last successful inputs...');
    _handleGenerateButtonPressed(); 
  }

  @override
  Widget build(BuildContext context) {
    // --- MODIFIED: Shorter button labels by default ---
    String characterButtonLabelText = _selectedCharacters.isEmpty ? 'Characters' : 'Characters (${_selectedCharacters.length})'; 
    String themeButtonLabelText = _selectedThemes.isEmpty ? 'Themes' : 'Themes (${_selectedThemes.length})';
    // --- END MODIFICATION ---

    final ButtonStyle influenceButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), 
      foregroundColor: Theme.of(context).textTheme.bodyLarge?.color, 
      elevation: 1, 
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)), 
      side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5))
    );
    
    const TextStyle sectionHeaderStyle = TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.black87);

    return Scaffold(
      appBar: AppBar( 
        leading: IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _isGenerating ? null : () async { await FirebaseAuth.instance.signOut(); if (mounted) {Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (Route<dynamic> route) => false); } } ),
        title: const Text('StoryStork'), centerTitle: true, 
        actions: <Widget>[ 
          IconButton(icon: const Icon(Icons.library_books), tooltip: 'My Library', onPressed: _isGenerating ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LibraryScreen()))), 
          IconButton(icon: const Icon(Icons.explore), tooltip: 'Browse Public Stories', onPressed: _isGenerating ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PublicBrowseScreen()))), 
          IconButton(icon: const Icon(Icons.face_retouching_natural), tooltip: 'My Personas', onPressed: _isGenerating ? null : () { Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonaListScreen())).then((_) => _fetchUserPersonas()); }), 
          IconButton(icon: const Icon(Icons.workspace_premium_outlined), tooltip: 'Upgrade Plan', onPressed: _isGenerating ? null : () { Navigator.push( context, MaterialPageRoute(builder: (context) => const UpgradeScreen())); },),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: ListView( 
          children: <Widget>[
            if (_isLoadingPrecurated) const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
            else if (_precuratedStories.isNotEmpty) ...[ Padding(padding: const EdgeInsets.only(top: 4.0, bottom: 8.0), child: Text('Featured Free Stories', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center,),), SizedBox(height: 160, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _precuratedStories.length, itemBuilder: (context, index) { return SizedBox(width: MediaQuery.of(context).size.width * 0.55, child: _buildPrecuratedStoryCard(context, _precuratedStories[index]),);},),), const Divider(height: 24, thickness: 1),],
            
            Text('I want a:', style: sectionHeaderStyle), 
            Row(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[Expanded(child: RadioListTile<String>(title: const Text('Story', style: TextStyle(fontSize: 14)), value: 'Story', groupValue: _contentType, dense: true, contentPadding: EdgeInsets.zero, onChanged: _isGenerating ? null : (val) => setStateIfMounted(() => _contentType = val!))), Expanded(child: RadioListTile<String>(title: const Text('Poem', style: TextStyle(fontSize: 14)), value: 'Poem', groupValue: _contentType, dense: true, contentPadding: EdgeInsets.zero, onChanged: _isGenerating ? null : (val) => setStateIfMounted(() => _contentType = val!))),]), 
            const SizedBox(height: 10.0), // Reduced whitespace
            
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: TextField(controller: _promptController, decoration: InputDecoration(hintText: 'Enter a prompt, or use the dice to randomize!', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)), maxLines: 3, keyboardType: TextInputType.multiline, enabled: !_isGenerating),), const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(top: 4.0), child: IconButton(icon: Icon(Icons.casino_outlined, size: 28, color: Theme.of(context).primaryColor.withOpacity(0.8)), tooltip: 'Randomize Inputs', onPressed: _isGenerating ? null : _randomizeSelectionsAndUpdateUI,),)],), 
            const SizedBox(height: 10.0), // Reduced whitespace

            // --- UI MODIFICATION: Buttons for influence selection ---
            Wrap(
              spacing: 6.0, runSpacing: 6.0, alignment: WrapAlignment.start,
              children: <Widget>[
                ElevatedButton.icon(icon: const Icon(Icons.palette_outlined, size: 16), label: Text(themeButtonLabelText), onPressed: _isGenerating ? null : _showThemeSelectionDialog, style: influenceButtonStyle),
                ElevatedButton.icon(icon: const Icon(Icons.person_search_outlined, size: 16), label: Text(characterButtonLabelText), onPressed: _isGenerating ? null : _showCharacterSelectionDialog, style: influenceButtonStyle),
                ElevatedButton.icon(icon: const Icon(Icons.face_retouching_natural_outlined, size: 16), label: Text(_selectedPersonaObject != null ? 'Persona: ${_selectedPersonaObject!.personaName.split(" ").first}' : 'Persona'), onPressed: _isGenerating ? null : _showPersonaDialog, style: influenceButtonStyle),
                ElevatedButton.icon(icon: const Icon(Icons.child_care_outlined, size: 16), label: Text(_selectedAgeRange != null && _selectedAgeRange != 'Not Specified' ? 'Age: $_selectedAgeRange' : 'Age Range'), onPressed: _isGenerating ? null : _showAgeRangeDialog, style: influenceButtonStyle),
                ElevatedButton.icon(icon: const Icon(Icons.school_outlined, size: 16), label: Text(_selectedLessons.isNotEmpty ? 'Lesson: ${_selectedLessons.first}' : 'Lesson'), onPressed: _isGenerating ? null : _showLessonDialog, style: influenceButtonStyle),
              ],
            ),
            // Chips for selected themes and characters (if any)
            if (_selectedThemes.isNotEmpty) ...[ const SizedBox(height: 4.0), Wrap(spacing: 6.0, runSpacing: 4.0, children: _selectedThemes.map((theme) => Chip(label: Text(theme, style: const TextStyle(fontSize: 11)),onDeleted: _isGenerating ? null : () => setStateIfMounted(() => _selectedThemes.remove(theme)), padding: const EdgeInsets.all(2), visualDensity: VisualDensity.compact)).toList())],
            if (_selectedCharacters.isNotEmpty) ...[ const SizedBox(height: 4.0), Wrap(spacing: 6.0, runSpacing: 4.0, children: _selectedCharacters.map((character) => Chip(label: Text(character, style: const TextStyle(fontSize: 11)),onDeleted: _isGenerating ? null : () => setStateIfMounted(() => _selectedCharacters.remove(character)), padding: const EdgeInsets.all(2), visualDensity: VisualDensity.compact)).toList())], 
            const SizedBox(height: 10.0), // Reduced whitespace
            
            // --- Assuming the buttons above now handle selection dialogs for Age, Lesson, Persona ---
            // The dedicated Dropdowns/ChoiceChip sections for these are removed for brevity
            // If you want to keep them as alternative selection methods, they can be added back.
            // For this cleanup, I'm assuming the buttons are the primary way.

            Text('Story Length:', style: sectionHeaderStyle), // Changed label
            const SizedBox(height: 4.0),
            Wrap( spacing: 6.0, runSpacing: 4.0, alignment: WrapAlignment.center, children: _availableLengths.map((lengthOpt) { bool isSelected = _selectedLength == lengthOpt; bool isDisabled = lengthOpt == '3+ Minutes' && _currentUserTier != 'unlimited'; String? tagText; Color? tagColor; if (lengthOpt == '< 3 Minutes' && _currentUserTier == 'free') { tagText = 'Premium'; tagColor = Colors.orange[700]; } else if (lengthOpt == '3+ Minutes') { tagText = 'Unlimited'; tagColor = Colors.purple[700]; }
                Widget chip = ChoiceChip(label: Padding(padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0), child: Text(lengthOpt, style: const TextStyle(fontSize: 11))), selected: isSelected, visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: isDisabled ? Colors.grey[350] : (isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[200]), labelStyle: TextStyle( color: isDisabled ? Colors.grey[500] : (isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).textTheme.bodyLarge?.color), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), onSelected: (_isGenerating || isDisabled) ? null : (bool selected) { if (selected) { setStateIfMounted(() => _selectedLength = lengthOpt); }},);
                if (tagText != null) { return Stack( clipBehavior: Clip.none, alignment: Alignment.topRight, children: [ chip, Positioned( right: -5, top: -7, child: Container( padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration( color: tagColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white, width: 0.5) ), child: Text(tagText, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),),),],); }
                return chip;
              }).toList(),
            ), 
            const SizedBox(height: 16.0), // Adjusted spacing

            ElevatedButton(onPressed: _isGenerating ? null : _handleGenerateButtonPressed, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))), child: _isGenerating ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Generate Content'),), 
            const SizedBox(height: 6.0), 
            if (_contentHasBeenGenerated || _lastSuccessfulPrompt.isNotEmpty) ElevatedButton.icon(icon: const Icon(Icons.refresh, size: 18), label: const Text('Regenerate'), onPressed: _isGenerating ? null : _handleRegenerateButtonPressed, style: ElevatedButton.styleFrom( backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 18.0), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),),
            const SizedBox(height: 12.0), 
            
            if (_contentHasBeenGenerated || _isGenerating && _displayStoryTitle.contains('Generating')) Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Title:', style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold)), const SizedBox(height: 4.0), Container( padding: const EdgeInsets.all(10.0), width: double.infinity, decoration: BoxDecoration(color: Colors.blueGrey[50], border: Border.all(color: Colors.blueGrey.shade100), borderRadius: BorderRadius.circular(8.0)), child: Text(_displayStoryTitle, style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic)),), const SizedBox(height: 12.0),],),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[ const Text('Synopsis:', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)), const SizedBox(height: 4.0), Container( padding: const EdgeInsets.all(8.0), width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4.0)), child: Text(_synopsis, style: const TextStyle(fontSize: 15.0, fontStyle: FontStyle.italic)),), const SizedBox(height: 12.0), const Text('Full Content:', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)), const SizedBox(height: 4.0), Container( padding: const EdgeInsets.all(8.0), width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4.0)), child: Text(_fullText, style: const TextStyle(fontSize: 15.0)),), ]), 
            const SizedBox(height: 12.0), 
            Text('App Version: $_appVersion', style: const TextStyle(fontSize: 11.0, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}