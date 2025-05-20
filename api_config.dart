// api_config.dart

// !!! WARNING: Storing API keys directly in client-side code is NOT secure for production.
// This file is for development and testing purposes only.
// See Phase 8 of the development plan for production security considerations.

// For Google AI (Content Generation)
const String googleAiApiKey = 'AIzaSyAwgo1wquqKL46uegs_V_9_9iv74bReguI'; // Replace with your actual API Key
const String googleAiApiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent'; // Replace with your actual API Endpoint URL

// --- For ElevenLabs Text-to-Speech (Audio Playback) ---
const String elevenLabsApiKey = 'sk_aa9587db0279d25347c8096a776c02a037311ca4accb2ec6'; // Replace with your new, secure key
const String elevenLabsApiBaseUrl = 'https://api.elevenlabs.io/v1'; 

// For Google Cloud Text-to-Speech (Audio Playback)
//const String googleCloudTtsApiKeyAndroid = 'AIzaSyDnwVWwQpdUfkJzPYgZ4guZtjYBcL6ZQQ4';
//const String googleCloudTtsApiKeyIOS = 'AIzaSyAa12b0zR5WYPu7wDAWNoD4ksJFsd0kTyU';
//const String googleCloudTtsApiEndpoint = 'https://texttospeech.googleapis.com/v1/text:synthesize'; // Endpoint is the same for both