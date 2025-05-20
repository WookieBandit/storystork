// lib/content_detail_screen.dart - v1.3 (ElevenLabs TTS Integration)
import 'dart:convert'; // For jsonEncode (though API returns bytes directly)
import 'dart:io';     // For File and Platform
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart'; // For _updatePublicStatus
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'api_config.dart'; // For ElevenLabs API Key and Base URL

class ContentDetailScreen extends StatefulWidget {
  final String documentId;
  final String title;
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
  
  // States for TTS and audio playback
  bool _isRequestingAudio = false;
  bool _isAudioReady = false;
  bool _isPlayingAudio = false;
  String? _audioFilePath;

  // --- ElevenLabs Voice Selection ---
  final Map<String, String> _elevenLabsVoices = {
    'Rachel (Female Narrator)': '21m00Tcm4TlvDq8ikWAM',
    'Adam (Male Narrator)': 'pNInz6obpgDQGcFmaJgB',
    // Add your custom voice IDs here later, e.g.:
    // 'Your Voice (Male)': 'YOUR_CUSTOM_MALE_VOICE_ID',
    // 'Your Wife\'s Voice (Female)': 'YOUR_CUSTOM_FEMALE_VOICE_ID',
  };
  late String _selectedElevenLabsVoiceId;
  // --- End of ElevenLabs Voice Selection ---

  @override
  void initState() {
    super.initState();
    _isPublic = widget.initialIsPublic;
    _selectedElevenLabsVoiceId = _elevenLabsVoices.values.first; // Default to first voice (Rachel)

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
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Method to call ElevenLabs TTS API and prepare audio
  Future<void> _requestAndPrepareAudio() async {
    if (widget.fullText.isEmpty) {
      _showSnackBar('Nothing to synthesize!', isError: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _isRequestingAudio = true;
      _isAudioReady = false; 
      _audioFilePath = null; // Reset previous audio file path
    });

    // Stop any currently playing audio before fetching new
    await _audioPlayer.stop();

    try {
      final String apiKey = elevenLabsApiKey; // From api_config.dart
      final String voiceId = _selectedElevenLabsVoiceId;
      final String ttsUrl = '$elevenLabsApiBaseUrl/text-to-speech/$voiceId';
      
      print('Requesting TTS from ElevenLabs for voice ID: $voiceId');

      final response = await http.post(
        Uri.parse(ttsUrl),
        headers: {
          'Accept': 'audio/mpeg', // Request MP3 audio
          'Content-Type': 'application/json',
          'xi-api-key': apiKey,
        },
        body: jsonEncode({
          'text': widget.fullText,
          'model_id': 'eleven_multilingual_v2', // Or another suitable model
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
            // 'style': 0.0, // Set to a value > 0 for Style Exaggeration if using v2 models that support it
            // 'use_speaker_boost': true, // For v2 models
          }
        }),
      );

      if (response.statusCode == 200) {
        final Uint8List audioBytes = response.bodyBytes; // ElevenLabs returns raw audio bytes

        final tempDir = await getTemporaryDirectory();
        final sanitizedDocId = widget.documentId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        _audioFilePath = '${tempDir.path}/tts_audio_${sanitizedDocId}_${DateTime.now().millisecondsSinceEpoch}.mp3'; // Ensure unique filename
        
        final audioFile = File(_audioFilePath!);
        await audioFile.writeAsBytes(audioBytes);
        print('Audio saved to temporary file: $_audioFilePath');

        await _audioPlayer.setFilePath(_audioFilePath!); 

        if (mounted) {
          setState(() {
            _isAudioReady = true;
          });
          // Optionally auto-play, or let user press play
          // _audioPlayer.play(); 
        }
      } else {
        print('ElevenLabs TTS API request failed: ${response.statusCode}');
        print('Response Body: ${response.body}'); // Print error details from ElevenLabs
        if (mounted) _showSnackBar('Failed to generate audio (ElevenLabs): ${response.reasonPhrase} - ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error during ElevenLabs TTS request or audio processing: $e');
      if (mounted) _showSnackBar('Error generating audio: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingAudio = false;
        });
      }
    }
  }
  
  // Method to update public status in Firestore
  Future<void> _updatePublicStatus(bool newStatus) async {
    // ... (This method remains the same)
    if (widget.currentUserId != widget.ownerUserId) { _showSnackBar('You can only change visibility of your own content.', isError: true); return; }
    try { await FirebaseFirestore.instance.collection('content').doc(widget.documentId).update({'isPublic': newStatus}); if (mounted) { setState(() => _isPublic = newStatus); _showSnackBar('Content visibility updated to ${newStatus ? "Public" : "Private"}'); }
    } catch (e) { if (mounted) _showSnackBar('Failed to update visibility: ${e.toString()}', isError: true); }
  }

  // Helper for SnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.redAccent: null));
  }

  // Helper to build info rows for influences
  Widget _buildInfoRow(String label, String value) {
    // ... (This method remains the same)
    if (value.isEmpty || value == 'No Persona' || value == "Not specified" || value == "null") return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 4.0), child: RichText(text: TextSpan(style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16.0), children: <TextSpan>[TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: value)])));
  }

  @override
  Widget build(BuildContext context) {
    String personaDisplay = widget.selectedPersona ?? "Not specified";
    if (personaDisplay == 'No Persona' || personaDisplay.isEmpty) personaDisplay = "Not specified";
    final bool isOwner = widget.currentUserId != null && widget.currentUserId == widget.ownerUserId;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Section: "Make Public" toggle (only for owner)
            if (isOwner) ...[ /* ... SwitchListTile and Divider ... */ 
              SwitchListTile(title: const Text('Make this content public?'), subtitle: Text(_isPublic ? 'Visible to others.' : 'Only visible to you.'), value: _isPublic, onChanged: (bool newValue) => _updatePublicStatus(newValue), activeColor: Colors.blue),
              const SizedBox(height: 10.0), const Divider(),
            ],
            
            // Section: Audio Playback
            const SizedBox(height: 8.0),
            const Text('Listen to this Story/Poem:', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),

            // --- NEW: Voice Selection Dropdown ---
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Narrator Voice',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              ),
              value: _selectedElevenLabsVoiceId,
              items: _elevenLabsVoices.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.value, // The Voice ID
                  child: Text(entry.key), // The display name (e.g., "Rachel (Female)")
                );
              }).toList(),
              onChanged: _isRequestingAudio || _isAudioReady ? null : (String? newValue) { // Disable if audio loading or ready
                if (newValue != null) {
                  setState(() {
                    _selectedElevenLabsVoiceId = newValue;
                    _isAudioReady = false; // Reset audio ready state if voice changes
                    _audioFilePath = null; // Clear old audio file path
                    _audioPlayer.stop(); // Stop any playing audio
                  });
                }
              },
              isExpanded: true,
            ),
            const SizedBox(height: 8.0),
            // --- END OF Voice Selection Dropdown ---

            if (_isRequestingAudio)
              const Center(child: Padding(padding: EdgeInsets.all(8.0), child:CircularProgressIndicator()))
            else if (!_isAudioReady)
              ElevatedButton.icon(
                icon: const Icon(Icons.volume_up),
                label: const Text('Request Audio Version'),
                onPressed: _requestAndPrepareAudio, // Calls the updated method
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              )
            else // Audio is ready, show player controls
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(icon: Icon(_isPlayingAudio ? Icons.pause_circle_filled : Icons.play_circle_filled), iconSize: 48.0, onPressed: () { if (_isPlayingAudio) _audioPlayer.pause(); else _audioPlayer.play(); }),
                      IconButton(icon: const Icon(Icons.stop_circle_outlined), iconSize: 48.0, onPressed: () { _audioPlayer.stop(); _audioPlayer.seek(Duration.zero); if (mounted) setState(() => _isPlayingAudio = false); }),
                    ],
                  ),
                  TextButton.icon( // Button to re-request/refresh audio
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Change Voice / Re-generate Audio'),
                    onPressed: () {
                       setState(() {
                         _isAudioReady = false; // Allow voice change and re-request
                         _audioFilePath = null;
                       });
                    },
                  ),
                ],
              ),
            const SizedBox(height: 16.0), const Divider(),

            // Section: Influences
            // ... (This section remains the same, displaying themes, characters, etc.)
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
            
            // Section: Full Content
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