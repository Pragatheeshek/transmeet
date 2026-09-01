/// Application-wide constants for TransMeet.
class AppConstants {
  AppConstants._();

  static const String appName = 'TransMeet';
  static const String appTagline = 'Connect. Communicate. Understand.';
  static const String appVersion = '1.0.0';

  // ---------------------------------------------------------------------------
  // Navigation / route names (for future named-route migration if needed)
  // ---------------------------------------------------------------------------
  static const String routeHome = '/home';
  static const String routeCreateMeeting = '/create-meeting';
  static const String routeJoinMeeting = '/join-meeting';
  static const String routeProfile = '/profile';
  static const String routeSettings = '/settings';

  // ---------------------------------------------------------------------------
  // UI strings
  // ---------------------------------------------------------------------------
  static const String welcomeBack = 'Welcome back';
  static const String readyToConnect = 'Ready to connect with your team?';
  static const String createMeeting = 'Create Meeting';
  static const String joinMeeting = 'Join Meeting';
  static const String recentMeetings = 'Recent Meetings';
  static const String noRecentMeetings = 'No meetings yet';
  static const String noRecentMeetingsSubtext =
      'Create or join your first TransMeet meeting.';
  static const String preferredLanguage = 'Preferred Language';
  static const String defaultLanguage = 'English';
  static const String profile = 'Profile';
  static const String settings = 'Settings';
  static const String signOut = 'Sign Out';
  static const String signOutConfirmTitle = 'Sign Out';
  static const String signOutConfirmMessage =
      'Are you sure you want to sign out?';
  static const String cancel = 'Cancel';
  static const String confirm = 'Sign Out';

  // ---------------------------------------------------------------------------
  // Module placeholder strings
  // ---------------------------------------------------------------------------
  static const String createMeetingComingSoon =
      'Meeting creation will be available in the next update.';
  static const String joinMeetingComingSoon =
      'Meeting joining will be available in the next update.';
  static const String featureComingSoon =
      'This feature will be available soon.';

  // ---------------------------------------------------------------------------
  // Supported Languages
  // ---------------------------------------------------------------------------
  static const List<String> supportedLanguages = [
    'English',
    'Tamil',
    'Hindi',
    'Telugu',
    'Malayalam',
    'Kannada',
    'French',
    'German',
    'Spanish',
    'Japanese',
    'Chinese',
  ];

  static const String selectLanguage = 'Select Language';
  static const String languageRequired = 'Please select a preferred language.';

  // ---------------------------------------------------------------------------
  // Module 3 — Meeting Management
  // ---------------------------------------------------------------------------

  // Create Meeting
  static const String meetingTitle = 'Meeting Title';
  static const String meetingTitleHint = 'e.g. Team Standup';
  static const String yourName = 'Your Name';
  static const String meetingId = 'Meeting ID';
  static const String creatingMeeting = 'Creating meeting…';
  static const String meetingCreatedSuccess = 'Meeting Created Successfully 🎉';
  static const String meetingTitleRequired = 'Please enter a meeting title.';
  static const String meetingTitleTooShort =
      'Meeting title must be at least 2 characters.';
  static const String meetingTitleTooLong =
      'Meeting title must be 80 characters or less.';
  static const String meetingCreateError =
      'Unable to create the meeting.\nPlease check your connection and try again.';

  // Join Meeting
  static const String enterMeetingId = 'Enter Meeting ID';
  static const String meetingIdHint = 'e.g. TM-7K4P92';
  static const String findingMeeting = 'Finding meeting…';
  static const String meetingIdRequired = 'Please enter a Meeting ID.';
  static const String meetingIdInvalidFormat =
      'Invalid Meeting ID format.\nExpected format: TM-XXXXXX';
  static const String meetingNotFound =
      'Meeting not found.\nPlease check the Meeting ID.';
  static const String meetingEnded = 'This meeting has ended.';
  static const String meetingJoinError =
      'Unable to join the meeting.\nPlease check your connection and try again.';

  // Meeting Details
  static const String meetingDetails = 'Meeting Details';
  static const String hostedBy = 'Hosted by';
  static const String copyMeetingId = 'Copy Meeting ID';
  static const String meetingIdCopied = 'Meeting ID copied';
  static const String shareMeeting = 'Share Meeting';
  static const String enterMeeting = 'Enter Meeting';
  static const String joinMeetingAction = 'Join';

  // Meeting Room (placeholder)
  static const String meetingRoom = 'Meeting Room';
  static const String leaveMeeting = 'Leave Meeting';
  static const String webrtcPlaceholder =
      'Your video meeting will appear here.';
  static const String leaveConfirmTitle = 'Leave Meeting';
  static const String leaveConfirmMessage =
      'Are you sure you want to leave this meeting?';

  // Share text template
  static const String shareTemplate =
      "You're invited to join a TransMeet meeting.\n\n"
      'Meeting: {title}\n'
      'Meeting ID: {meetingId}\n\n'
      'Open TransMeet and use the Meeting ID to join.';

  // Status labels
  static const String statusActive = 'Active';
  static const String statusEnded = 'Ended';

  // ---------------------------------------------------------------------------
  // Module 5 — AI Translation
  // ---------------------------------------------------------------------------

  /// Base URL for the Node.js translation backend.
  /// During development, use your machine's LAN IP (e.g. http://192.168.x.x:3001).
  static const String backendBaseUrl = 'http://10.0.2.2:3001';

  // Translation UI strings
  static const String translationEnabled = 'Translation: ON';
  static const String translationDisabled = 'Translation: OFF';
  static const String translationToggle = 'Translation';
  static const String myLanguage = 'My Language';
  static const String selectMyLanguage = 'Select Your Language';
  static const String languageSaved = 'Language preference saved.';
  static const String languageSaveFailed =
      'Failed to save language preference. Please try again.';
  static const String translationUnavailable =
      'Translation service unavailable. Please check your connection.';
  static const String speechNotRecognized =
      'Speech could not be recognized. Please try again.';
  static const String translationFailed =
      'Translation failed. Please try again.';
  static const String ttsFailed = 'Text-to-speech failed. Please try again.';
  static const String noInternetConnection =
      'No internet connection. Please check your network.';
  static const String apiTimeout =
      'Request timed out. Please try again.';
  static const String unsupportedLanguage =
      'This language is not supported.';
}
