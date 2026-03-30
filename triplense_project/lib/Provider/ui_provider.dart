import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UiProvider extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;
  late SharedPreferences _prefs;

  ThemeData get darkTheme => ThemeData.dark().copyWith(
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black87),
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      );

  ThemeData get lightTheme => ThemeData.light().copyWith(
        appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromARGB(255, 192, 141, 64)),
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black)),
      );

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isDark = _prefs.getBool("isDark") ?? false;
    notifyListeners();
  }

  void changeTheme() {
    _isDark = !_isDark;
    _prefs.setBool("isDark", _isDark);
    notifyListeners();
  }
}
