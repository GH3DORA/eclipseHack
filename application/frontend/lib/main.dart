import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'config/constants.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediGuide Assistant',
      theme: _buildTheme(),
      home: const AuthGate(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBgColor,
      colorScheme: const ColorScheme.dark(
        primary: kPrimaryColor,
        secondary: kSecondaryColor,
        surface: kSurfaceColor,
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: kBgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white70),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: kDrawerBg,
      ),
    );
  }
}

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
          return const _SplashScreen();
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
              return const _SplashScreen();
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

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
