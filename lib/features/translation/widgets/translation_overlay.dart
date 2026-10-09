import 'dart:async';

import 'package:flutter/material.dart';

import 'package:transmeet/features/translation/models/translation_language.dart';
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
    required this.isCaptionsEnabled,
    required this.isTtsEnabled,
    required this.meetingDocId,
    required this.onMuteRemoteAudio,
    required this.onCaptionReceived,
  });

  /// Whether captions should be passed to the listener.
  final bool isCaptionsEnabled;

  /// Whether translated TTS voice should be played.
  final bool isTtsEnabled;

  /// Callback when a new translation caption is ready.
  final void Function(String speaker, String text) onCaptionReceived;

  /// Firestore document ID of the current meeting.
  final String meetingDocId;

  /// Callback to mute/unmute the remote WebRTC audio track.
  final ValueChanged<bool> onMuteRemoteAudio;

  @override
  State<TranslationOverlay> createState() => _TranslationOverlayState();
}

class _TranslationOverlayState extends State<TranslationOverlay>
    with SingleTickerProviderStateMixin {
  RealtimeTranslationEngine? _translationEngine;
  String _statusText = 'Initializing...';
  String? _errorMessage;
  bool _servicesRunning = false;

  StreamSubscription<TranslationResult>? _resultSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<bool>? _speakingStateSub;

  /// Timer to auto-dismiss error banners after a few seconds.
  Timer? _errorDismissTimer;

  late final AnimationController _pulseController;
  final ScrollController _scrollController = ScrollController();

  /// How long to show error banners before auto-dismissing.
  static const Duration _errorDisplayDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    if (widget.isCaptionsEnabled || widget.isTtsEnabled) {
      _startServices(); // async — intentionally not awaited; runs in background.
    }
  }

  @override
  void didUpdateWidget(covariant TranslationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasEnabled = oldWidget.isCaptionsEnabled || oldWidget.isTtsEnabled;
    final isEnabled = widget.isCaptionsEnabled || widget.isTtsEnabled;

    if (isEnabled && !wasEnabled) {
      _startServices();
    } else if (!isEnabled && wasEnabled) {
      _stopServices();
    }

    if (_translationEngine != null) {
      _translationEngine!.enableTts = widget.isTtsEnabled;
      widget.onMuteRemoteAudio(widget.isTtsEnabled);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
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

    // Mute remote audio if TTS is enabled, otherwise let original audio play
    widget.onMuteRemoteAudio(widget.isTtsEnabled);

    if (mounted) {
      setState(() => _statusText = 'Starting translation engine...');
    }

    // ── Receiver-side: translate remote speech ─────────────────────────────
    _translationEngine = RealtimeTranslationEngine();
    _translationEngine!.enableTts = widget.isTtsEnabled;

    // Wire up result/error/status listeners before awaiting start(),
    // so no events are missed during the async initialisation.
    _resultSub = _translationEngine!.onResult.listen((result) {
      if (mounted) {
        if (widget.isCaptionsEnabled) {
          widget.onCaptionReceived(
            'Remote',
            result.translatedText,
          );
        }
        setState(() {
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

    _speakingStateSub = _translationEngine!.onSpeakingStateChanged.listen((isSpeaking) {
      // We don't pause capture service here anymore since it's managed externally.
    });

    // Await engine start so the preferred language is loaded from Firestore
    // and the Firestore listener is registered before we return.
    await _translationEngine!.start(meetingId: widget.meetingDocId);

    if (mounted) {
      setState(() => _statusText = 'Listening for speech...');
    }
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Target Language',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: TranslationLanguage.supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = TranslationLanguage.supportedLanguages[index];
                    final isSelected = lang.code == _translationEngine?.targetLanguageCode;
                    return ListTile(
                      title: Text(lang.name),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        if (_translationEngine != null) {
                          _translationEngine!.changeTargetLanguage(lang.code);
                          setState(() {}); // Update the badge
                        }
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
    _speakingStateSub?.cancel();
    _speakingStateSub = null;

    widget.onMuteRemoteAudio(false);

    final engineToStop = _translationEngine;
    _translationEngine = null;
    engineToStop?.stop();
    engineToStop?.dispose(); // Future ignored — safe, it just closes streams.
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCaptionsEnabled && !widget.isTtsEnabled) return const SizedBox.shrink();

    return Flexible(
      child: Container(
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
          ],
        ),
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
        InkWell(
          onTap: _showLanguagePicker,
          borderRadius: BorderRadius.circular(8),
          child: Container(
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
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down_rounded,
                    color: Colors.cyanAccent, size: 14),
              ],
            ),
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

}
