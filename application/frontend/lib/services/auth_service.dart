import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Stream ────────────────────────────────────────────────────────────────
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  // ── Sign Up ───────────────────────────────────────────────────────────────
  static Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(displayName);

    // Create the user document in Firestore (no role yet — set on next step)
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email,
      'displayName': displayName,
      'role': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  // ── Sign In ───────────────────────────────────────────────────────────────
  static Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Role Management ───────────────────────────────────────────────────────
  static Future<void> setRole(String uid, String role) async {
    await _db.collection('users').doc(uid).update({'role': role});
  }

  /// Returns null if the user document doesn't exist yet or role is unset.
  static Future<String?> getRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['role'] as String?;
  }

  // ── Check if user has completed onboarding ────────────────────────────────
  static Future<bool> hasCompletedOnboarding(String uid) async {
    final role = await getRole(uid);
    return role != null && role.isNotEmpty;
  }
}
