import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// A reusable widget to render WebRTC video streams.
///
/// Handles initialization and disposal of [RTCVideoRenderer].
/// Shows a clean avatar placeholder (instead of a spinner) when the
/// stream is not yet available — prevents the black/blank screen issue.
class WebRTCVideoView extends StatefulWidget {
  const WebRTCVideoView({
    super.key,
    required this.stream,
    this.mirror = false,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    this.placeholderLabel,
  });

  /// The media stream to render.
  final MediaStream? stream;

  /// Whether to mirror the video (typically true for local front camera).
  final bool mirror;

  /// How the video should be fitted into its bounds.
  final RTCVideoViewObjectFit objectFit;

  /// Optional label shown in the placeholder (e.g. participant name initial).
  final String? placeholderLabel;

  @override
  State<WebRTCVideoView> createState() => _WebRTCVideoViewState();
}

class _WebRTCVideoViewState extends State<WebRTCVideoView> {
  final _renderer = RTCVideoRenderer();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    await _renderer.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
        _renderer.srcObject = widget.stream;
      });
    }
  }

  @override
  void didUpdateWidget(covariant WebRTCVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update renderer whenever the stream reference changes.
    if (widget.stream != oldWidget.stream && _isInitialized) {
      setState(() {
        _renderer.srcObject = widget.stream;
      });
    }
  }

  @override
  void dispose() {
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show video only when renderer is ready AND a stream is present.
    if (_isInitialized && widget.stream != null) {
      return RTCVideoView(
        _renderer,
        mirror: widget.mirror,
        objectFit: widget.objectFit,
      );
    }

    // Clean avatar placeholder — no black screen, no spinning indicator.
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.grey[700],
              child: Text(
                widget.placeholderLabel?.isNotEmpty == true
                    ? widget.placeholderLabel![0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.stream == null) ...[
              const SizedBox(height: 12),
              Text(
                widget.placeholderLabel != null
                    ? 'Camera off'
                    : 'Waiting for video...',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
