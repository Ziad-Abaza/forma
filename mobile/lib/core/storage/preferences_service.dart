import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for local and account-level persistence of user settings (locale and numerals).
class PreferencesService {
  static const _keyLocale = 'forma_locale_code';
  static const _keyNumeralSystem = 'forma_numeral_system';

  static Future<Locale> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyLocale) ?? 'en';
    return Locale(code);
  }

  static Future<String> getSavedNumeralSystem() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNumeralSystem) ?? 'western';
  }

  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale.languageCode);
  }

  static Future<void> saveNumeralSystem(String numeralSystem) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNumeralSystem, numeralSystem);
  }
}
