import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/translation/models/translation_language.dart';
import 'package:transmeet/features/translation/models/translation_result.dart';

/// Low-latency real-time translation engine.
///
/// Listens for transcriptions from Firestore, translates them using the
/// Node.js backend (official Google Cloud Translation API), and synthesizes
/// speech using the Google TTS API via the backend.
///
/// Latency breakdown (logged per translation):
///   Firestore event: ~0.1–0.3s
///   Translation API: ~0.2–0.5s
///   Google TTS API:  ~0.3–0.6s
///   Total:           ~0.6–1.4s
///
/// Architecture:
/// ```
/// Remote speech → Firestore transcription
///       ↓
/// Backend /translate (Google Translate)
///       ↓
/// Backend /synthesize (Google TTS)
///       ↓
/// Played via just_audio
/// ```
class RealtimeTranslationEngine {
  RealtimeTranslationEngine({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final http.Client _httpClient;

  bool _isRunning = false;
  bool _isDisposed = false;
  bool _isSpeaking = false;

  StreamSubscription<QuerySnapshot>? _transcriptionSub;

  /// The user's preferred language code (e.g. "ta" for Tamil).
  String _targetLanguageCode = 'en';
  String _targetLanguageName = 'English';

  String get targetLanguageCode => _targetLanguageCode;
  String get targetLanguageName => _targetLanguageName;
  bool get isRunning => _isRunning;

  /// Update the target language dynamically.
  Future<void> changeTargetLanguage(String langCode) async {
    _targetLanguageCode = langCode;
    _targetLanguageName = TranslationLanguage.codeToName(langCode) ?? langCode;
    debugPrint('[TranslationEngine] Changed target language to $_targetLanguageName');
    
    // Persist to user profile if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'preferredLanguageCode': langCode,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[TranslationEngine] Failed to save preferred language: $e');
      }
    }
  }

  /// Queue of base64 audio segments to speak in order.
  final List<String> _speakQueue = [];

  /// Track processed document IDs to avoid duplicates.
  final Set<String> _processedDocIds = {};

  /// Track last translated text to avoid duplicate translations.
  String _lastTranslatedText = '';

  /// Monotonically increasing sequence number to prevent stale response
  /// overwrites. Each translation request gets the next sequence number.
  /// When a response arrives, it is discarded if its sequence is less than
  /// the sequence of the most recently emitted result.
  int _requestSequence = 0;
  int _lastEmittedSequence = 0;

  /// Emits translation results for caption display.
  final _resultController = StreamController<TranslationResult>.broadcast();
  Stream<TranslationResult> get onResult => _resultController.stream;

  /// Emits error messages.
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get onError => _errorController.stream;

  /// Emits status updates.
  final _statusController = StreamController<String>.broadcast();
  Stream<String> get onStatus => _statusController.stream;

  /// Emits when TTS playback starts/stops.
  final _speakingStateController = StreamController<bool>.broadcast();
  Stream<bool> get onSpeakingStateChanged => _speakingStateController.stream;

  void _setSpeaking(bool speaking) {
    if (_isSpeaking == speaking) return;
    _isSpeaking = speaking;
    if (!_isDisposed) _speakingStateController.add(speaking);
  }

  /// Whether TTS playback is enabled. If false, we skip synthesizing audio.
  bool enableTts = false;

  /// Backend base URL for translation API.
  String get _backendBaseUrl => AppConstants.backendBaseUrl;

  /// Starts listening for transcriptions and translating them.
  Future<void> start({
    required String meetingId,
    String? preferredLanguageCode,
  }) async {
    if (_isRunning || _isDisposed) return;

    await _loadPreferredLanguage(preferredLanguageCode);
    await _initTts();

    debugPrint(
        '[TranslationEngine] Starting — target: $_targetLanguageName ($_targetLanguageCode)');
    _isRunning = true;
    _processedDocIds.clear();
    _lastTranslatedText = '';
    _requestSequence = 0;
    _lastEmittedSequence = 0;
    _emitStatus('Listening for speech...');

    final myUid = FirebaseAuth.instance.currentUser?.uid;

    // Listen to transcriptions in real-time
    _transcriptionSub = _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('transcriptions')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final docId = change.doc.id;
        if (_processedDocIds.contains(docId)) continue;
        _processedDocIds.add(docId);

        final data = change.doc.data();
        if (data == null) continue;

        final speakerUid = data['speakerUid'] as String? ?? '';
        if (speakerUid == myUid) continue; // Skip own speech

        final text = data['text'] as String? ?? '';
        final detectedLanguage = data['detectedLanguage'] as String? ?? 'en';

        if (text.trim().isEmpty) continue;

        debugPrint('[TranslationEngine] Received: "$text" ($detectedLanguage)');
        _processTranscription(text: text, sourceLanguage: detectedLanguage);
      }
    }, onError: (e) {
      debugPrint('[TranslationEngine] Firestore error: $e');
      if (!_isDisposed) _errorController.add('Connection error: $e');
    });
  }

  /// Initialize audio player.
  Future<void> _initTts() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          usage: AndroidAudioUsage.voiceCommunication,
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: true,
      ));
      debugPrint('[TranslationEngine] AudioPlayer initialized for Google TTS');
    } catch (e) {
      debugPrint('[TranslationEngine] AudioPlayer init error: $e');
    }
  }

  /// Stops the engine.
  Future<void> stop() async {
    debugPrint('[TranslationEngine] Stopping');
    _isRunning = false;
    await _transcriptionSub?.cancel();
    _transcriptionSub = null;
    _speakQueue.clear();
    _processedDocIds.clear();
    _lastTranslatedText = '';
    await _audioPlayer.stop();
    _setSpeaking(false);
    _emitStatus('Translation paused');
  }

  /// Process a transcription through the translation pipeline.
  Future<void> _processTranscription({
    required String text,
    required String sourceLanguage,
  }) async {
    if (!_isRunning || _isDisposed) return;

    final trimmedText = text.trim();

    // Guard: empty/whitespace
    if (trimmedText.isEmpty) return;

    // Guard: exact duplicate of last translation
    if (trimmedText == _lastTranslatedText) {
      debugPrint('[TranslationEngine] Skipping duplicate: "$trimmedText"');
      return;
    }

    // Assign a sequence number for this request
    _requestSequence++;
    final mySequence = _requestSequence;

    final t1 = DateTime.now(); // T1: Speech segment captured

    try {
      String translatedText;

      if (TranslationLanguage.baseCode(sourceLanguage) == 
          TranslationLanguage.baseCode(_targetLanguageCode)) {
        translatedText = trimmedText;
        debugPrint('[TranslationEngine] Source == target, no translation needed');
      } else {
        _emitStatus('Translating...');

        // Use the backend API for translation — single direct call
        // No double-hop (source→en→target) needed; Google Translate handles
        // any language pair directly.
        final effectiveSource =
            sourceLanguage == 'auto' ? 'auto' : sourceLanguage;
        final t4 = DateTime.now(); // T4: Translation request sent
        translatedText = await _translateViaBackend(
          trimmedText,
          effectiveSource,
          _targetLanguageCode,
        );
        final t5 = DateTime.now(); // T5: Translation received

        final translationLatency = t5.difference(t4).inMilliseconds;
        debugPrint(
            '[TranslationEngine] Translation: ${translationLatency}ms'
            ' ($effectiveSource → $_targetLanguageCode)');
        debugPrint(
            '[TranslationEngine] → $_targetLanguageCode: "$translatedText"');
      }

      // Check if this response is stale (a newer request already completed)
      if (mySequence < _lastEmittedSequence) {
        debugPrint(
            '[TranslationEngine] Discarding stale response '
            '(seq $mySequence < $_lastEmittedSequence)');
        return;
      }
      _lastEmittedSequence = mySequence;
      _lastTranslatedText = trimmedText;

      // Emit caption for UI — immediately, don't wait for TTS
      if (!_isDisposed) {
        _resultController.add(TranslationResult.fromTranscriptionAndTranslation(
          originalText: trimmedText,
          translatedText: translatedText,
          sourceLanguage: sourceLanguage,
          targetLanguage: _targetLanguageCode,
        ));
      }

      // Call backend synthesize API
      if (enableTts) {
        _emitStatus('Synthesizing...');
        final audioContent = await _synthesizeViaBackend(translatedText, _targetLanguageCode);

        // Queue for TTS playback
        if (_isRunning && !_isDisposed && audioContent.isNotEmpty) {
          final t6 = DateTime.now(); // T6: TTS request sent
          _speakQueue.add(audioContent);
          _processQueue();

          final t7 = DateTime.now(); // T7: TTS queued
          final ttsStartup = t7.difference(t6).inMilliseconds;
          final totalLatency = t7.difference(t1).inMilliseconds;

          debugPrint('[Translation Latency]');
          debugPrint('  Total end-to-end: ${totalLatency}ms');
          debugPrint('  TTS startup (network): ${ttsStartup}ms');
        }
      }

      _emitStatus('Listening for speech...');
    } catch (e) {
      debugPrint('[TranslationEngine] Pipeline error: $e');
      if (!_isDisposed) {
        _errorController.add(e.toString());
        _emitStatus('Error — retrying...');
        // Recover: reset status after delay so next sentence can be processed
        Future.delayed(const Duration(seconds: 2), () {
          if (_isRunning && !_isDisposed) {
            _emitStatus('Listening for speech...');
          }
        });
      }
    }
  }

  /// Translates text using the Node.js backend (official Google Cloud
  /// Translation API). API keys stay on the server.
  ///
  /// Includes 2 automatic retries with a 1-second backoff for transient
  /// network/timeout failures. The 45-second timeout accommodates the
  /// Google Translate API cold-start which can take 15–20s.
  Future<String> _translateViaBackend(
      String text, String from, String to) async {
    const maxAttempts = 3;
    const retryDelay = Duration(seconds: 1);
    const requestTimeout = Duration(seconds: 45);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _translateViaBackendSingle(
            text, from, to, requestTimeout);
      } on TimeoutException {
        debugPrint('[TranslationEngine] Timeout on attempt $attempt/$maxAttempts');
        if (attempt == maxAttempts) {
          throw 'Connection slow — translation timed out. Please check your network.';
        }
        await Future.delayed(retryDelay);
      } on SocketException catch (e) {
        debugPrint('[TranslationEngine] Network error on attempt $attempt/$maxAttempts: $e');
        if (attempt == maxAttempts) {
          throw 'Network error — cannot reach translation server.';
        }
        await Future.delayed(retryDelay);
      } on http.ClientException catch (e) {
        debugPrint('[TranslationEngine] Client error on attempt $attempt/$maxAttempts: $e');
        if (attempt == maxAttempts) {
          throw 'Network error — cannot reach translation server.';
        }
        await Future.delayed(retryDelay);
      }
    }
    // Unreachable, but satisfies the compiler.
    throw 'Translation failed after $maxAttempts attempts.';
  }

  /// Single translation attempt.
  Future<String> _translateViaBackendSingle(
      String text, String from, String to, Duration timeout) async {
    final safeFrom = TranslationLanguage.nameToCode(from) ?? from;
    final safeTo = TranslationLanguage.nameToCode(to) ?? to;

    final url = Uri.parse('$_backendBaseUrl/api/translation/translate');

    final response = await _httpClient
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'text': text,
            'sourceLanguage': safeFrom == 'auto' ? 'auto' : TranslationLanguage.baseCode(safeFrom),
            'targetLanguage': TranslationLanguage.baseCode(safeTo),
          }),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final translatedText = data['translatedText'] as String?;
      if (translatedText != null && translatedText.isNotEmpty) {
        return translatedText;
      }
      throw 'Translation returned empty result';
    }

    // Structured error logging
    String errorMessage;
    try {
      final errorBody = json.decode(response.body) as Map<String, dynamic>;
      errorMessage = errorBody['error'] as String? ?? 'Unknown error';
    } catch (_) {
      errorMessage = 'Server error';
    }

    debugPrint('[TranslationError]');
    debugPrint('  status: ${response.statusCode}');
    debugPrint('  endpoint: $url');
    debugPrint('  sourceLanguage: $from');
    debugPrint('  targetLanguage: $to');
    debugPrint('  error: $errorMessage');

    switch (response.statusCode) {
      case 400:
        throw 'Invalid request: $errorMessage';
      case 401:
      case 403:
        throw 'Authentication error. Check API configuration.';
      case 404:
        throw 'Translation endpoint not found. Check backend URL.';
      case 429:
        throw 'Rate limit exceeded. Please wait a moment.';
      case 503:
        throw 'Translation service unavailable. $errorMessage';
      default:
        throw 'Translation failed (${response.statusCode}): $errorMessage';
    }
  }

  /// Synthesize text to speech via backend
  Future<String> _synthesizeViaBackend(String text, String to) async {
    try {
      final safeTo = TranslationLanguage.nameToCode(to) ?? to;
      final url = Uri.parse('$_backendBaseUrl/api/translation/synthesize');
      final response = await _httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'languageCode': safeTo,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['audioContent'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('[TranslationEngine] Synthesize error: $e');
    }
    return '';
  }

  /// Process the TTS speak queue sequentially.
  Future<void> _processQueue() async {
    if (_isSpeaking || _isDisposed || !_isRunning) {
      return;
    }
    _setSpeaking(true);

    while (_speakQueue.isNotEmpty && !_isDisposed && _isRunning) {
      final base64Audio = _speakQueue.removeAt(0);

      try {
        final bytes = base64Decode(base64Audio);
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/tts_output_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await tempFile.writeAsBytes(bytes);

        await _audioPlayer.setFilePath(tempFile.path);
        
        _audioPlayer.play();
        
        // Wait until playback finishes
        await _audioPlayer.processingStateStream.firstWhere(
            (state) => state == ProcessingState.completed);
            
        // Ensure player is stopped before loading the next file
        await _audioPlayer.stop();
        await _audioPlayer.seek(Duration.zero);
        
        // Small gap between sentences to make it sound natural
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('[TranslationEngine] Audio playback error: $e');
        // Wait a bit on error before trying the next one to avoid rapid crash loops
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    _setSpeaking(false);
  }

  /// Load the user's preferred language.
  Future<void> _loadPreferredLanguage(String? overrideCode) async {
    if (overrideCode != null && overrideCode.isNotEmpty) {
      _targetLanguageCode = overrideCode;
      _targetLanguageName =
          TranslationLanguage.codeToName(overrideCode) ?? overrideCode;
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        final langCode = data?['preferredLanguageCode'] as String? ?? 'en';
        _targetLanguageCode = langCode;
        _targetLanguageName =
            TranslationLanguage.codeToName(langCode) ?? langCode;
      }
    } catch (e) {
      debugPrint('[TranslationEngine] Language load error: $e');
    }
  }

  void _emitStatus(String status) {
    if (!_isDisposed) _statusController.add(status);
  }

  /// Releases all resources.
  Future<void> dispose() async {
    _isDisposed = true;
    _isRunning = false;
    await _transcriptionSub?.cancel();
    _transcriptionSub = null;
    _speakQueue.clear();
    _processedDocIds.clear();
    _lastTranslatedText = '';
    await _audioPlayer.dispose();
    _httpClient.close();
    await _resultController.close();
    await _errorController.close();
    await _statusController.close();
    await _speakingStateController.close();
  }
}
