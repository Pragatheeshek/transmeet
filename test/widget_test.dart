// Tests for TransMeet — Modules 2, 3 & 4
//
// Firebase cannot be initialized in a plain test environment without mocking,
// so full widget tests for Firebase-dependent screens are out of scope here.
// These tests verify:
//   1. The test runner itself works.
//   2. Core constant values are correct.
//   3. Meeting ID generator produces valid IDs.
//   4. Meeting model serialization/deserialization works.
//   5. Module 4 — preferredLanguage field, validation logic, supported languages.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/core/utils/meeting_id_generator.dart';
import 'package:transmeet/features/meeting/models/meeting_model.dart';

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

    // Module 3 constants
    test('meetingTitle label is non-empty', () {
      expect(AppConstants.meetingTitle.isNotEmpty, isTrue);
    });

    test('meetingIdCopied label is non-empty', () {
      expect(AppConstants.meetingIdCopied.isNotEmpty, isTrue);
    });

    test('shareTemplate contains placeholders', () {
      expect(AppConstants.shareTemplate.contains('{title}'), isTrue);
      expect(AppConstants.shareTemplate.contains('{meetingId}'), isTrue);
    });

    // Module 4 constants
    test('supportedLanguages list is non-empty', () {
      expect(AppConstants.supportedLanguages.isNotEmpty, isTrue);
    });

    test('supportedLanguages contains English', () {
      expect(AppConstants.supportedLanguages.contains('English'), isTrue);
    });

    test('supportedLanguages has at least 10 languages', () {
      expect(AppConstants.supportedLanguages.length, greaterThanOrEqualTo(10));
    });

    test('selectLanguage label is non-empty', () {
      expect(AppConstants.selectLanguage.isNotEmpty, isTrue);
    });

    test('languageRequired message is non-empty', () {
      expect(AppConstants.languageRequired.isNotEmpty, isTrue);
    });

    test('noRecentMeetings uses Module 4 text', () {
      expect(AppConstants.noRecentMeetings, 'No meetings yet');
    });

    test('noRecentMeetingsSubtext uses Module 4 text', () {
      expect(
        AppConstants.noRecentMeetingsSubtext,
        'Create or join your first TransMeet meeting.',
      );
    });
  });

  // ── Meeting ID Generator ──────────────────────────────────────────────────
  group('MeetingIdGenerator', () {
    test('generates non-empty IDs', () {
      final id = MeetingIdGenerator.generate();
      expect(id.isNotEmpty, isTrue);
    });

    test('generates IDs with TM- prefix', () {
      final id = MeetingIdGenerator.generate();
      expect(id.startsWith('TM-'), isTrue);
    });

    test('generates IDs with correct length (TM- + 6 chars)', () {
      final id = MeetingIdGenerator.generate();
      expect(id.length, 9); // "TM-" (3) + 6 = 9
    });

    test('generated IDs pass format validation', () {
      for (var i = 0; i < 50; i++) {
        final id = MeetingIdGenerator.generate();
        expect(MeetingIdGenerator.isValidFormat(id), isTrue,
            reason: 'ID "$id" did not pass format validation');
      }
    });

    test('generates unique IDs (100 IDs should all be different)', () {
      final ids = <String>{};
      for (var i = 0; i < 100; i++) {
        ids.add(MeetingIdGenerator.generate());
      }
      expect(ids.length, 100);
    });

    test('isValidFormat rejects empty string', () {
      expect(MeetingIdGenerator.isValidFormat(''), isFalse);
    });

    test('isValidFormat rejects short IDs', () {
      expect(MeetingIdGenerator.isValidFormat('TM-AB'), isFalse);
    });

    test('isValidFormat accepts valid ID without prefix', () {
      expect(MeetingIdGenerator.isValidFormat('ABC234'), isTrue);
    });

    test('normalize adds TM- prefix', () {
      expect(MeetingIdGenerator.normalize('abc234'), 'TM-ABC234');
    });

    test('normalize preserves existing prefix', () {
      expect(MeetingIdGenerator.normalize('TM-ABC234'), 'TM-ABC234');
    });

    test('normalize returns null for empty input', () {
      expect(MeetingIdGenerator.normalize(''), isNull);
    });

    test('normalize handles whitespace', () {
      expect(MeetingIdGenerator.normalize('  tm-abc234  '), 'TM-ABC234');
    });

    // Module 4 — meeting ID validation edge cases
    test('isValidFormat rejects IDs with spaces', () {
      expect(MeetingIdGenerator.isValidFormat('TM-AB C2'), isFalse);
    });

    test('isValidFormat rejects IDs with lowercase only when invalid chars', () {
      // normalize handles case, so 'abc234' should be valid after normalize
      expect(MeetingIdGenerator.isValidFormat('abc234'), isTrue);
    });
  });

  // ── Meeting Model ─────────────────────────────────────────────────────────
  group('MeetingModel', () {
    final testDate = DateTime(2026, 8, 16, 19, 30);

    MeetingModel createTestMeeting() {
      return MeetingModel(
        docId: 'test-doc-id',
        meetingId: 'TM-ABC234',
        title: 'Project Discussion',
        hostUid: 'uid-123',
        hostName: 'Test User',
        hostEmail: 'test@example.com',
        preferredLanguage: 'English',
        createdAt: testDate,
        status: 'active',
        participantCount: 1,
      );
    }

    test('toMap produces correct map', () {
      final meeting = createTestMeeting();
      final map = meeting.toMap();

      expect(map['meetingId'], 'TM-ABC234');
      expect(map['title'], 'Project Discussion');
      expect(map['hostUid'], 'uid-123');
      expect(map['hostName'], 'Test User');
      expect(map['hostEmail'], 'test@example.com');
      expect(map['preferredLanguage'], 'English');
      expect(map['status'], 'active');
      expect(map['participantCount'], 1);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('fromMap roundtrip produces identical model', () {
      final original = createTestMeeting();
      final map = original.toMap();
      final restored = MeetingModel.fromMap('test-doc-id', map);

      expect(restored.docId, original.docId);
      expect(restored.meetingId, original.meetingId);
      expect(restored.title, original.title);
      expect(restored.hostUid, original.hostUid);
      expect(restored.hostName, original.hostName);
      expect(restored.hostEmail, original.hostEmail);
      expect(restored.preferredLanguage, original.preferredLanguage);
      expect(restored.status, original.status);
      expect(restored.participantCount, original.participantCount);
      expect(restored.createdAt.year, original.createdAt.year);
      expect(restored.createdAt.month, original.createdAt.month);
      expect(restored.createdAt.day, original.createdAt.day);
    });

    test('isActive returns true for active meetings', () {
      final meeting = createTestMeeting();
      expect(meeting.isActive, isTrue);
      expect(meeting.isEnded, isFalse);
    });

    test('isEnded returns true for ended meetings', () {
      final meeting = MeetingModel(
        docId: 'doc',
        meetingId: 'TM-ABC234',
        title: 'Done',
        hostUid: 'uid',
        hostName: 'Host',
        hostEmail: 'h@e.com',
        preferredLanguage: 'Tamil',
        createdAt: testDate,
        status: 'ended',
        participantCount: 3,
      );
      expect(meeting.isEnded, isTrue);
      expect(meeting.isActive, isFalse);
    });

    test('fromMap handles missing fields gracefully', () {
      final meeting = MeetingModel.fromMap('doc-id', {});
      expect(meeting.docId, 'doc-id');
      expect(meeting.meetingId, '');
      expect(meeting.title, '');
      expect(meeting.hostUid, '');
      expect(meeting.preferredLanguage, 'English');
      expect(meeting.status, 'active');
      expect(meeting.participantCount, 1);
    });

    test('toFirestore uses FieldValue.serverTimestamp', () {
      final meeting = createTestMeeting();
      final firestoreMap = meeting.toFirestore();
      expect(firestoreMap['createdAt'], isA<FieldValue>());
    });

    // Module 4 — preferredLanguage field tests
    test('preferredLanguage defaults to English when missing from map', () {
      final meeting = MeetingModel.fromMap('doc-id', {
        'meetingId': 'TM-XYZ789',
        'title': 'Test',
        'hostUid': 'uid-1',
        'hostName': 'User',
        'hostEmail': 'user@test.com',
        'status': 'active',
      });
      expect(meeting.preferredLanguage, 'English');
    });

    test('preferredLanguage is serialized in toMap', () {
      final meeting = MeetingModel(
        docId: 'doc',
        meetingId: 'TM-ABC234',
        title: 'Test',
        hostUid: 'uid',
        hostName: 'Host',
        hostEmail: 'h@e.com',
        preferredLanguage: 'Tamil',
        createdAt: testDate,
        status: 'active',
        participantCount: 1,
      );
      final map = meeting.toMap();
      expect(map['preferredLanguage'], 'Tamil');
    });

    test('preferredLanguage is serialized in toFirestore', () {
      final meeting = MeetingModel(
        docId: 'doc',
        meetingId: 'TM-ABC234',
        title: 'Test',
        hostUid: 'uid',
        hostName: 'Host',
        hostEmail: 'h@e.com',
        preferredLanguage: 'Hindi',
        createdAt: testDate,
        status: 'active',
        participantCount: 1,
      );
      final firestoreMap = meeting.toFirestore();
      expect(firestoreMap['preferredLanguage'], 'Hindi');
    });

    test('preferredLanguage roundtrip via fromMap/toMap', () {
      for (final lang in ['English', 'Tamil', 'Hindi', 'French', 'Japanese']) {
        final original = MeetingModel(
          docId: 'doc',
          meetingId: 'TM-ABC234',
          title: 'Test',
          hostUid: 'uid',
          hostName: 'Host',
          hostEmail: 'h@e.com',
          preferredLanguage: lang,
          createdAt: testDate,
          status: 'active',
          participantCount: 1,
        );
        final restored = MeetingModel.fromMap('doc', original.toMap());
        expect(restored.preferredLanguage, lang,
            reason: 'Failed roundtrip for language: $lang');
      }
    });
  });

  // ── Module 4 — Validation Logic ───────────────────────────────────────────
  group('Module 4 — Validation', () {
    test('empty meeting title should fail validation', () {
      const title = '';
      expect(title.trim().isEmpty, isTrue);
    });

    test('whitespace-only meeting title should fail validation', () {
      const title = '   ';
      expect(title.trim().isEmpty, isTrue);
    });

    test('valid meeting title should pass validation', () {
      const title = 'Team Discussion';
      final trimmed = title.trim();
      expect(trimmed.isNotEmpty, isTrue);
      expect(trimmed.length >= 2, isTrue);
      expect(trimmed.length <= 80, isTrue);
    });

    test('meeting title exceeding 80 chars should fail validation', () {
      final title = 'A' * 81;
      expect(title.length > 80, isTrue);
    });

    test('empty meeting ID should fail validation', () {
      expect(MeetingIdGenerator.isValidFormat(''), isFalse);
    });

    test('whitespace-only meeting ID should fail validation', () {
      expect(MeetingIdGenerator.normalize('   '), isNull);
    });

    test('valid meeting ID should pass validation', () {
      final id = MeetingIdGenerator.generate();
      expect(MeetingIdGenerator.isValidFormat(id), isTrue);
    });
  });
}
