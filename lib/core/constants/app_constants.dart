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
  static const String noRecentMeetings = 'No recent meetings';
  static const String noRecentMeetingsSubtext =
      'Your recent meetings will appear here.';
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
}
