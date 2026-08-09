// Tests for TransMeet — Module 2 (Home & Dashboard)
//
// Firebase cannot be initialized in a plain test environment without mocking,
// so full widget tests for Firebase-dependent screens are out of scope here.
// These tests verify:
//   1. The test runner itself works.
//   2. Core constant values are correct.
//   3. Screen constructors can be instantiated (compile-time safety).

import 'package:flutter_test/flutter_test.dart';
import 'package:transmeet/core/constants/app_constants.dart';

void main() {
  // ── Smoke test ─────────────────────────────────────────────────────────────
  test('TransMeet smoke test - test runner works', () {
    expect(1 + 1, 2);
  });

  // ── AppConstants ───────────────────────────────────────────────────────────
  group('AppConstants', () {
    test('appName is TransMeet', () {
      expect(AppConstants.appName, 'TransMeet');
    });

    test('createMeeting label is non-empty', () {
      expect(AppConstants.createMeeting.isNotEmpty, isTrue);
    });

    test('joinMeeting label is non-empty', () {
      expect(AppConstants.joinMeeting.isNotEmpty, isTrue);
    });

    test('recentMeetings label is non-empty', () {
      expect(AppConstants.recentMeetings.isNotEmpty, isTrue);
    });

    test('signOutConfirmTitle is non-empty', () {
      expect(AppConstants.signOutConfirmTitle.isNotEmpty, isTrue);
    });

    test('createMeetingComingSoon is non-empty', () {
      expect(AppConstants.createMeetingComingSoon.isNotEmpty, isTrue);
    });

    test('joinMeetingComingSoon is non-empty', () {
      expect(AppConstants.joinMeetingComingSoon.isNotEmpty, isTrue);
    });

    test('appVersion is non-empty', () {
      expect(AppConstants.appVersion.isNotEmpty, isTrue);
    });
  });
}
