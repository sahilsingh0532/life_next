import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'group_chat_screen.dart';
import 'create_group_dialog.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _username = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _selectedUsers = [];
  bool _isSearching = false;
  int _groupCount = 0;

  // Colors for gradient
  final List<Color> _gradientColors = [
    const Color(0xFF1A237E),
    const Color(0xFF3949AB),
    const Color(0xFF5C6BC0),
  ];

  // Colors for group cards
  final List<List<Color>> _cardGradients = [
    [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)],
    [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
    [const Color(0xFF00695C), const Color(0xFF26A69A)],
    [const Color(0xFFE65100), const Color(0xFFFF9800)],
    [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  Future<void> _loadUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userData =
            await _firestore.collection('users').doc(user.uid).get();

        if (userData.exists) {
          setState(() {
            _username = userData.get('firstName') ?? 'User';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _searchUsers(String email) async {
    if (email.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: email)
          .where('email', isLessThanOrEqualTo: email + '\uf8ff')
          .limit(10)
          .get();

      setState(() {
        _searchResults = result.docs
            .map((doc) => {
                  'id': doc.id,
                  'email': doc.get('email'),
                  'name': doc.get('firstName'),
                })
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching users: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _createGroup() async {
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select users for the group'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => CreateGroupDialog(selectedUsers: _selectedUsers),
    );

    if (result != null && result.isNotEmpty) {
      try {
        // Add current user to the group
        _selectedUsers.add(_auth.currentUser!.uid);

        // Add group to Firestore
        DocumentReference groupRef = await _firestore.collection('groups').add({
          'name': result,
          'members': _selectedUsers,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _auth.currentUser!.uid,
          'lastMessage': null,
          'lastMessageTime': null,
        });

        setState(() {
          _selectedUsers = [];
        });

        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  GroupChatScreen(
                groupId: groupRef.id,
                groupName: result,
                groupCreatorId: _auth.currentUser!.uid,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                var begin = const Offset(1.0, 0.0);
                var end = Offset.zero;
                var curve = Curves.easeInOutCubic;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Group created successfully!'),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating group: $e'),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Color _getRandomColor() {
    final random = math.Random();
    return Color.fromRGBO(
      random.nextInt(200) + 55,
      random.nextInt(200) + 55,
      random.nextInt(200) + 55,
      1,
    );
  }

  List<Color> _getCardGradient(int index) {
    return _cardGradients[index % _cardGradients.length];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isSearching) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
            _searchController.clear();
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _gradientColors,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        radius: 24,
                        child: Text(
                          _username.isNotEmpty
                              ? _username[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ).animate().scale(
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome,',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
                            Text(
                              _username,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 200.ms)
                                .slideY(
                                  begin: 0.2,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                  duration: 500.ms,
                                ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications,
                            color: Colors.white),
                        onPressed: () {},
                      ).animate().scale(
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                            delay: 300.ms,
                          ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Opacity(
                              opacity: _fadeAnimation.value,
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Groups Header with Count
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Groups',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      StreamBuilder<QuerySnapshot>(
                                        stream: _firestore
                                            .collection('groups')
                                            .where('members',
                                                arrayContains:
                                                    _auth.currentUser?.uid)
                                            .snapshots(),
                                        builder: (context, snapshot) {
                                          int count = 0;
                                          if (snapshot.hasData) {
                                            count = snapshot.data!.docs.length;
                                            _groupCount = count;
                                          }
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF5C6BC0),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '$count',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ).animate().scale(
                                                duration: 300.ms,
                                                curve: Curves.elasticOut,
                                                delay: 500.ms,
                                              );
                                        },
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      // Navigate to Groups screen or show all groups
                                    },
                                    icon: const Icon(Icons.arrow_forward),
                                    label: const Text('See all'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF3949AB),
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(delay: 400.ms, duration: 400.ms),
                                ],
                              ),

                              // Search Bar with Create Group Button
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(25),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          controller: _searchController,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Search friends by email...',
                                            hintStyle: TextStyle(
                                                color: Colors.grey[400]),
                                            prefixIcon: const Icon(Icons.search,
                                                color: Color(0xFF5C6BC0)),
                                            suffixIcon: _searchController
                                                    .text.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(
                                                        Icons.clear,
                                                        color:
                                                            Color(0xFF5C6BC0)),
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      _searchUsers('');
                                                    },
                                                  )
                                                : null,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                              borderSide: BorderSide.none,
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[100],
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 12),
                                          ),
                                          onChanged: _searchUsers,
                                        ),
                                      )
                                          .animate()
                                          .fadeIn(
                                              delay: 200.ms, duration: 400.ms)
                                          .slideX(
                                            begin: -0.1,
                                            end: 0,
                                            delay: 200.ms,
                                            duration: 400.ms,
                                          ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFF3949AB),
                                            const Color(0xFF5C6BC0)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(50),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF3949AB)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.group_add,
                                            color: Colors.white),
                                        onPressed: _createGroup,
                                        tooltip: 'Create Group',
                                      ),
                                    ).animate().scale(
                                          duration: 400.ms,
                                          curve: Curves.easeOutBack,
                                          delay: 400.ms,
                                        ),
                                  ],
                                ),
                              ),

                              // Search Results
                              if (_isSearching)
                                Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      const Color(0xFF3949AB),
                                    ),
                                  ),
                                ),

                              if (_searchResults.isNotEmpty)
                                Container(
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _searchResults.length,
                                      itemBuilder: (context, index) {
                                        final user = _searchResults[index];
                                        final bool isSelected =
                                            _selectedUsers.contains(user['id']);
                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: _getRandomColor(),
                                            child: Text(
                                              user['name'][0].toUpperCase(),
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                          title: Text(
                                            user['name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(user['email']),
                                          trailing: Checkbox(
                                            value: isSelected,
                                            activeColor:
                                                const Color(0xFF3949AB),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  _selectedUsers
                                                      .add(user['id']);
                                                } else {
                                                  _selectedUsers
                                                      .remove(user['id']);
                                                }
                                              });
                                            },
                                          ),
                                        )
                                            .animate()
                                            .fadeIn(
                                              duration: 300.ms,
                                              delay: Duration(
                                                  milliseconds: 50 * index),
                                            )
                                            .slideY(
                                              begin: 0.1,
                                              end: 0,
                                              duration: 300.ms,
                                              delay: Duration(
                                                  milliseconds: 50 * index),
                                              curve: Curves.easeOutCubic,
                                            );
                                      },
                                    ),
                                  ),
                                ).animate().fadeIn(duration: 300.ms).scale(
                                      begin: Offset(0,
                                          0.1),
                                      end: Offset(0, 0),
                                      duration: 300.ms,
                                      curve: Curves.easeOutCubic,
                                    ),
                              // Groups List
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: _firestore
                                      .collection('groups')
                                      .where('members',
                                          arrayContains: _auth.currentUser?.uid)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    if (!snapshot.hasData ||
                                        snapshot.data!.docs.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.group_off,
                                              size: 64,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No groups yet',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Create a new group to start chatting',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ).animate().fadeIn(duration: 600.ms),
                                      );
                                    }

                                    final groups = snapshot.data!.docs;
                                    return ListView.builder(
                                      itemCount: groups.length,
                                      itemBuilder: (context, index) {
                                        final group = groups[index];
                                        final memberCount =
                                            (group.get('members') as List)
                                                .length;
                                        final gradientColors =
                                            _getCardGradient(index);

                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: gradientColors,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: gradientColors[0]
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  PageRouteBuilder(
                                                    pageBuilder: (context,
                                                            animation,
                                                            secondaryAnimation) =>
                                                        GroupChatScreen(
                                                      groupId: group.id,
                                                      groupName:
                                                          group.get('name'),
                                                      groupCreatorId: group
                                                          .get('createdBy'),
                                                    ),
                                                    transitionsBuilder:
                                                        (context,
                                                            animation,
                                                            secondaryAnimation,
                                                            child) {
                                                      var begin = const Offset(
                                                          1.0, 0.0);
                                                      var end = Offset.zero;
                                                      var curve =
                                                          Curves.easeInOutCubic;
                                                      var tween = Tween(
                                                              begin: begin,
                                                              end: end)
                                                          .chain(CurveTween(
                                                              curve: curve));
                                                      return SlideTransition(
                                                        position: animation
                                                            .drive(tween),
                                                        child: child,
                                                      );
                                                    },
                                                    transitionDuration:
                                                        const Duration(
                                                            milliseconds: 500),
                                                  ),
                                                );
                                              },
                                              splashColor:
                                                  Colors.white.withOpacity(0.1),
                                              highlightColor:
                                                  Colors.white.withOpacity(0.1),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 60,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          group
                                                              .get('name')[0]
                                                              .toUpperCase(),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 24,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            group.get('name'),
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.people,
                                                                color: Colors
                                                                    .white70,
                                                                size: 16,
                                                              ),
                                                              const SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                '$memberCount members',
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: const Icon(
                                                        Icons.arrow_forward_ios,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                            .animate()
                                            .fadeIn(
                                              duration: 400.ms,
                                              delay: Duration(
                                                  milliseconds: 100 * index),
                                            )
                                            .slideX(
                                              begin: 0.1,
                                              end: 0,
                                              duration: 400.ms,
                                              delay: Duration(
                                                  milliseconds: 100 * index),
                                              curve: Curves.easeOutCubic,
                                            );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
