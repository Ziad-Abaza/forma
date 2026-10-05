import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeProvider = StateProvider<Locale>((ref) {
  return const Locale('en');
});

final numeralSystemProvider = StateProvider<String>((ref) {
  return 'western';
});

String formatNumeralString(String input, String numeralSystem) {
  if (numeralSystem == 'western') return input;

  const arabicIndicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return input.replaceAllMapped(RegExp(r'\d'), (match) {
    final digit = int.parse(match.group(0)!);
    return arabicIndicDigits[digit];
  });
}
