import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Centralized authentication service for TransMeet.
///
/// Wraps [FirebaseAuth] and [GoogleSignIn] to provide a clean API
/// for email/password and social authentication.
///
/// Architecture is ready for adding Microsoft Sign-In later.
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  /// Whether the Google Sign-In plugin has been initialized.
  static bool _googleInitialized = false;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// The currently signed-in user, or `null` if not authenticated.
  User? get currentUser => _firebaseAuth.currentUser;

  /// A stream that emits whenever the authentication state changes.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Email + Password
  // ---------------------------------------------------------------------------

  /// Creates a new Firebase account with [email] and [password].
  ///
  /// Throws a user-friendly [String] message on failure.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e.code);
    } catch (_) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Signs in an existing user with [email] and [password].
  ///
  /// Throws a user-friendly [String] message on failure.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e.code);
    } catch (_) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In (google_sign_in v7.x API)
  // ---------------------------------------------------------------------------

  /// Ensures the Google Sign-In plugin is initialized.
  Future<void> _ensureGoogleInitialized() async {
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleInitialized = true;
    }
  }

  /// Initiates the Google Sign-In flow and authenticates with Firebase.
  ///
  /// Returns `null` if the user cancels the sign-in.
  /// Throws a user-friendly [String] message on failure.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthError(e.code);
    } catch (e) {
      // User cancellation or other errors surface here.
      if (e.toString().contains('cancel') ||
          e.toString().contains('sign_in_canceled')) {
        return null;
      }
      throw 'Google Sign-In failed. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Microsoft Sign-In — Placeholder
  // ---------------------------------------------------------------------------

  // TODO: Implement Microsoft Sign-In in a future module.
  //
  // Future<UserCredential?> signInWithMicrosoft() async {
  //   final provider = OAuthProvider('microsoft.com');
  //   provider.addScope('User.Read');
  //   return await _firebaseAuth.signInWithProvider(provider);
  // }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  /// Signs out from all providers (Firebase + Google).
  Future<void> signOut() async {
    try {
      // Sign out from Google.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Google sign-out may fail if the user wasn't signed in via Google.
      }
      await _firebaseAuth.signOut();
    } catch (_) {
      throw 'Failed to sign out. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping
  // ---------------------------------------------------------------------------

  /// Converts Firebase error codes into user-friendly messages.
  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 8 characters.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
