import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      primaryColor: Colors.white,
      scaffoldBackgroundColor: Colors.white,
      hintColor: const Color.fromARGB(255, 0, 0, 0),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color.fromARGB(255, 0, 0, 0),
      ),
      textTheme: TextTheme(
        bodyLarge: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
        bodyMedium: TextStyle(color: const Color.fromARGB(255, 0, 0, 0)),
      ),
      colorScheme:
          ColorScheme.fromSwatch().copyWith(secondary: Colors.blueAccent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: Colors.black,
      scaffoldBackgroundColor: const Color.fromARGB(255, 0, 0, 0),
      hintColor: const Color.fromARGB(255, 253, 253, 253),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Color.fromARGB(255, 255, 255, 255),
      ),
      textTheme: TextTheme(
        bodyLarge: const TextStyle(color: Colors.grey),
        bodyMedium: TextStyle(color: Colors.grey.shade400),
      ),
      colorScheme:
          ColorScheme.fromSwatch().copyWith(secondary: Colors.redAccent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color.fromARGB(255, 212, 198, 198),
        hintStyle: TextStyle(color: Colors.grey.shade300),
      ),
    );
  }
}
