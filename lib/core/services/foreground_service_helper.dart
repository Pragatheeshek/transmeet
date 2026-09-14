import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Helper to communicate with Android's native MeetingForegroundService.
/// Keeps VoIP meetings and screen sharing sessions alive when the app is
/// backgrounded or minimized.
class ForegroundServiceHelper {
  static const MethodChannel _channel =
      MethodChannel('com.transmeet/foreground_service');

  /// Starts the foreground service for an active meeting call.
  static Future<void> startCall({
    String title = 'TransMeet',
    String text = 'Meeting in progress',
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startCall', {
        'title': title,
        'text': text,
      });
      debugPrint('[ForegroundService] Started call service');
    } catch (e) {
      debugPrint('[ForegroundService] Failed to start call service: $e');
    }
  }

  /// Upgrades the foreground service to support screen sharing.
  static Future<void> startScreenShare() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startScreenShare');
      debugPrint('[ForegroundService] Upgraded to screen share');
    } catch (e) {
      debugPrint('[ForegroundService] Failed to start screen share service: $e');
    }
  }

  /// Downgrades the foreground service from screen share back to standard call.
  static Future<void> stopScreenShare() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopScreenShare');
      debugPrint('[ForegroundService] Downgraded to call service');
    } catch (e) {
      debugPrint('[ForegroundService] Failed to stop screen share service: $e');
    }
  }

  /// Completely stops the foreground service and removes notification.
  static Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopService');
      debugPrint('[ForegroundService] Stopped service');
    } catch (e) {
      debugPrint('[ForegroundService] Failed to stop service: $e');
    }
  }
}
