import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // Lazy: touching FirebaseAuth.instance before Firebase is up throws and breaks the screen.
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Returns the signed-in Firebase user, or null if cancelled/failed.
  Future<UserCredential?> signInWithGoogle() async {
    if (Firebase.apps.isEmpty) throw Exception('Google sign-in is unavailable right now. Use your phone number.');
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      print('Google sign-in error: $e');
      return null;
    }
  }

  /// Call this after a successful sign-in to get the ID token
  /// you'll send to your own backend to exchange for a Bearer token.
  Future<String?> getIdToken() async {
    if (Firebase.apps.isEmpty) return null;
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<void> signOut() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}