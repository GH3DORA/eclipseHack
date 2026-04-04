import 'package:flutter/material.dart';

// ── API ──────────────────────────────────────────────────────────────────────
const String kBaseUrl = 'http://127.0.0.1:5000';

// ── Colors ───────────────────────────────────────────────────────────────────
const Color kBgColor = Color(0xFF0D0D0D);
const Color kSurfaceColor = Color(0xFF1A1A1A);
const Color kSurfaceBorderColor = Color(0xFF2A2A2A);
const Color kDividerColor = Color(0xFF222222);
const Color kDrawerBg = Color(0xFF111111);
const Color kDrawerBorder = Color(0xFF1E1E1E);

const Color kPrimaryColor = Color(0xFF00E5C8);
const Color kSecondaryColor = Color(0xFF7B61FF);
const Color kDangerColor = Color(0xFFFF3B3B);
const Color kOrangeColor = Color(0xFFFF9500);

// ── Gradients ────────────────────────────────────────────────────────────────
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [kPrimaryColor, kSecondaryColor],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ── Text Styles ──────────────────────────────────────────────────────────────
const TextStyle kAppTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 17,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.3,
);

const TextStyle kSubtitleStyle = TextStyle(
  color: Colors.white38,
  fontSize: 11,
);

const TextStyle kMessageStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  height: 1.5,
);

const TextStyle kAiMessageStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  height: 1.6,
);

const TextStyle kDrawerTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.w700,
);

const TextStyle kDrawerSectionStyle = TextStyle(
  color: Colors.white54,
  fontSize: 12,
  letterSpacing: 0.5,
  fontWeight: FontWeight.w600,
);

const TextStyle kDisclaimerStyle = TextStyle(
  color: Colors.white24,
  fontSize: 10.5,
);
