import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../config/constants.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'chat_screen.dart';

/// Listens to Firebase Auth state and routes to the appropriate screen:
///   - Not signed in  → LoginScreen
///   - Signed in, no role → RoleSelectionScreen
///   - Signed in, role set → ChatScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        // Still waiting for Firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        // Not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Logged in — check if role is set
        return FutureBuilder<bool>(
          future: AuthService.hasCompletedOnboarding(snapshot.data!.uid),
          builder: (ctx, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            if (roleSnap.data == true) {
              return const ChatScreen();
            }
            return const RoleSelectionScreen();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kBgColor,
      body: Center(
        child: CircularProgressIndicator(
          color: kPrimaryColor,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}
