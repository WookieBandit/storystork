// lib/content_detail_screen.dart - v1.7.1 (Upvote Button and Logic - Corrected)
import 'dart:convert'; 
import 'dart:io'; 
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'api_config.dart'; 

class ContentDetailScreen extends StatefulWidget {
  final String documentId;
  final String title;         // Content TYPE ("Story", "Poem")
  final String? storyTitle;   // AI-Generated Title
  final String? synopsis;     
  final String fullText;
  final List<String> selectedThemes;
  final List<String> selectedCharacters;
  final String? selectedPersona;
  final String selectedLength; 
  final bool initialIsPublic;
  final String ownerUserId;
  final String? currentUserId;
  final String? selectedAgeRange;
  final List<String> selectedLessons;

  const ContentDetailScreen({
    super.key,
    required this.documentId,
    required this.title,         
    this.storyTitle,             
    this.synopsis,               
    required this.fullText,
    required this.selectedThemes,
    required this.selectedCharacters,
    this.selectedPersona,
    required this.selectedLength,
    required this.initialIsPublic,
    required this.ownerUserId,
    this.currentUserId,
    this.selectedAgeRange,
    required this.selectedLessons,
  });

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  late bool _isPublic;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; 
  
  bool _isRequestingAudio = false;
  bool _isAudioReady = false;
  bool _isPlayingAudio = false;
  String? _audioFilePath; // This IS used in _requestAndPrepareAudio and audio controls

  final Map<String, String> _elevenLabsVoices = {
    'Rachel (Female Narrator)': '21m00Tcm4TlvDq8ikWAM',
    'Adam (Male Narrator)': 'pNInz6obpgDQGcFmaJgB',
  };
  late String _selectedElevenLabsVoiceId;

  int _currentViewCount = 0;
  bool _viewCountFetched = false;
  bool _isFavorited = false;
  bool _isLoadingFavoriteStatus = true;
  String? _favoriteDocId; 

  // --- State variables for Upvotes ---
  int _currentUpvoteCount = 0;
  bool _hasUpvoted = false;
  bool _isLoadingUpvoteStatus = true;
  String? _upvoteDocId; 
  // --- END Upvotes State ---

  @override
  void initState() {
    super.initState();
    _isPublic = widget.initialIsPublic;
    _selectedElevenLabsVoiceId = _elevenLabsVoices.values.first;

    _audioPlayer.playerStateStream.listen((playerState) {
      if (!mounted) return;
      final bool isPlaying = playerState.playing;
      if (_isPlayingAudio != isPlaying) {
        setState(() => _isPlayingAudio = isPlaying);
      }
      if (playerState.processingState == ProcessingState.completed) {
        setState(() => _isPlayingAudio = false);
        _audioPlayer.seek(Duration.zero);
      }
    });

    _fetchAndIncrementViewCount();

    if (widget.currentUserId != null) {
      _checkIfFavorited();
      _loadInitialUpvoteData(); // Load upvote status
    } else {
      setState(() {
        _isLoadingFavoriteStatus = false;
        _isLoadingUpvoteStatus = false; 
      });
    }
  }

  Future<void> _checkIfFavorited() async { 
    if (widget.currentUserId == null || !mounted) { setState(() => _isLoadingFavoriteStatus = false); return; }
    setState(() => _isLoadingFavoriteStatus = true);
    try {
      final querySnapshot = await _firestore.collection('user_favorites').where('userId', isEqualTo: widget.currentUserId).where('contentId', isEqualTo: widget.documentId).limit(1).get();
      if (mounted) { setState(() { if (querySnapshot.docs.isNotEmpty) { _isFavorited = true; _favoriteDocId = querySnapshot.docs.first.id; } else { _isFavorited = false; _favoriteDocId = null; } _isLoadingFavoriteStatus = false; });}
    } catch (e) { print("Error checking favorite status: $e"); if (mounted) { setState(() => _isLoadingFavoriteStatus = false); } }
  }

  Future<void> _toggleFavoriteStatus() async { 
    if (widget.currentUserId == null) { _showSnackBar('Please log in to add to favorites.', isError: true); return; }
    if (_isLoadingFavoriteStatus) return; 
    setState(() => _isLoadingFavoriteStatus = true);
    final String effectiveDisplayTitle = widget.storyTitle != null && widget.storyTitle!.isNotEmpty ? widget.storyTitle! : widget.title; 
    if (_isFavorited) { if (_favoriteDocId != null) { try { await _firestore.collection('user_favorites').doc(_favoriteDocId).delete(); if (mounted) { setState(() { _isFavorited = false; _favoriteDocId = null; }); _showSnackBar('Removed from Favorites.'); } } catch (e) { print("Error removing favorite: $e"); if (mounted) _showSnackBar('Could not remove from Favorites. Please try again.', isError: true); } } else { if (mounted) _showSnackBar('Error: Favorite reference not found.', isError: true); await _checkIfFavorited(); }
    } else { try { DocumentReference newFavoriteDocRef = await _firestore.collection('user_favorites').add({ 'userId': widget.currentUserId, 'contentId': widget.documentId, 'storyTitle': effectiveDisplayTitle, 'contentType': widget.title, 'synopsis': widget.synopsis ?? 'No synopsis provided.', 'favoritedAt': FieldValue.serverTimestamp(), }); if (mounted) { setState(() { _isFavorited = true; _favoriteDocId = newFavoriteDocRef.id; }); _showSnackBar('Added to Favorites!'); } } catch (e) { print("Error adding favorite: $e"); if (mounted) _showSnackBar('Could not add to Favorites. Please try again.', isError: true); } }
    if (mounted) { setState(() => _isLoadingFavoriteStatus = false); }
  }

  Future<void> _fetchAndIncrementViewCount() async { 
    DocumentReference storyDocRef = FirebaseFirestore.instance.collection('content').doc(widget.documentId);
    bool shouldIncrement = widget.initialIsPublic && (widget.currentUserId != widget.ownerUserId);
    try {
      DocumentSnapshot docSnapshot = await storyDocRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (mounted) { 
          setState(() { 
            _currentViewCount = data['viewCount'] as int? ?? 0; 
             // Also update upvote count if not already loading/loaded by its own function
            if (!_isLoadingUpvoteStatus && data.containsKey('upvoteCount')) {
                _currentUpvoteCount = data['upvoteCount'] as int? ?? 0;
            }
            _viewCountFetched = true; 
          }); 
        }
      } else {
         if (mounted) setState(() => _viewCountFetched = true);
      }
      if (shouldIncrement) {
        await storyDocRef.update({'viewCount': FieldValue.increment(1)});
        print('View count incremented for document: ${widget.documentId}');
        if (mounted && docSnapshot.exists) { setState(() { _currentViewCount++; }); }
      }
    } catch (e) {
      print('Error fetching/incrementing view count for ${widget.documentId}: $e');
      if (mounted && !_viewCountFetched) { setState(() => _viewCountFetched = true); }
    }
  }

  Future<void> _loadInitialUpvoteData() async {
    if (!mounted) return;
    setState(() => _isLoadingUpvoteStatus = true);
    DocumentReference storyDocRef = _firestore.collection('content').doc(widget.documentId);
    try {
      DocumentSnapshot contentSnapshot = await storyDocRef.get();
      if (contentSnapshot.exists && contentSnapshot.data() != null) {
        final data = contentSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentUpvoteCount = data['upvoteCount'] as int? ?? 0;
            // If view count also comes from this snapshot and hasn't been fetched by its dedicated method.
            if (!_viewCountFetched && data.containsKey('viewCount')) {
                _currentViewCount = data['viewCount'] as int? ?? 0;
                _viewCountFetched = true; // Mark as fetched via this route
            }
          });
        }
      }
      if (widget.currentUserId != null) {
        QuerySnapshot upvoteQuery = await _firestore.collection('user_story_upvotes').where('userId', isEqualTo: widget.currentUserId).where('contentId', isEqualTo: widget.documentId).limit(1).get();
        if (mounted) {
          if (upvoteQuery.docs.isNotEmpty) {
            _hasUpvoted = true;
            _upvoteDocId = upvoteQuery.docs.first.id;
          } else {
            _hasUpvoted = false;
            _upvoteDocId = null;
          }
        }
      }
    } catch (e) { print("Error loading initial upvote data: $e");
    } finally { if (mounted) { setState(() => _isLoadingUpvoteStatus = false); } }
  }

  Future<void> _toggleUpvote() async {
    if (widget.currentUserId == null) { _showSnackBar('Please log in to upvote stories.', isError: true); return; }
    if (_isLoadingUpvoteStatus) return;
    setState(() => _isLoadingUpvoteStatus = true);
    DocumentReference storyDocRef = _firestore.collection('content').doc(widget.documentId);
    CollectionReference userUpvotesRef = _firestore.collection('user_story_upvotes');
    WriteBatch batch = _firestore.batch();
    if (_hasUpvoted) { 
      if (_upvoteDocId != null) {
        batch.delete(userUpvotesRef.doc(_upvoteDocId));
        batch.update(storyDocRef, {'upvoteCount': FieldValue.increment(-1)});
        try { await batch.commit(); if (mounted) { setState(() { _hasUpvoted = false; _upvoteDocId = null; _currentUpvoteCount = (_currentUpvoteCount > 0) ? _currentUpvoteCount - 1 : 0; }); _showSnackBar('Upvote removed.'); }} catch (e) { print("Error removing upvote with batch: $e"); if (mounted) _showSnackBar('Could not remove upvote.', isError: true);}
      } else { if (mounted) _showSnackBar('Error: Upvote reference missing.', isError: true); await _loadInitialUpvoteData(); }
    } else { 
      try {
        DocumentReference newUpvoteRef = userUpvotesRef.doc(); 
        batch.set(newUpvoteRef, { 'userId': widget.currentUserId, 'contentId': widget.documentId, 'upvotedAt': FieldValue.serverTimestamp(),});
        batch.update(storyDocRef, {'upvoteCount': FieldValue.increment(1)});
        await batch.commit();
        if (mounted) { setState(() { _hasUpvoted = true; _upvoteDocId = newUpvoteRef.id; _currentUpvoteCount++; }); _showSnackBar('Story Upvoted!');}
      } catch (e) { print("Error adding upvote with batch: $e"); if (mounted) _showSnackBar('Could not upvote story.', isError: true); }
    }
    if (mounted) { setState(() => _isLoadingUpvoteStatus = false); }
  }

  @override
  void dispose() { 
    _audioPlayer.dispose();
    super.dispose(); // Ensure super.dispose() is called
  }
 
  Future<void> _requestAndPrepareAudio() async { 
    if (widget.fullText.isEmpty) { _showSnackBar('Nothing to synthesize!', isError: true); return; }
    if (!mounted) return;
    setState(() { _isRequestingAudio = true; _isAudioReady = false; _audioFilePath = null; });
    await _audioPlayer.stop();
    try {
      final String apiKey = elevenLabsApiKey; final String voiceId = _selectedElevenLabsVoiceId;
      final String ttsUrl = '$elevenLabsApiBaseUrl/text-to-speech/$voiceId';
      print('Requesting TTS from ElevenLabs for voice ID: $voiceId');
      final response = await http.post( Uri.parse(ttsUrl), headers: { 'Accept': 'audio/mpeg', 'Content-Type': 'application/json', 'xi-api-key': apiKey, }, body: jsonEncode({ 'text': widget.fullText, 'model_id': 'eleven_multilingual_v2', 'voice_settings': { 'stability': 0.5, 'similarity_boost': 0.75, } }), );
      if (response.statusCode == 200) {
        final Uint8List audioBytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final sanitizedDocId = widget.documentId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        _audioFilePath = '${tempDir.path}/tts_audio_${sanitizedDocId}_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final audioFile = File(_audioFilePath!); await audioFile.writeAsBytes(audioBytes);
        print('Audio saved to temporary file: $_audioFilePath');
        await _audioPlayer.setFilePath(_audioFilePath!); 
        if (mounted) { setState(() { _isAudioReady = true; }); }
      } else {
        print('ElevenLabs TTS API request failed: ${response.statusCode}'); print('Response Body: ${response.body}');
        if (mounted) _showSnackBar('Failed to generate audio (ElevenLabs): ${response.reasonPhrase} - ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error during ElevenLabs TTS request or audio processing: $e');
      if (mounted) _showSnackBar('Error generating audio: ${e.toString()}', isError: true);
    } finally {
      if (mounted) { setState(() { _isRequestingAudio = false; }); }
    }
  }
  
  Future<void> _updatePublicStatus(bool newStatus) async { 
    if (widget.currentUserId != widget.ownerUserId) { _showSnackBar('You can only change visibility of your own content.', isError: true); return; }
    try { await FirebaseFirestore.instance.collection('content').doc(widget.documentId).update({'isPublic': newStatus}); if (mounted) { setState(() => _isPublic = newStatus); _showSnackBar('Content visibility updated to ${newStatus ? "Public" : "Private"}'); }
    } catch (e) { if (mounted) _showSnackBar('Failed to update visibility: ${e.toString()}', isError: true); }
  }

  void _showSnackBar(String message, {bool isError = false}) { 
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent: null));
  }

  // This method IS used in build()
  Widget _buildInfoRow(String label, String value) { 
    if (value.isEmpty || value == 'No Persona' || value == "Not specified" || value == "null") return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 4.0), child: RichText(text: TextSpan(style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16.0), children: <TextSpan>[TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: value)])));
  }

  @override
  Widget build(BuildContext context) {
    String personaDisplay = widget.selectedPersona ?? "Not specified";
    if (personaDisplay == 'No Persona' || personaDisplay.isEmpty) personaDisplay = "Not specified";
    final bool isOwner = widget.currentUserId != null && widget.currentUserId == widget.ownerUserId;
    String appBarTitle = widget.storyTitle != null && widget.storyTitle!.isNotEmpty ? widget.storyTitle! : widget.title; 

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, overflow: TextOverflow.ellipsis), 
        centerTitle: true,
        actions: [
          // Upvote Button and Count
          if (widget.currentUserId != null && widget.initialIsPublic) 
            _isLoadingUpvoteStatus
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 12.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _hasUpvoted ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                        color: _hasUpvoted ? Theme.of(context).colorScheme.secondary : Colors.white, // Use white for outlined
                      ),
                      tooltip: _hasUpvoted ? 'Remove Upvote' : 'Upvote Story',
                      onPressed: _toggleUpvote,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6.0), 
                      child: Text(
                        _currentUpvoteCount.toString(), 
                        style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.normal)
                      ),
                    ),
                  ],
                ),
          
          // Favorite Button
          if (widget.currentUserId != null) 
            _isLoadingFavoriteStatus
              ? const Padding( padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5,)),)
              : IconButton( icon: Icon( _isFavorited ? Icons.star : Icons.star_border, color: _isFavorited ? Colors.amber : Colors.white,), tooltip: _isFavorited ? 'Remove from Favorites' : 'Add to Favorites', onPressed: _toggleFavoriteStatus,),
        ],
      ),
      body: SingleChildScrollView( 
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
             if (isOwner) ...[ SwitchListTile(title: const Text('Make this content public?'), subtitle: Text(_isPublic ? 'Visible to others.' : 'Only visible to you.'), value: _isPublic, onChanged: (bool newValue) => _updatePublicStatus(newValue), activeColor: Colors.teal), const SizedBox(height: 10.0), const Divider(),],
            if (widget.initialIsPublic) Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row( children: [ Icon(Icons.visibility_outlined, color: Colors.grey[700], size: 20), const SizedBox(width: 8.0), Text( _viewCountFetched ? '$_currentViewCount views' : 'Loading views...', style: TextStyle(fontSize: 15.0, color: Colors.grey[700]),), ],),),
            if (widget.initialIsPublic) const SizedBox(height: 8.0),
            if (widget.storyTitle != null && widget.storyTitle!.isNotEmpty && widget.storyTitle != widget.title) Padding( padding: const EdgeInsets.only(bottom: 12.0), child: Text( "A ${widget.title}", style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500, color: Colors.grey[800], fontStyle: FontStyle.italic), textAlign: TextAlign.start,),),
            const Text('Listen to this Story/Poem:', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            DropdownButtonFormField<String>( decoration: InputDecoration(labelText: 'Narrator Voice', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),), value: _selectedElevenLabsVoiceId, items: _elevenLabsVoices.entries.map((entry) => DropdownMenuItem<String>(value: entry.value, child: Text(entry.key))).toList(), onChanged: _isRequestingAudio || _isAudioReady ? null : (String? newValue) { if (newValue != null) { setState(() { _selectedElevenLabsVoiceId = newValue; _isAudioReady = false; _audioFilePath = null; _audioPlayer.stop(); }); } }, isExpanded: true,),
            const SizedBox(height: 8.0),
            if (_isRequestingAudio) const Center(child: Padding(padding: EdgeInsets.all(8.0), child:CircularProgressIndicator()))
            else if (!_isAudioReady) ElevatedButton.icon( icon: const Icon(Icons.volume_up), label: const Text('Request Audio Version'), onPressed: _requestAndPrepareAudio, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),)
            else Column( children: [ Row( mainAxisAlignment: MainAxisAlignment.center, children: [ IconButton(icon: Icon(_isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_filled), iconSize: 48.0, onPressed: () { if (_isPlayingAudio) _audioPlayer.pause(); else _audioPlayer.play(); }), IconButton(icon: const Icon(Icons.stop_circle_outlined), iconSize: 48.0, onPressed: () { _audioPlayer.stop(); _audioPlayer.seek(Duration.zero); if (mounted) setState(() => _isPlayingAudio = false); }), ], ), TextButton.icon( icon: const Icon(Icons.refresh, size: 20), label: const Text('Change Voice / Re-generate Audio'), onPressed: () { setState(() { _isAudioReady = false; _audioFilePath = null;}); }, ), ],),
            const SizedBox(height: 16.0), const Divider(),
            const SizedBox(height: 8.0),
            const Text('Influences:', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            if (widget.selectedThemes.isNotEmpty) _buildInfoRow('Themes', widget.selectedThemes.join(', ')),
            if (widget.selectedCharacters.isNotEmpty) _buildInfoRow('Characters', widget.selectedCharacters.join(', ')),
            _buildInfoRow('Persona', personaDisplay),
            _buildInfoRow('Length', widget.selectedLength),
            _buildInfoRow('Age Range', widget.selectedAgeRange ?? "Not specified"),
            if (widget.selectedLessons.isNotEmpty) _buildInfoRow('Lesson(s)', widget.selectedLessons.join(', ')),
            const SizedBox(height: 16.0), const Divider(),
            const SizedBox(height: 16.0),
            const Text('Full Content:', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            Text(widget.fullText, style: const TextStyle(fontSize: 16.0)),
          ],
        ),
      ),
    );
  }
}