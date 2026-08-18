import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// A reusable widget to render WebRTC video streams.
///
/// It handles the initialization and disposal of the [RTCVideoRenderer].
class WebRTCVideoView extends StatefulWidget {
  const WebRTCVideoView({
    super.key,
    required this.stream,
    this.mirror = false,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  });

  /// The media stream to render.
  final MediaStream? stream;

  /// Whether to mirror the video (typically true for local front camera).
  final bool mirror;

  /// How the video should be fitted into its bounds.
  final RTCVideoViewObjectFit objectFit;

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
    if (!_isInitialized || widget.stream == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return RTCVideoView(
      _renderer,
      mirror: widget.mirror,
      objectFit: widget.objectFit,
    );
  }
}
