import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// الألوان: أخضر هادئ + ذهبي + كريمي.
const Color gold = Color(0xFFC9A24B);
const Color goldDeep = Color(0xFF9C7A2B);
const Color cream = Color(0xFFF8F4E8);
const Color creamCard = Color(0xFFFFFCF5);

class AccentOption {
  final String name;
  final Color color;
  const AccentOption(this.name, this.color);
}

const accents = <AccentOption>[
  AccentOption('أخضر سكينة', Color(0xFF0F7B5F)),
  AccentOption('زمردي', Color(0xFF14695A)),
  AccentOption('أزرق ليلي', Color(0xFF2A5D8F)),
  AccentOption('بنفسجي', Color(0xFF6B4C9A)),
  AccentOption('ذهبي', Color(0xFFA37F1E)),
  AccentOption('عنابي', Color(0xFF8E3B46)),
];

const fontChoices = <String>['Cairo', 'Tajawal', 'Almarai', 'Amiri'];

TextTheme _textFor(String font, TextTheme base) {
  switch (font) {
    case 'Tajawal':
      return GoogleFonts.tajawalTextTheme(base);
    case 'Almarai':
      return GoogleFonts.almaraiTextTheme(base);
    case 'Amiri':
      return GoogleFonts.amiriTextTheme(base);
    default:
      return GoogleFonts.cairoTextTheme(base);
  }
}

TextStyle quranStyle(double size, Color color) {
  try {
    return GoogleFonts.amiriQuran(fontSize: size, height: 2.1, color: color);
  } catch (_) {
    return TextStyle(fontSize: size, height: 2.1, color: color);
  }
}

ThemeData buildTheme(Brightness b, int accentIndex, String font) {
  final dark = b == Brightness.dark;
  final seed = accents[accentIndex.clamp(0, accents.length - 1)].color;
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: b,
    surface: dark ? const Color(0xFF15211D) : creamCard,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1714) : cream,
    textTheme: _textFor(font, base.textTheme),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
    ),
  );
}
