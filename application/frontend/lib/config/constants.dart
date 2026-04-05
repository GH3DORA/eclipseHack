import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

// ── API ──────────────────────────────────────────────────────────────────────
const String kBaseUrl = 'http://127.0.0.1:5000';

// ── Colors ───────────────────────────────────────────────────────────────────
const Color kBgColor = Color(0xFF080B10);
const Color kSurfaceColor = Color(0xFF12161E);
const Color kSurfaceBorderColor = Color(0xFF1A222D);
const Color kDividerColor = Color(0xFF1A222D);
const Color kDrawerBg = Color(0xFF0C1017);
const Color kDrawerBorder = Color(0xFF1A222D);

const Color kPrimaryColor = Color(0xFF20C29B);
const Color kSecondaryColor = Color(0xFF15997A);
const Color kDangerColor = Color(0xFFFF3B3B);
const Color kOrangeColor = Color(0xFFFF9500);

// ── Gradients ────────────────────────────────────────────────────────────────
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [kPrimaryColor, kSecondaryColor],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ── Text Styles ──────────────────────────────────────────────────────────────
final TextStyle kAppTitleStyle = GoogleFonts.outfit(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.3,
);

final TextStyle kSubtitleStyle = GoogleFonts.dmSans(
  color: Colors.white38,
  fontSize: 11,
);

final TextStyle kMessageStyle = GoogleFonts.dmSans(
  color: Colors.white,
  fontSize: 15,
  height: 1.5,
);

final TextStyle kAiMessageStyle = GoogleFonts.dmSans(
  color: Colors.white,
  fontSize: 15,
  height: 1.6,
);

final TextStyle kDrawerTitleStyle = GoogleFonts.outfit(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.w700,
);

final TextStyle kDrawerSectionStyle = GoogleFonts.outfit(
  color: Colors.white54,
  fontSize: 12,
  letterSpacing: 0.5,
  fontWeight: FontWeight.w600,
);

final TextStyle kDisclaimerStyle = GoogleFonts.dmSans(
  color: Colors.white24,
  fontSize: 10.5,
);
