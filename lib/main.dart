import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'chats_page.dart'; // Import the ChatsPage from chats_page.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Life Next Messenger',
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black54),
        ),
        colorScheme:
            ColorScheme.fromSwatch().copyWith(secondary: Colors.blueAccent),
        bottomAppBarTheme: BottomAppBarTheme(color: Colors.grey[200]),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        colorScheme:
            ColorScheme.fromSwatch().copyWith(secondary: Colors.redAccent),
        bottomAppBarTheme: BottomAppBarTheme(color: Colors.grey[900]),
      ),
      themeMode: ThemeMode.system, // Switch based on system settings
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  _navigateToLogin() async {
    await Future.delayed(Duration(seconds: 3), () {});
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            SizedBox(height: 20),
            Text('Welcome to Life Next Messenger',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSignupMode = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _loginUser() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainChatsPage()),
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _signupUser() async {
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showError("Passwords do not match");
      return;
    }
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _auth.currentUser!.sendEmailVerification();
      _showMessage("Verification email sent. Please check your email.");
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _resetPassword() async {
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      _showMessage("Password reset email sent");
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleUser = await _googleSignIn.signIn();
      final GoogleAuth = await GoogleUser!.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: GoogleAuth.accessToken,
        idToken: GoogleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainChatsPage()),
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignupMode ? 'Sign Up' : 'Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
            ),
            if (_isSignupMode) ...[
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Confirm Password'),
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSignupMode ? _signupUser : _loginUser,
              child: Text(_isSignupMode ? 'Sign Up' : 'Login'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _signInWithGoogle(),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/google_icon.png',
                      height: 24), // Use Image.asset for PNG
                  SizedBox(width: 10),
                  Text('Sign in with Google'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isSignupMode = !_isSignupMode),
              child: Text(_isSignupMode
                  ? 'Already have an account? Login'
                  : 'Create an Account'),
            ),
            TextButton(
              onPressed: () => _toggleFormMode(FormMode.forgotPassword),
              child: Text('Forgot Password?'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFormMode(FormMode formMode) {
    setState(() {
      if (formMode == FormMode.forgotPassword) {
        _isSignupMode = false;
      } else {
        _isSignupMode = formMode == FormMode.signup;
      }
    });
  }
}

enum FormMode { login, signup, forgotPassword }

class MainChatsPage extends StatefulWidget {
  @override
  _MainChatsPageState createState() => _MainChatsPageState();
}

class _MainChatsPageState extends State<MainChatsPage> {
  int _selectedIndex = 0;
  final List<Color> _colors = [
    const Color.fromARGB(255, 3, 51, 90),
    const Color.fromARGB(255, 13, 126, 17),
    const Color.fromARGB(255, 93, 5, 109),
    const Color.fromARGB(255, 155, 95, 6),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getPage(_selectedIndex),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        items: <Widget>[
          Icon(Icons.chat, size: 30),
          Icon(Icons.flash_on, size: 30),
          Icon(Icons.star, size: 30),
          Icon(Icons.settings, size: 30),
        ],
        color: _colors[_selectedIndex],
        index: _selectedIndex,
        height: 50,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return ChatsPage(bgColor: Colors.transparent); // Your chat page
      case 1:
        return Center(child: Text('Discover'));
      case 2:
        return Center(child: Text('Favorites'));
      case 3:
        return Center(child: Text('Settings'));
      default:
        return Center(child: Text('Unknown'));
    }
  }
}
