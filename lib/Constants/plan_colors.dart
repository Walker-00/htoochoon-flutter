import 'package:flutter/material.dart';

@immutable
class PlanColors extends ThemeExtension<PlanColors> {
  final Color basic;
  final Color pro;
  final Color premium;

  const PlanColors({
    required this.basic,
    required this.pro,
    required this.premium,
  });

  @override
  PlanColors copyWith({Color? basic, Color? pro, Color? premium}) {
    return PlanColors(
      basic: basic ?? this.basic,
      pro: pro ?? this.pro,
      premium: premium ?? this.premium,
    );
  }

  @override
  PlanColors lerp(ThemeExtension<PlanColors>? other, double t) {
    if (other is! PlanColors) return this;
    return PlanColors(
      basic: Color.lerp(basic, other.basic, t)!,
      pro: Color.lerp(pro, other.pro, t)!,
      premium: Color.lerp(premium, other.premium, t)!,
    );
  }
}
