import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:life_next/main.dart';
import 'EditProfilePage.dart';
import 'memo_screen.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'theme.dart';

class EnhancedSettingsPage extends StatefulWidget {
  const EnhancedSettingsPage({
    Key? key,
    required String userName,
    required String userId,
  }) : super(key: key);

  @override
  State<EnhancedSettingsPage> createState() => _EnhancedSettingsPageState();
}

class _EnhancedSettingsPageState extends State<EnhancedSettingsPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _profileController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _profileAnimation;

  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;
  bool _autoBackup = true;
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserPreferences();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _profileController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _profileAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _profileController.forward();
  }

  void _loadUserPreferences() async {
    // Load user preferences from Firestore or SharedPreferences
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _biometricEnabled = data['biometricEnabled'] ?? false;
          _autoBackup = data['autoBackup'] ?? true;
          _fontSize = data['fontSize']?.toDouble() ?? 16.0;
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  void _saveUserPreference(String key, dynamic value) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({key: value});
    } catch (e) {
      print('Error saving preference: $e');
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    HapticFeedback.mediumImpact();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 24),
                    const SizedBox(width: 8),
                    const Text('Confirm Logout'),
                  ],
                ),
                content: const Text(
                  'Are you sure you want to log out? You will need to sign in again to access your account.',
                  style: TextStyle(fontSize: 16),
                ),
                actions: <Widget>[
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Logout', style: TextStyle(fontSize: 16)),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => MyApp()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Font Size'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sample Text',
                    style: TextStyle(fontSize: _fontSize),
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: _fontSize,
                    min: 12.0,
                    max: 24.0,
                    divisions: 6,
                    label: _fontSize.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        _fontSize = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _saveUserPreference('fontSize', _fontSize);
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
              ),
            );
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final firstName = userData['firstName'] ?? 'User';
          final lastName = userData['lastName'] ?? '';
          final email = userData['email'] ??
              FirebaseAuth.instance.currentUser?.email ??
              '';
          final profileImage = userData['profileImage'];

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                slivers: [
                  // Custom App Bar with Profile
                  SliverAppBar(
                    expandedHeight: 200,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Theme.of(context).primaryColor,
                    leading: IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 12),
                              Text(
                                '$firstName $lastName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Settings Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Account Section
                          _buildSectionHeader('Account', Icons.person),
                          _buildAnimatedSettingsItem(
                            title: 'Edit Profile',
                            subtitle: 'Update your personal information',
                            icon: Icons.edit,
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      EditProfilePage(),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    return SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(1.0, 0.0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            delay: 100,
                          ),
                          _buildAnimatedSettingsItem(
                            title: 'Privacy & Security',
                            subtitle: 'Manage your privacy settings',
                            icon: Icons.security,
                            onTap: () {
                              // TODO: Navigate to privacy settings page
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Privacy & Security - Coming Soon!')),
                              );
                            },
                            delay: 150,
                          ),

                          const SizedBox(height: 20),

                          // Preferences Section
                          _buildSectionHeader('Preferences', Icons.tune),
                          _buildAnimatedSettingsItem(
                            title: 'Notifications',
                            subtitle: 'Push notifications and alerts',
                            icon: Icons.notifications,
                            onTap: () {
                              setState(() {
                                _notificationsEnabled = !_notificationsEnabled;
                              });
                              _saveUserPreference('notificationsEnabled',
                                  _notificationsEnabled);
                              HapticFeedback.lightImpact();
                            },
                            trailing: Switch.adaptive(
                              value: _notificationsEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _notificationsEnabled = value;
                                });
                                _saveUserPreference(
                                    'notificationsEnabled', value);
                                HapticFeedback.lightImpact();
                              },
                            ),
                            delay: 200,
                          ),
                          Consumer<ThemeProvider>(
                            builder: (context, themeProvider, child) {
                              return _buildAnimatedSettingsItem(
                                title: 'Dark Mode',
                                subtitle: 'Switch between light and dark theme',
                                icon: themeProvider.isDarkMode
                                    ? Icons.dark_mode
                                    : Icons.light_mode,
                                trailing: Switch.adaptive(
                                  value: themeProvider.isDarkMode,
                                  onChanged: (_) {
                                    themeProvider.toggleTheme();
                                    HapticFeedback.lightImpact();
                                  },
                                ),
                                onTap: () => themeProvider.toggleTheme(),
                                delay: 250,
                              );
                            },
                          ),
                          _buildAnimatedSettingsItem(
                            title: 'Font Size',
                            subtitle: 'Adjust text size for better readability',
                            icon: Icons.text_fields,
                            onTap: _showFontSizeDialog,
                            delay: 300,
                          ),
                          _buildAnimatedSettingsItem(
                            title: 'Biometric Login',
                            subtitle: 'Use fingerprint or face recognition',
                            icon: Icons.fingerprint,
                            onTap: () {
                              setState(() {
                                _biometricEnabled = !_biometricEnabled;
                              });
                              _saveUserPreference(
                                  'biometricEnabled', _biometricEnabled);
                              HapticFeedback.lightImpact();
                            },
                            trailing: Switch.adaptive(
                              value: _biometricEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _biometricEnabled = value;
                                });
                                _saveUserPreference('biometricEnabled', value);
                                HapticFeedback.lightImpact();
                              },
                            ),
                            delay: 350,
                          ),

                          const SizedBox(height: 20),

                          // App Features Section
                          _buildSectionHeader('Features', Icons.apps),
                          _buildAnimatedSettingsItem(
                            title: 'Memo',
                            subtitle: 'Quick notes and reminders',
                            icon: Icons.note,
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation,
                                          secondaryAnimation) =>
                                      MemoScreen(),
                                  transitionsBuilder: (context, animation,
                                      secondaryAnimation, child) {
                                    return FadeTransition(
                                        opacity: animation, child: child);
                                  },
                                ),
                              );
                            },
                            delay: 400,
                          ),
                          _buildAnimatedSettingsItem(
                            title: 'Location Services',
                            subtitle: 'Manage location permissions',
                            icon: Icons.location_on,
                            onTap: () {
                              // TODO: Navigate to location settings
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Location Services - Coming Soon!')),
                              );
                            },
                            delay: 450,
                          ),
                          _buildAnimatedSettingsItem(
                            title: 'Auto Backup',
                            subtitle: 'Automatically backup your data',
                            icon: Icons.backup,
                            onTap: () {
                              setState(() {
                                _autoBackup = !_autoBackup;
                              });
                              _saveUserPreference('autoBackup', _autoBackup);
                              HapticFeedback.lightImpact();
                            },
                            trailing: Switch.adaptive(
                              value: _autoBackup,
                              onChanged: (value) {
                                setState(() {
                                  _autoBackup = value;
                                });
                                _saveUserPreference('autoBackup', value);
                                HapticFeedback.lightImpact();
                              },
                            ),
                            delay: 500,
                          ),

                          const SizedBox(height: 20),

                          // Support Section
                          _buildSectionHeader('Support & About', Icons.help),
                          _buildAnimatedSettingsItem(
                            title: 'Help & Support',
                            subtitle: 'Get help and contact support',
                            icon: Icons.help_outline,
                            onTap: () {
                              // TODO: Navigate to help page
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Help & Support - Coming Soon!')),
                              );
                            },
                            delay: 550,
                          ),
                          _buildAnimatedSettingsItem(
                            title: 'About LifeNext',
                            subtitle: 'App version and information',
                            icon: Icons.info_outline,
                            onTap: () {
                              // TODO: Show about dialog
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  title: const Text('About LifeNext'),
                                  content: const Text(
                                      'LifeNext v1.0.0\nDeveloped with ❤️ for better life management'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            delay: 600,
                          ),
                          _buildAnimatedSettingsItem(
                            title: 'About RCOP',
                            subtitle: 'Learn more about RCOP',
                            icon: Icons.business,
                            onTap: () {
                              // TODO: Show RCOP info dialog
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  title: const Text('About RCOP'),
                                  content: const Text(
                                      'RCOP - Your trusted partner in life management solutions.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            delay: 650,
                          ),
                          _buildAnimatedSettingsItem(
                            title: 'Rate App',
                            subtitle: 'Rate us on the app store',
                            icon: Icons.star_outline,
                            onTap: () {
                              // TODO: Open app store rating
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Thank you for your support! 🌟'),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            delay: 700,
                          ),

                          const SizedBox(height: 30),

                          // Logout Button
                          TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 750),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 30 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      onPressed: () =>
                                          _showLogoutDialog(context),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.logout, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Logout',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSettingsItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
    int delay = 0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing ??
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
