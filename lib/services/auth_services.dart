import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signUpWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);



  bool _googleInitialized = false;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;

      // Call once before any other use (e.g. in main() or lazily like here)
      if (!_googleInitialized) {
        await googleSignIn.initialize(
          // serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
        );
        _googleInitialized = true;
      }

      // Replaces signIn()
      final GoogleSignInAccount account = await googleSignIn.authenticate();

      // No longer async, and no accessToken here
      final GoogleSignInAuthentication auth = account.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in failed: ${e.code}');
      return null;
    }
  }

  Future<void> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    if (result.status != LoginStatus.success) return;
    final cred =
    FacebookAuthProvider.credential(result.accessToken!.tokenString);
    await _auth.signInWithCredential(cred);
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google কখনো initialize না হলে বা ইউজার Google দিয়ে লগইন না করলে এটা ignore হবে
    }
    await FacebookAuth.instance.logOut();
    await _auth.signOut();
  }
}