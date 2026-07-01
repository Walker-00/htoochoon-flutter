import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Constants/app_colors.dart';

class AppTypography {
  // ============================================================
  // FONT FAMILY
  // ============================================================
  static const String kFontFamily = 'Inter';

  // ============================================================
  // FONT SIZES
  // ============================================================
  static const double kXXs = 10;
  static const double kXs = 12;
  static const double kSm = 14;
  static const double kMd = 16;
  static const double kLg = 18;
  static const double kXl = 20;
  static const double kXxl = 24;
  static const double kDisplaySm = 28;
  static const double kDisplayMd = 32;

  // ============================================================
  // FONT WEIGHTS
  // ============================================================
  static const FontWeight kRegular = FontWeight.w400;
  static const FontWeight kMedium = FontWeight.w500;
  static const FontWeight kSemibold = FontWeight.w600;
  static const FontWeight kBold = FontWeight.w700;

  // ============================================================
  // LINE HEIGHTS
  // ============================================================
  static const double kTight = 1.2;
  static const double kNormal = 1.4;
  static const double kRelaxed = 1.5;

  // ============================================================
  // LETTER SPACING
  // ============================================================
  static const double kTightSpacing = -0.3;
  static const double kNormalSpacing = 0;
  static const double kWideSpacing = 0.2;

  // ============================================================
  // TEXT STYLES (BASE - NO COLOR)
  // ============================================================

  static const TextStyle kDisplayLarge = TextStyle(
    fontSize: kDisplayMd,
    fontWeight: kBold,
    height: kTight,
    letterSpacing: -0.5,
  );

  static const TextStyle kDisplayMedium = TextStyle(
    fontSize: kDisplaySm,
    fontWeight: kBold,
    height: kTight,
    letterSpacing: -0.5,
  );

  static const TextStyle kHeadline = TextStyle(
    fontSize: kXxl,
    fontWeight: kSemibold,
    height: kNormal,
    letterSpacing: kTightSpacing,
  );

  static const TextStyle kTitle = TextStyle(
    fontSize: kLg,
    fontWeight: FontWeight.w900,
    height: kNormal,
  );

  static const TextStyle kBody = TextStyle(
    fontSize: kMd,
    fontWeight: kRegular,
    height: kRelaxed,
  );

  static const TextStyle kBodySmall = TextStyle(
    fontSize: kSm,
    fontWeight: kRegular,
    height: kRelaxed,
  );

  static const TextStyle kLabel = TextStyle(
    fontSize: kSm,
    fontWeight: kMedium,
    height: kNormal,
    letterSpacing: kWideSpacing,
  );

  static const TextStyle kCaption = TextStyle(
    fontSize: kXs,
    fontWeight: kMedium,
    height: kNormal,
    letterSpacing: kWideSpacing,
  );
}

class AppTextColors {
  static Color kPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.textPrimary
        : AppColors.textPrimaryDark;
  }

  static Color kSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? AppColors.textSecondary
        : AppColors.textSecondaryDark;
  }

  static Color kMuted(BuildContext context) {
    return kSecondary(context).withValues(alpha: 0.6);
  }

  static Color kInverse(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Colors.black;
  }
}
