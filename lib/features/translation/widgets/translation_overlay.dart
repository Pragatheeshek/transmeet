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

  late final AnimationController _pulseController;

  static const int _maxCaptions = 5;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    if (widget.isEnabled) {
      _startServices();
    }
  }

  @override
  void didUpdateWidget(covariant TranslationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnabled && !oldWidget.isEnabled) {
      _startServices();
    } else if (!widget.isEnabled && oldWidget.isEnabled) {
      _stopServices();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopServices();
    super.dispose();
  }

  /// Starts both the capture and translation services.
  void _startServices() {
    if (_servicesRunning) return;
    _servicesRunning = true;

    debugPrint('[TranslationOverlay] Starting translation services');

    // Mute remote audio so user only hears TTS
    widget.onMuteRemoteAudio(true);

    // Start sender-side capture
    _captureService = AudioCaptureService();
    _captureService!.start(meetingId: widget.meetingDocId);
    _captureErrorSub = _captureService!.onError.listen((error) {
      if (mounted) {
        setState(() => _errorMessage = 'Capture: $error');
      }
    });

    // Start receiver-side translation engine
    _translationEngine = RealtimeTranslationEngine();
    _translationEngine!.start(meetingId: widget.meetingDocId);

    _resultSub = _translationEngine!.onResult.listen((result) {
      if (mounted) {
        setState(() {
          _captions.add(result);
          if (_captions.length > _maxCaptions) {
            _captions.removeAt(0);
          }
          _errorMessage = null;
        });
      }
    });

    _errorSub = _translationEngine!.onError.listen((error) {
      if (mounted) {
        setState(() => _errorMessage = error);
      }
    });

    _statusSub = _translationEngine!.onStatus.listen((status) {
      if (mounted) {
        setState(() => _statusText = status);
      }
    });

    if (mounted) {
      setState(() => _statusText = 'Listening for speech...');
    }
  }

  /// Stops both services and unmutes remote audio.
  void _stopServices() {
    if (!_servicesRunning) return;
    _servicesRunning = false;

    debugPrint('[TranslationOverlay] Stopping translation services');

    // Unmute remote audio
    widget.onMuteRemoteAudio(false);

    _resultSub?.cancel();
    _resultSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _statusSub?.cancel();
    _statusSub = null;
    _captureErrorSub?.cancel();
    _captureErrorSub = null;

    _captureService?.stop();
    _captureService?.dispose();
    _captureService = null;

    _translationEngine?.stop();
    _translationEngine?.dispose();
    _translationEngine = null;

    _captions.clear();
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
