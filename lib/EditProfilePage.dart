import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Function to pick an image
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  // Function to load user data from Firestore
  Future<void> _loadUserData() async {
    _user = _auth.currentUser;
    if (_user != null) {
      DocumentSnapshot userData =
          await _firestore.collection('users').doc(_user!.uid).get();

      setState(() {
        _firstNameController.text = userData['firstName'];
        _lastNameController.text = userData['lastName'];
        _emailController.text = _user!.email!;
        _profileImageUrl = userData['profilePic'] ?? ''; // Profile pic URL
      });
    }
  }

  // Function to update the user profile
  Future<void> _updateUserProfile() async {
    if (_user != null) {
      String imageUrl = _profileImageUrl ?? '';

      // If a new image is selected, upload it to Firebase Storage (optional)
      if (_profileImage != null) {
        // Here you can add Firebase Storage upload logic if needed
        // Example:
        // imageUrl = await _uploadImageToFirebase(_profileImage!);
      }

      try {
        // Update user data in Firestore
        await _firestore.collection('users').doc(_user!.uid).update({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'profilePic': imageUrl,
        });

        // Show success alert dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Success'),
              content: Text('Profile updated successfully!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        print(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!) // Display new picked image
                    : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                            ? NetworkImage(_profileImageUrl!)
                            : AssetImage('assets/default_profile.png'))
                        as ImageProvider, // Existing profile pic or default
                child: _profileImage == null
                    ? Icon(Icons.add_a_photo, size: 40, color: Colors.white)
                    : null,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: 'First Name',
                hintText: 'Enter your first name',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: 'Last Name',
                hintText: 'Enter your last name',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _emailController,
              readOnly: true, // Email is not editable
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateUserProfile,
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
