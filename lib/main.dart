import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For saving user data
import 'chats_page.dart'; // Import the ChatsPage from chats_page.dart
import 'EditProfilePage.dart';

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
          foregroundColor: Colors.grey, // Grey color for app bar text
        ),
        textTheme: TextTheme(
          bodyLarge:
              TextStyle(color: Colors.grey), // Grey text for large body text
          bodyMedium: TextStyle(
              color: Colors.grey[600]), // Slightly darker grey for medium text
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
          foregroundColor: Colors.grey, // Grey color for dark mode app bar text
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.grey), // Grey text for dark mode
          bodyMedium: TextStyle(color: Colors.grey[600]),
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlutterLogo(size: 100),
              SizedBox(height: 20),
              Text(
                'Welcome to Life Next Messenger',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey, // Grey text color
                ),
              ),
            ],
          ),
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
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final String _defaultProfileImageUrl =
      'https://example.com/default_profile.png';

  bool _isSignupMode = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'profileImage':
            _defaultProfileImageUrl, // Using the default profile image
      });

      await userCredential.user!.sendEmailVerification();
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
        content: Text(message, style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: TextStyle(color: Colors.grey))),
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
            if (_isSignupMode) ...[
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: 'First Name'),
              ),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: 'Last Name'),
              ),
            ],
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
                backgroundColor: const Color.fromARGB(61, 244, 67, 54),
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
              child: Text(
                _isSignupMode
                    ? 'Already have an account? Login'
                    : 'Create an Account',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => _toggleFormMode(FormMode.forgotPassword),
              child: Text('Forgot Password?',
                  style: TextStyle(color: Colors.grey)),
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
        return EditProfilePage();
      default:
        return Center(child: Text('Unknown'));
    }
  }
}
