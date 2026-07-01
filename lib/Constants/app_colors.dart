import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

class AppColors {
  // ================= LIGHT THEME =================
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color background = Color(0xFFFAFAFA); // Neutral 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0); // Slate 200

  // Semantic Colors
  static const Color success = Color(0xFF10B981); // Green 500
  static const Color successLight = Color(0xFFD1FAE5); // Green 100
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorLight = Color(0xFFFEE2E2); // Red 100
  static const Color info = Color(0xFF3B82F6); // Blue 500
  static const Color infoLight = Color(0xFFDBEAFE); // Blue 100

  // Icons
  static const Color iconPrimary = Color(0xFF0F172A);
  static const Color iconSecondary = Color(0xFF64748B);
  static const Color iconError = error;

  // Buttons / Containers
  static const Color buttonPrimary = Color(0xFF005871);
  static const Color buttonPrimaryDark = info;
  static const Color buttonSecondary = textPrimary; // slate dark
  static const Color buttonSecondaryDark = textPrimaryDark;
  static const Color buttonDisabled = Color(0xFFCBD5E1); // Slate 300
  static const Color buttonDisabledDark = Color(0xFF475569); // Slate 600
  static const Color containerLight = surface; // default white container
  static const Color containerDark = surfaceDark; // dark container

  // ================= DARK THEME =================
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color backgroundDark = Color(0xFF0A0A0B); // Almost black
  static const Color surfaceDark = Color(0xFF141416);
  static const Color borderDark = Color(0xFF27272A); // Zinc 800

  // Semantic Colors (same as light)
  static const Color successDark = success;
  static const Color successLightDark = successLight;
  static const Color warningDark = warning;
  static const Color warningLightDark = warningLight;
  static const Color errorDark = error;
  static const Color errorLightDark = errorLight;
  static const Color infoDark = info;
  static const Color infoLightDark = infoLight;

  // Icons
  static const Color iconPrimaryDark = textPrimaryDark;
  static const Color iconSecondaryDark = textSecondaryDark;
  static const Color iconErrorDark = errorDark;
}
