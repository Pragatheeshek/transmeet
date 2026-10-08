import 'dart:async';

import 'package:flutter/material.dart';

import 'package:transmeet/features/translation/models/translation_result.dart';
import 'package:transmeet/features/translation/services/audio_capture_service.dart';
import 'package:transmeet/features/translation/services/realtime_translation_engine.dart';

/// Automatic translation overlay for the meeting screen.
///
/// When enabled, this widget:
/// 1. Starts the [AudioCaptureService] to continuously capture and broadcast
///    the local user's speech as transcriptions via Firestore.
/// 2. Starts the [RealtimeTranslationEngine] to listen for remote
///    transcriptions, translate them, synthesize TTS, and play them.
/// 3. Displays real-time captions showing original and translated text.
/// 4. Calls [onMuteRemoteAudio] to mute/unmute the WebRTC remote audio track.
class TranslationOverlay extends StatefulWidget {
  const TranslationOverlay({
    super.key,
    required this.isEnabled,
    required this.meetingDocId,
    required this.onMuteRemoteAudio,
  });

  /// Whether translation is currently enabled.
  final bool isEnabled;

  /// Firestore document ID of the current meeting.
  final String meetingDocId;

  /// Callback to mute/unmute the remote WebRTC audio track.
  final ValueChanged<bool> onMuteRemoteAudio;

  @override
  State<TranslationOverlay> createState() => _TranslationOverlayState();
}

class _TranslationOverlayState extends State<TranslationOverlay>
    with SingleTickerProviderStateMixin {
  AudioCaptureService? _captureService;
  RealtimeTranslationEngine? _translationEngine;

  final List<TranslationResult> _captions = [];
  String _statusText = 'Initializing...';
  String? _errorMessage;
  bool _servicesRunning = false;

  StreamSubscription<TranslationResult>? _resultSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<String>? _captureErrorSub;

  /// Timer to auto-dismiss error banners after a few seconds.
  Timer? _errorDismissTimer;

  late final AnimationController _pulseController;

  static const int _maxCaptions = 5;

  /// How long to show error banners before auto-dismissing.
  static const Duration _errorDisplayDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    if (widget.isEnabled) {
      _startServices(); // async — intentionally not awaited; runs in background.
    }
  }

  @override
  void didUpdateWidget(covariant TranslationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _startServices(); // async — intentionally not awaited; runs in background.
    } else if (!widget.isEnabled && oldWidget.isEnabled) {
      _stopServices();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _errorDismissTimer?.cancel();
    _stopServices();
    super.dispose();
  }

  /// Sets an error message that auto-dismisses after [_errorDisplayDuration].
  void _showError(String message) {
    if (!mounted) return;

    // Make error messages more user-friendly
    final friendlyMessage = _friendlyError(message);

    _errorDismissTimer?.cancel();
    setState(() => _errorMessage = friendlyMessage);

    _errorDismissTimer = Timer(_errorDisplayDuration, () {
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    });
  }

  /// Converts raw error strings into user-friendly messages.
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Connection slow — retrying...';
    }
    if (lower.contains('socketexception') || lower.contains('network error')) {
      return 'Network error — check your connection';
    }
    if (lower.contains('connection refused') ||
        lower.contains('cannot reach')) {
      return 'Translation server unreachable';
    }
    // Already friendly
    return raw;
  }

  /// Starts both the capture and translation services.
  ///
  /// This is async so that:
  /// 1. Subscriptions are registered BEFORE the async work begins (prevents
  ///    the race where health-check errors fire before listeners are attached).
  /// 2. The translation engine is fully initialised (language loaded from
  ///    Firestore) before the Firestore transcription listener starts.
  Future<void> _startServices() async {
    if (_servicesRunning) return;
    _servicesRunning = true;

    debugPrint('[TranslationOverlay] Starting translation services');

    // Mute remote audio so the user only hears TTS instead of raw remote audio.
    widget.onMuteRemoteAudio(true);

    if (mounted) {
      setState(() => _statusText = 'Starting speech capture...');
    }

    // ── Sender-side: capture local speech ──────────────────────────────────
    // Subscribe BEFORE calling start() to avoid the race where the
    // health-check error fires before _captureErrorSub is registered.
    _captureService = AudioCaptureService();
    _captureErrorSub = _captureService!.onError.listen((error) {
      debugPrint('[TranslationOverlay] Capture error: $error');
      _showError('Capture: $error');
    });

    // Fire-and-forget — the loop runs independently from here.
    // Do NOT await this; it runs forever until stop() is called.
    _captureService!.start(meetingId: widget.meetingDocId);

    // ── Receiver-side: translate remote speech ─────────────────────────────
    _translationEngine = RealtimeTranslationEngine();

    // Wire up result/error/status listeners before awaiting start(),
    // so no events are missed during the async initialisation.
    _resultSub = _translationEngine!.onResult.listen((result) {
      if (mounted) {
        setState(() {
          _captions.add(result);
          if (_captions.length > _maxCaptions) {
            _captions.removeAt(0);
          }
          // Clear any error on successful translation.
          _errorDismissTimer?.cancel();
          _errorMessage = null;
        });
      }
    });

    _errorSub = _translationEngine!.onError.listen((error) {
      debugPrint('[TranslationOverlay] Translation error: $error');
      _showError(error);
    });

    _statusSub = _translationEngine!.onStatus.listen((status) {
      if (mounted) setState(() => _statusText = status);
    });

    // Await engine start so the preferred language is loaded from Firestore
    // and the Firestore listener is registered before we return.
    await _translationEngine!.start(meetingId: widget.meetingDocId);

    if (mounted) {
      setState(() => _statusText = 'Listening for speech...');
    }
  }

  /// Stops both services and unmutes remote audio.
  void _stopServices() {
    if (!_servicesRunning) return;
    _servicesRunning = false;

    debugPrint('[TranslationOverlay] Stopping translation services');

    // Unmute remote audio — restore the original WebRTC audio.
    widget.onMuteRemoteAudio(false);

    _errorDismissTimer?.cancel();

    _resultSub?.cancel();
    _resultSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _statusSub?.cancel();
    _statusSub = null;
    _captureErrorSub?.cancel();
    _captureErrorSub = null;

    // Stop and dispose synchronously (stop is sync; dispose is fire-and-forget).
    _captureService?.stop();
    final captureToDispose = _captureService;
    _captureService = null;
    captureToDispose?.dispose(); // Future ignored — safe, it just closes streams.

    final engineToStop = _translationEngine;
    _translationEngine = null;
    engineToStop?.stop();
    engineToStop?.dispose(); // Future ignored — safe, it just closes streams.

    if (mounted) {
      setState(() => _captions.clear());
    } else {
      _captions.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xDD0A0A18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: status bar ───────────────────────────────────────────
          _buildStatusBar(),

          // ── Error message ───────────────────────────────────────────────
          if (_errorMessage != null) ...[
            const SizedBox(height: 6),
            _buildErrorBanner(),
          ],

          // ── Captions ────────────────────────────────────────────────────
          if (_captions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._captions.map(_buildCaptionTile),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final targetLang = _translationEngine?.targetLanguageName ?? 'Loading...';

    return Row(
      children: [
        // Pulsing dot
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, _) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.cyanAccent
                  .withValues(alpha: 0.5 + _pulseController.value * 0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Status text
        Expanded(
          child: Text(
            _statusText,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Target language badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded,
                  color: Colors.cyanAccent, size: 12),
              const SizedBox(width: 4),
              Text(
                targetLang,
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.redAccent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionTile(TranslationResult result) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original text (dimmed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_langFlag(result.sourceLanguage)} ',
                style: const TextStyle(fontSize: 11),
              ),
              Expanded(
                child: Text(
                  result.originalText,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Translated text (bright)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_langFlag(result.targetLanguage)} ',
                style: const TextStyle(fontSize: 11),
              ),
              Expanded(
                child: Text(
                  result.translatedText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Returns a flag emoji for a language code.
  String _langFlag(String code) {
    switch (code) {
      case 'en':
        return '🇬🇧';
      case 'hi':
        return '🇮🇳';
      case 'ta':
        return '🇮🇳';
      case 'te':
        return '🇮🇳';
      case 'ml':
        return '🇮🇳';
      case 'kn':
        return '🇮🇳';
      case 'es':
        return '🇪🇸';
      case 'fr':
        return '🇫🇷';
      case 'de':
        return '🇩🇪';
      case 'ja':
        return '🇯🇵';
      default:
        return '🌐';
    }
  }
}
