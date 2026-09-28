import 'package:flutter/material.dart';

// Colours the designs use that Material 3 has no role for.
extension Palette on ColorScheme {
  bool get _isLight => brightness == Brightness.light;

  // Light cards are white and lifted by a shadow; dark cards are a tone above the page.
  Color get card => _isLight ? surfaceContainerLowest : surfaceContainer;

  List<BoxShadow> get cardShadow => _isLight
      ? const [
          BoxShadow(color: Color(0x141D1B20), offset: Offset(0, 1), blurRadius: 2),
          BoxShadow(color: Color(0x0F1D1B20), offset: Offset(0, 2), blurRadius: 8),
        ]
      : const [];

  Color get star => _isLight ? const Color(0xFFC98A00) : const Color(0xFFF9C74F);

  (Color, Color) get pinkBadge => _isLight
      ? (const Color(0xFFFFD8E4), const Color(0xFF7D5260))
      : (const Color(0xFF633B48), const Color(0xFFFFD9E3));

  (Color, Color) get yellowBadge => _isLight
      ? (const Color(0xFFFFE7B3), const Color(0xFF7A5300))
      : (const Color(0xFF4A3A10), const Color(0xFFF9C74F));

  (Color, Color) get pinkNote => _isLight
      ? (const Color(0xFFFFD8E4), const Color(0xFF31111D))
      : (const Color(0xFF3E2B33), const Color(0xFFFFD9E3));

  // Background, text, then icon and action.
  (Color, Color, Color) get savedBanner => _isLight
      ? (const Color(0xFFFFD8E4), const Color(0xFF31111D), const Color(0xFF7D5260))
      : (const Color(0xFF633B48), const Color(0xFFFFD9E3), const Color(0xFFF0B8C9));

  (Color, Color) get pinkAction => _isLight
      ? (const Color(0xFF7D5260), const Color(0xFFFFFFFF))
      : (const Color(0xFFF0B8C9), const Color(0xFF492532));

  Color get positive => _isLight ? const Color(0xFF3F8F55) : const Color(0xFF9AD1A8);
}
