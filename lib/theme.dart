import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  /// 🌞 **Modern Light Theme**
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: const Color(0xFF1976D2), // Deep Blue
      scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Off-White Background
      hintColor: const Color(0xFF333333), // Dark Gray Text
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1976D2), // Deep Blue
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge:
            TextStyle(color: Color(0xFF333333), fontSize: 18), // Dark Gray
        bodyMedium: TextStyle(color: Color(0xFF424242), fontSize: 16),
        titleLarge: TextStyle(
            color: Color(0xFF222222),
            fontSize: 22,
            fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: Color(0xFF424242), fontSize: 20),
        labelLarge: TextStyle(
            color: Color(0xFF1976D2),
            fontSize: 16,
            fontWeight: FontWeight.bold),
      ),
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF1976D2),
        secondary: const Color(0xFFFF4081),
        background: const Color(0xFFF5F5F5),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFF1976D2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
        ),
      ),
    );
  }

  /// 🌙 **Sleek Dark Theme**
  static ThemeData get darkTheme {
    return ThemeData(
      primaryColor: const Color(0xFF121212), // Deep Black
      scaffoldBackgroundColor: const Color(0xFF1E1E1E), // Dark Gray Background
      hintColor: const Color(0xFFE0E0E0), // Light Gray Text
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      textTheme: TextTheme(
        bodyLarge: const TextStyle(
            color: Color(0xFFE0E0E0), fontSize: 18), // Light Gray
        bodyMedium: TextStyle(color: Colors.grey.shade400, fontSize: 16),
        titleLarge: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: const TextStyle(color: Colors.white, fontSize: 20),
        labelLarge: const TextStyle(
            color: Color(0xFFBB86FC),
            fontSize: 16,
            fontWeight: FontWeight.bold),
      ),
      colorScheme: ColorScheme.dark(
        primary: const Color.fromARGB(255, 255, 249, 249), // Deep Black
        secondary: const Color(0xFFBB86FC), // Soft Purple Accent
        background: const Color(0xFF1E1E1E), // Dark Gray Background
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFFBB86FC), // Purple Buttons
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2E2E2E), // Dark Input Field
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBB86FC), width: 2),
        ),
      ),
    );
  }
}
