import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

  final ValueNotifier<String> navBarThemeNotifier = ValueNotifier('blue');
  final ValueNotifier<String> navBarStyleNotifier = ValueNotifier('floating');

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme != null) {
      if (savedTheme == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else {
        themeModeNotifier.value = ThemeMode.system;
      }
    }
    
    final savedNavTheme = prefs.getString('nav_bar_theme');
    if (savedNavTheme != null) {
      navBarThemeNotifier.value = savedNavTheme;
    }

    final savedNavStyle = prefs.getString('nav_bar_style');
    if (savedNavStyle != null) {
      navBarStyleNotifier.value = savedNavStyle;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    String value;
    if (mode == ThemeMode.dark) {
      value = 'dark';
    } else if (mode == ThemeMode.light) {
      value = 'light';
    } else {
      value = 'system';
    }
    await prefs.setString('theme_mode', value);
  }

  Future<void> setNavBarTheme(String theme) async {
    navBarThemeNotifier.value = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nav_bar_theme', theme);
  }

  Future<void> setNavBarStyle(String style) async {
    navBarStyleNotifier.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nav_bar_style', style);
  }
}
