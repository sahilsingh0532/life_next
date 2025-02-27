import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:life_next/home_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:simple_animations/simple_animations.dart';
import 'chats_page.dart';
import 'dart:math' as math;

import 'settings.dart';

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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = Offset(1.0, 0.0);
          var end = Offset.zero;
          var curve = Curves.easeInOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 800),
      ),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E),
              Color(0xFF3949AB),
              Color(0xFF5C6BC0),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FlutterLogo(size: 100)
                    .animate()
                    .scale(duration: 1000.ms, curve: Curves.easeOutBack)
                    .then()
                    .shimmer(
                        duration: 1200.ms,
                        color: Colors.white.withOpacity(0.8)),
                SizedBox(height: 20),
                Text(
                  'Welcome to Life Next Messenger',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black.withOpacity(0.3),
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 400.ms)
                    .then()
                    .slide(
                        duration: 400.ms,
                        begin: Offset(0, 0.2),
                        curve: Curves.easeOut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6A1B9A),
            Color(0xFF8E24AA),
            Color(0xFFAB47BC),
          ],
        ),
      ),
      child: PlasmaRenderer(
        type: PlasmaType.infinity,
        particles: 10,
        color: Color(0x44FFFFFF),
        blur: 0.5,
        size: 0.5,
        speed: 1.5,
        offset: 0,
        blendMode: BlendMode.screen,
        particleType: ParticleType.atlas,
        variation1: 0.3,
        variation2: 0.5,
        variation3: 0.2,
        rotation: 0,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final String _defaultProfileImageUrl = 'defaultProfilePic.png';

  bool _isSignupMode = false;
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MainChatsPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = Offset(0.0, 1.0);
            var end = Offset.zero;
            var curve = Curves.easeInOutCubic;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signupUser() async {
    setState(() {
      _isLoading = true;
    });

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showError("Passwords do not match");
      setState(() {
        _isLoading = false;
      });
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
        'profileImage': _defaultProfileImageUrl,
      });

      await userCredential.user!.sendEmailVerification();
      _showMessage("Verification email sent. Please check your email.");
      setState(() {
        _isSignupMode = false;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showError("Please enter your email address");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      _showMessage("Password reset email sent");
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleUser = await _googleSignIn.signIn();
      if (GoogleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleAuth = await GoogleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: GoogleAuth.accessToken,
        idToken: GoogleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MainChatsPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = Offset(0.0, 1.0);
            var end = Offset.zero;
            var curve = Curves.easeInOutCubic;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: Colors.white.withOpacity(0.9),
        title: Text('Error', style: TextStyle(color: Colors.red[700])),
        content: Text(message, style: TextStyle(color: Colors.grey[800])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: Colors.purple[700])),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purple[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _toggleFormMode(FormMode formMode) {
    _animationController.reset();
    setState(() {
      if (formMode == FormMode.forgotPassword) {
        _isSignupMode = false;
      } else {
        _isSignupMode = formMode == FormMode.signup;
      }
    });
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Container(
                height: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          // Logo and Title
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                FlutterLogo(size: 70)
                                    .animate(
                                        onPlay: (controller) =>
                                            controller.repeat())
                                    .shimmer(
                                        duration: 2000.ms,
                                        color: Colors.white.withOpacity(0.8))
                                    .then()
                                    .scale(
                                        duration: 700.ms,
                                        curve: Curves.easeOutBack),
                                SizedBox(height: 16),
                                Text(
                                  _isSignupMode
                                      ? 'Create Account'
                                      : 'Welcome Back',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 10.0,
                                        color: Colors.black.withOpacity(0.3),
                                        offset: Offset(2.0, 2.0),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 30),

                          // Form Fields
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                if (_isSignupMode) ...[
                                  _buildTextField(
                                    controller: _firstNameController,
                                    label: 'First Name',
                                    icon: Icons.person_outline,
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _lastNameController,
                                    label: 'Last Name',
                                    icon: Icons.person_outline,
                                  ),
                                  SizedBox(height: 16),
                                ],
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                SizedBox(height: 16),
                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                ),
                                if (_isSignupMode) ...[
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    controller: _confirmPasswordController,
                                    label: 'Confirm Password',
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 30),

                          // Action Buttons
                          _isLoading
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                )
                              : Column(
                                  children: [
                                    _buildGradientButton(
                                      text: _isSignupMode ? 'Sign Up' : 'Login',
                                      onPressed: _isSignupMode
                                          ? _signupUser
                                          : _loginUser,
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF6A1B9A),
                                          Color(0xFF4A148C),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    _buildGradientButton(
                                      text: 'Sign in with Google',
                                      onPressed: _signInWithGoogle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFD32F2F),
                                          Color(0xFFB71C1C),
                                        ],
                                      ),
                                      icon: Icons.g_mobiledata,
                                    ),
                                  ],
                                ),
                          SizedBox(height: 20),

                          // Toggle and Forgot Password
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () => _toggleFormMode(_isSignupMode
                                    ? FormMode.login
                                    : FormMode.signup),
                                child: Text(
                                  _isSignupMode
                                      ? 'Already have an account? Login'
                                      : 'Create an Account',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_isSignupMode)
                            TextButton(
                              onPressed: _resetPassword,
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Colors.white.withOpacity(0.5), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
    required Gradient gradient,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 24),
              SizedBox(width: 10),
            ],
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .scale(duration: 200.ms, curve: Curves.easeInOut)
        .then()
        .shimmer(duration: 700.ms, color: Colors.white.withOpacity(0.2));
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
          Icon(Icons.home, size: 30),
          Icon(Icons.chat, size: 30),
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
        return HomeScreen();
      case 1:
        return ChatsPage(bgColor: Colors.transparent); // Your chat page
      case 2:
        return Center(child: Text('Favorites'));
      case 3:
        return SettingsPage();
      default:
        return Center(child: Text('Unknown'));
    }
  }
}

// Plasma renderer for animated background
class PlasmaRenderer extends StatefulWidget {
  final PlasmaType type;
  final int particles;
  final Color color;
  final double blur;
  final double size;
  final double speed;
  final double offset;
  final BlendMode blendMode;
  final ParticleType particleType;
  final double variation1;
  final double variation2;
  final double variation3;
  final double rotation;

  const PlasmaRenderer({
    Key? key,
    this.type = PlasmaType.infinity,
    this.particles = 10,
    this.color = Colors.white,
    this.blur = 0.5,
    this.size = 1.0,
    this.speed = 1.0,
    this.offset = 0.0,
    this.blendMode = BlendMode.srcOver,
    this.particleType = ParticleType.circle,
    this.variation1 = 0.0,
    this.variation2 = 0.0,
    this.variation3 = 0.0,
    this.rotation = 0.0,
  }) : super(key: key);

  @override
  _PlasmaRendererState createState() => _PlasmaRendererState();
}

class _PlasmaRendererState extends State<PlasmaRenderer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: PlasmaPainter(
            _controller.value,
            type: widget.type,
            particles: widget.particles,
            color: widget.color,
            blur: widget.blur,
            size: widget.size,
            speed: widget.speed,
            offset: widget.offset,
            blendMode: widget.blendMode,
            particleType: widget.particleType,
            variation1: widget.variation1,
            variation2: widget.variation2,
            variation3: widget.variation3,
            rotation: widget.rotation,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

enum PlasmaType { infinity, bubbles, circle }

enum ParticleType { circle, square, triangle, atlas }

class PlasmaPainter extends CustomPainter {
  final double progress;
  final PlasmaType type;
  final int particles;
  final Color color;
  final double blur;
  final double size;
  final double speed;
  final double offset;
  final BlendMode blendMode;
  final ParticleType particleType;
  final double variation1;
  final double variation2;
  final double variation3;
  final double rotation;

  PlasmaPainter(
    this.progress, {
    this.type = PlasmaType.infinity,
    this.particles = 10,
    this.color = Colors.white,
    this.blur = 0.5,
    this.size = 1.0,
    this.speed = 1.0,
    this.offset = 0.0,
    this.blendMode = BlendMode.srcOver,
    this.particleType = ParticleType.circle,
    this.variation1 = 0.0,
    this.variation2 = 0.0,
    this.variation3 = 0.0,
    this.rotation = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..blendMode = blendMode;

    switch (type) {
      case PlasmaType.infinity:
        _drawInfinity(canvas, size, paint);
        break;
      case PlasmaType.bubbles:
        _drawBubbles(canvas, size, paint);
        break;
      case PlasmaType.circle:
        _drawCircle(canvas, size, paint);
        break;
    }
  }

  void _drawInfinity(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3 * this.size;

    for (int i = 0; i < particles; i++) {
      final angle = 2 * 3.14159 * ((i / particles) + progress * speed + offset);
      final x = center.dx + radius * 2 * cos(angle);
      final y = center.dy + radius * sin(2 * angle) / 2;

      _drawParticle(canvas, Offset(x, y), paint, size);
    }
  }

  void _drawBubbles(Canvas canvas, Size size, Paint paint) {
    for (int i = 0; i < particles; i++) {
      final seed = i / particles;
      final time = (progress * speed + seed + offset) % 1.0;
      final x = size.width * (0.2 + 0.6 * seed + 0.1 * sin(time * 6.28));
      final y = size.height * (1.0 - time * 0.9);

      _drawParticle(canvas, Offset(x, y), paint, size);
    }
  }

  void _drawCircle(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3 * this.size;

    for (int i = 0; i < particles; i++) {
      final angle = 2 * 3.14159 * ((i / particles) + progress * speed + offset);
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      _drawParticle(canvas, Offset(x, y), paint, size);
    }
  }

  void _drawParticle(
      Canvas canvas, Offset position, Paint paint, Size canvasSize) {
    final particleSize = canvasSize.width *
        0.05 *
        this.size *
        (0.8 + 0.4 * sin(progress * 6.28 * speed));

    switch (particleType) {
      case ParticleType.circle:
        canvas.drawCircle(position, particleSize, paint);
        break;
      case ParticleType.square:
        canvas.drawRect(
          Rect.fromCenter(
              center: position,
              width: particleSize * 2,
              height: particleSize * 2),
          paint,
        );
        break;
      case ParticleType.triangle:
        final path = Path();
        path.moveTo(position.dx, position.dy - particleSize);
        path.lineTo(position.dx + particleSize, position.dy + particleSize);
        path.lineTo(position.dx - particleSize, position.dy + particleSize);
        path.close();
        canvas.drawPath(path, paint);
        break;
      case ParticleType.atlas:
        // Draw a more complex shape
        final path = Path();
        for (int i = 0; i < 5; i++) {
          final angle = 2 * 3.14159 * (i / 5) + rotation;
          final x = position.dx + particleSize * cos(angle);
          final y = position.dy + particleSize * sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  double sin(double value) {
    return math.sin(value);
  }

  double cos(double value) {
    return math.cos(value);
  }

  @override
  bool shouldRepaint(PlasmaPainter oldDelegate) => true;
}

// Import math library