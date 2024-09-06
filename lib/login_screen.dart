import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController =
      TextEditingController(); // First name
  final TextEditingController _lastNameController =
      TextEditingController(); // Last name

  bool _isSignupMode = false;
  File? _profileImage; // Store the picked image
  final ImagePicker _picker = ImagePicker(); // ImagePicker instance

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to pick an image
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _loginUser() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _signupUser() async {
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      return;
    }

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        // Use default profile picture if no image is picked
        String profilePicUrl = _profileImage != null
            ? _profileImage!.path
            : ''; // Handle profile picture
        await _firestore.collection('users').doc(user.uid).set({
          'firstName': _firstNameController.text.trim(), // Save first name
          'lastName': _lastNameController.text.trim(), // Save last name
          'email': user.email,
          'profilePic':
              profilePicUrl, // Save profile pic (could be a path or empty if not provided)
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth =
          await googleUser!.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set(
          {
            'name': user.displayName ?? '',
            'email': user.email,
            'profilePic': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      print(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Image picker for profile picture
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!) // Display picked image
                    : AssetImage('assets/default_profile.png')
                        as ImageProvider, // Default profile picture
                child: _profileImage == null
                    ? Icon(Icons.add_a_photo, size: 40, color: Colors.white)
                    : null,
              ),
            ),
            SizedBox(height: 20),
            // First Name input
            if (_isSignupMode)
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  hintText: 'Enter your first name',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            SizedBox(height: 10),
            // Last Name input
            if (_isSignupMode)
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  hintText: 'Enter your last name',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            SizedBox(height: 10),
            // Email input
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
            // Password input
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
            // Confirm Password input
            if (_isSignupMode)
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Confirm your password',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSignupMode ? _signupUser : _loginUser,
              child: Text(_isSignupMode ? 'Sign Up' : 'Login'),
            ),
            SizedBox(height: 10),
            TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(Colors.white),
              ),
              onPressed: _signInWithGoogle,
              child: Text('Login with Google'),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isSignupMode = !_isSignupMode;
              }),
              child: Text(_isSignupMode
                  ? 'Already have an account? Login'
                  : 'Don\'t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
