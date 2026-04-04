import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/constants.dart';
import 'screens/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const ChatScreen(),
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
