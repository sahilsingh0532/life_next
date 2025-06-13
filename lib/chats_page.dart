import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'settings.dart'; // Import settings page

class ChatsPage extends StatefulWidget {
  final Color bgColor;

  const ChatsPage({Key? key, required this.bgColor}) : super(key: key);

  @override
  _ChatsPageState createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage>
    with SingleTickerProviderStateMixin {
  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // State variables
  String _selectedUserId = '';
  String _selectedUserName = '';
  bool _isAddFriendMode = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Set<String> _selectedFriends = {};
  List<String> _selectedMessages = [];
  bool _isSelectionMode = false;
  String? _chatBackgroundUrl;

  // Vulgar words filter
  final List<String> vulgarWords = [
    'badword1',
    'badword2',
    'anotherbadword',
    'kutta'
  ];

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadChatBackground();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Navigate to settings page
  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          userId: currentUser?.uid ?? '',
          userName: currentUser?.displayName ?? 'User',
        ),
      ),
    );
  }

  // Search users functionality
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
          .where('email', isGreaterThanOrEqualTo: email.toLowerCase())
          .where('email', isLessThanOrEqualTo: email.toLowerCase() + '\uf8ff')
          .limit(10)
          .get();

      if (!mounted) return;

      setState(() {
        _searchResults = result.docs
            .where((doc) => doc.id != currentUser?.uid)
            .map((doc) => {
                  'id': doc.id,
                  'email': doc.get('email'),
                  'name': doc.get('firstName') ?? 'Unknown',
                  'lastName': doc.get('lastName') ?? '',
                })
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showSnackBar('Error searching users: $e');
    }
  }

  // Friend request functionality
  Future<void> _sendFriendRequest(String receiverId) async {
    if (receiverId == currentUser?.uid) return;

    try {
      final existing = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUser?.uid)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) {
        _showSnackBar('Friend request already sent');
        return;
      }

      await _firestore.collection('friendRequests').add({
        'senderId': currentUser?.uid,
        'receiverId': receiverId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Friend request sent');
    } catch (e) {
      _showSnackBar('Error sending request: $e');
    }
  }

  Future<void> _acceptFriendRequest(String requestId, String senderId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).update({
        'status': 'accepted',
      });

      await _firestore.collection('users').doc(currentUser?.uid).update({
        'friends': FieldValue.arrayUnion([senderId])
      });

      await _firestore.collection('users').doc(senderId).update({
        'friends': FieldValue.arrayUnion([currentUser?.uid])
      });

      _showSnackBar('Friend request accepted!');
    } catch (e) {
      _showSnackBar('Error accepting friend request: $e');
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).delete();
      _showSnackBar('Friend request rejected');
    } catch (e) {
      _showSnackBar('Error rejecting request: $e');
    }
  }

  // Chat background functionality
  Future<void> _loadChatBackground() async {
    if (_selectedUserId.isEmpty) return;

    try {
      final doc = await _firestore
          .collection('chatBackgrounds')
          .doc('${currentUser?.uid}_${_selectedUserId}')
          .get();

      if (doc.exists) {
        setState(() {
          _chatBackgroundUrl = doc.data()?['backgroundUrl'];
        });
      }
    } catch (e) {
      print('Error loading chat background: $e');
    }
  }

  Future<void> _changeChatBackground() async {
    final XFile? image =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      // Show loading indicator
      _showLoadingDialog('Uploading image...');

      final ref =
          _storage.ref().child('chat_backgrounds/${DateTime.now()}.jpg');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      await _firestore
          .collection('chatBackgrounds')
          .doc('${currentUser?.uid}_${_selectedUserId}')
          .set({
        'backgroundUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Dismiss loading dialog
      Navigator.pop(context);

      setState(() {
        _chatBackgroundUrl = url;
      });

      _showSnackBar('Chat background updated');
    } catch (e) {
      // Dismiss loading dialog if there's an error
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Error changing background: $e');
    }
  }

  // Friend management functionality
  Future<void> _confirmAndDeleteSelectedFriends() async {
    if (_selectedFriends.isEmpty) return;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Friend'),
        content:
            Text('Are you sure you want to delete the selected friend(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSelectedFriends();
    }
  }

  Future<void> _deleteSelectedFriends() async {
    WriteBatch batch = _firestore.batch();
    try {
      for (String friendId in _selectedFriends) {
        var userDoc = _firestore.collection('users').doc(currentUser?.uid);
        var friendDoc = _firestore.collection('users').doc(friendId);

        batch.update(userDoc, {
          'friends': FieldValue.arrayRemove([friendId])
        });

        batch.update(friendDoc, {
          'friends': FieldValue.arrayRemove([currentUser?.uid])
        });
      }

      await batch.commit();

      setState(() {
        _selectedFriends.clear();
        _isSelectionMode = false;
      });

      _showSnackBar('Selected friends removed');
    } catch (e) {
      _showSnackBar('Error removing friends: $e');
    }
  }

  Future<void> _confirmRemoveFriend() async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _removeFriend();
    }
  }

  Future<void> _removeFriend() async {
    try {
      await _firestore.collection('users').doc(currentUser?.uid).update({
        'friends': FieldValue.arrayRemove([_selectedUserId])
      });

      await _firestore.collection('users').doc(_selectedUserId).update({
        'friends': FieldValue.arrayRemove([currentUser?.uid])
      });

      setState(() {
        _selectedUserId = '';
        _selectedUserName = '';
      });

      _showSnackBar('Friend removed');
    } catch (e) {
      _showSnackBar('Error removing friend: $e');
    }
  }

  // Chat management functionality
  Future<void> _clearChat() async {
    try {
      final messages = await _firestore
          .collection('users')
          .doc(currentUser?.uid)
          .collection('chats')
          .doc(_selectedUserId)
          .collection('messages')
          .get();

      for (var message in messages.docs) {
        await message.reference.delete();
      }

      _showSnackBar('Chat cleared');
    } catch (e) {
      _showSnackBar('Error clearing chat: $e');
    }
  }

  Future<void> _deleteSelectedMessages() async {
    try {
      for (String messageId in _selectedMessages) {
        await _firestore
            .collection('users')
            .doc(currentUser?.uid)
            .collection('chats')
            .doc(_selectedUserId)
            .collection('messages')
            .doc(messageId)
            .delete();

        await _firestore
            .collection('users')
            .doc(_selectedUserId)
            .collection('chats')
            .doc(currentUser?.uid)
            .collection('messages')
            .doc(messageId)
            .delete();
      }

      setState(() {
        _selectedMessages.clear();
      });

      _showSnackBar('Selected messages deleted');
    } catch (e) {
      _showSnackBar('Error deleting messages: $e');
    }
  }

  // Media functionality
  Future<void> _pickAndSendMedia(ImageSource source, bool isVideo) async {
    try {
      final XFile? media = isVideo
          ? await _imagePicker.pickVideo(source: source)
          : await _imagePicker.pickImage(source: source);

      if (media == null) return;

      // Show loading indicator
      _showLoadingDialog('Sending media...');

      final ref = _storage.ref().child(
          'chat_media/${currentUser?.uid}/${DateTime.now()}.${isVideo ? 'mp4' : 'jpg'}');

      await ref.putFile(File(media.path));
      final url = await ref.getDownloadURL();

      await _sendMessage(
        mediaUrl: url,
        mediaType: isVideo ? 'video' : 'image',
      );

      // Dismiss loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Dismiss loading dialog if there's an error
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showSnackBar('Error sending media: $e');
    }
  }

  // Message handling
  bool containsVulgarContent(String message) {
    for (String badWord in vulgarWords) {
      if (message.toLowerCase().contains(badWord)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _sendMessage(
      {String? text, String? mediaUrl, String? mediaType}) async {
    if ((text?.isEmpty ?? true) && mediaUrl == null) return;
    if (_selectedUserId.isEmpty) return;

    // Check for vulgar content
    if (text != null && containsVulgarContent(text)) {
      _showSnackBar(
          'Your message contains inappropriate words and cannot be sent.');
      return;
    }

    try {
      final messageData = {
        'text': text,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'senderId': currentUser?.uid,
        'receiverId': _selectedUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isEdited': false,
      };

      // Store message for both users
      await _firestore
          .collection('users')
          .doc(currentUser?.uid)
          .collection('chats')
          .doc(_selectedUserId)
          .collection('messages')
          .add(messageData);

      await _firestore
          .collection('users')
          .doc(_selectedUserId)
          .collection('chats')
          .doc(currentUser?.uid)
          .collection('messages')
          .add(messageData);

      _messageController.clear();
      _scrollController.jumpTo(0);
    } catch (e) {
      _showSnackBar('Error sending message: $e');
    }
  }

  // User reporting
  Future<void> _reportUser(String userId) async {
    try {
      await _firestore.collection('reports').add({
        'reportedUserId': userId,
        'reporterId': currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _showSnackBar('User reported successfully');
    } catch (e) {
      _showSnackBar('Error reporting user: $e');
    }
  }

  // UI Helper methods
  void _showFriendOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chat Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildOptionTile(
              icon: Icons.person,
              title: 'View Profile',
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement view profile
              },
            ),
            _buildOptionTile(
              icon: Icons.delete,
              title: 'Remove Friend',
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveFriend();
              },
            ),
            _buildOptionTile(
              icon: Icons.delete_sweep,
              title: 'Clear Chat',
              onTap: () {
                Navigator.pop(context);
                _clearChat();
              },
            ),
            _buildOptionTile(
              icon: Icons.wallpaper,
              title: 'Change Background',
              onTap: () {
                Navigator.pop(context);
                _changeChatBackground();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    ).animate().fadeIn().slideX(begin: 0.2, end: 0);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(10),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  PopupMenuButton _buildPopupMenu(String userId) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.flag, size: 18),
              const SizedBox(width: 8),
              const Text('Report'),
            ],
          ),
          onTap: () => _reportUser(userId),
        ),
      ],
    );
  }

  Widget _buildMediaOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    ).animate().fadeIn().scale(delay: 100.ms);
  }

  // UI Building methods
  Widget _buildAddFriendView(
      Color cardColor, Color textColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add app bar with back button
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: Icon(Icons.arrow_back, color: textColor),
                onPressed: () {
                  setState(() {
                    _isAddFriendMode = false;
                    _searchController.clear();
                    _searchResults = [];
                  });
                },
              ),
              SizedBox(width: 12),
              Text(
                'Add Friends',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: InputDecoration(
              hintText: 'Search by email...',
              hintStyle: TextStyle(color: subtitleColor),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search, color: subtitleColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: subtitleColor),
                      onPressed: () {
                        _searchController.clear();
                        _searchUsers('');
                      },
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            style: TextStyle(color: textColor),
          ),
        ),

        // Rest of the add friend view remains the same
        if (_isSearching)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!_isSearching && _searchResults.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Search Results',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final fullName = '${user['name']} ${user['lastName']}';
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                    color: cardColor,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          user['name'][0].toUpperCase(),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        fullName,
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        user['email'],
                        style: TextStyle(color: subtitleColor),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _sendFriendRequest(user['id']),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Add Friend'),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: 100 * index));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Pending Friend Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('friendRequests')
                .where('receiverId', isEqualTo: currentUser?.uid)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hourglass_empty,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'No pending requests',
                        style: TextStyle(fontSize: 16, color: subtitleColor),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final request = snapshot.data!.docs[index];
                  return FutureBuilder<DocumentSnapshot>(
                    future: _firestore
                        .collection('users')
                        .doc(request['senderId'])
                        .get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(
                              userData['firstName'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            '${userData['firstName']} ${userData['lastName']}',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Sent you a friend request',
                            style: TextStyle(color: subtitleColor),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                tooltip: 'Accept',
                                onPressed: () => _acceptFriendRequest(
                                    request.id, request['senderId']),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                tooltip: 'Reject',
                                onPressed: () =>
                                    _rejectFriendRequest(request.id),
                              ),
                            ],
                          ),
                        ),
                      ).animate().slideX(
                            begin: -0.5,
                            duration: 400.ms,
                            curve: Curves.easeOut,
                          );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsList(
      Color cardColor, Color textColor, Color subtitleColor) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(currentUser?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = List<String>.from(snapshot.data?['friends'] ?? []);
        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: subtitleColor)
                    .animate()
                    .scale(duration: 400.ms),
                const SizedBox(height: 24),
                Text(
                  'No friends yet',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ).animate().fadeIn().slideY(begin: 0.3),
                const SizedBox(height: 12),
                Text(
                  'Tap the + button to add friends!',
                  style: TextStyle(color: subtitleColor, fontSize: 16),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: Icon(Icons.person_add),
                  label: Text('Add Friends'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () => setState(() => _isAddFriendMode = true),
                ).animate().fadeIn(delay: 400.ms).scale(),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: friends)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final friend = snapshot.data!.docs[index];
                final isSelected = _selectedFriends.contains(friend.id);
                final firstName = friend['firstName'] ?? '';
                final lastName = friend['lastName'] ?? '';
                final initial =
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : cardColor,
                  child: ListTile(
                    onTap: _isSelectionMode
                        ? () {
                            setState(() {
                              if (isSelected) {
                                _selectedFriends.remove(friend.id);
                              } else {
                                _selectedFriends.add(friend.id);
                              }

                              if (_selectedFriends.isEmpty) {
                                _isSelectionMode = false;
                              }
                            });
                          }
                        : () {
                            setState(() {
                              _selectedUserId = friend.id;
                              _selectedUserName = '$firstName $lastName';
                              _loadChatBackground();
                            });
                          },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedFriends.add(friend.id);
                        });
                      }
                    },
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        initial,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      '$firstName $lastName',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    subtitle: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .doc(currentUser?.uid)
                          .collection('chats')
                          .doc(friend.id)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .limit(1)
                          .snapshots(),
                      builder: (context, msgSnapshot) {
                        if (!msgSnapshot.hasData ||
                            msgSnapshot.data!.docs.isEmpty) {
                          return Text(
                            'No messages yet',
                            style: TextStyle(color: subtitleColor),
                          );
                        }

                        final lastMessage = msgSnapshot.data!.docs.first;
                        String messagePreview = '';

                        if (lastMessage['mediaUrl'] != null) {
                          final mediaType = lastMessage['mediaType'] ?? 'image';
                          messagePreview = '$mediaType';
                        } else {
                          messagePreview = lastMessage['text'] ?? '';
                          if (messagePreview.length > 30) {
                            messagePreview =
                                messagePreview.substring(0, 30) + '...';
                          }
                        }

                        return Text(
                          messagePreview,
                          style: TextStyle(color: subtitleColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    trailing: _isSelectionMode
                        ? isSelected
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).primaryColor)
                            : Icon(Icons.circle_outlined)
                        : null,
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: 50 * index));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSelectedChatView(
      Color cardColor, Color textColor, Color subtitleColor) {
    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(() {
                  _selectedUserId = '';
                  _selectedUserName = '';
                  _chatBackgroundUrl = null;
                }),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back, color: textColor),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  _selectedUserName.isNotEmpty
                      ? _selectedUserName[0].toUpperCase()
                      : '',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedUserName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: textColor),
                onPressed: _showFriendOptions,
              ),
            ],
          ),
        ),

        // Chat messages
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              image: _chatBackgroundUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_chatBackgroundUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(currentUser?.uid)
                  .collection('chats')
                  .doc(_selectedUserId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: subtitleColor),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: subtitleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say hi to start a conversation!',
                          style: TextStyle(color: subtitleColor),
                        ),
                      ],
                    ).animate().fadeIn().scale(),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final message = snapshot.data!.docs[index];
                    final isMe = message['senderId'] == currentUser?.uid;
                    final isSelected = _selectedMessages.contains(message.id);

                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          if (_selectedMessages.contains(message.id)) {
                            _selectedMessages.remove(message.id);
                          } else {
                            _selectedMessages.add(message.id);
                          }
                        });
                      },
                      onTap: _selectedMessages.isNotEmpty
                          ? () {
                              setState(() {
                                if (_selectedMessages.contains(message.id)) {
                                  _selectedMessages.remove(message.id);
                                } else {
                                  _selectedMessages.add(message.id);
                                }
                              });
                            }
                          : null,
                      child: Container(
                        margin: EdgeInsets.only(
                          bottom: 8,
                          left: isMe ? 64 : 0,
                          right: isMe ? 0 : 64,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor.withOpacity(0.3)
                              : isMe
                                  ? Theme.of(context).primaryColor
                                  : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (message['mediaUrl'] != null) ...[
                                message['mediaType'] == 'image'
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          message['mediaUrl'],
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              height: 200,
                                              width: double.infinity,
                                              color: Colors.grey[300],
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  value: loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                      : null,
                                                ),
                                              ),
                                            );
                                          },
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Container(
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.play_circle_outline),
                                              SizedBox(width: 8),
                                              Text('Video'),
                                            ],
                                          ),
                                        ),
                                      ),
                                SizedBox(height: 8),
                              ],
                              if (message['text'] != null &&
                                  message['text'] != '')
                                Text(
                                  message['text'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    message['timestamp'] != null
                                        ? _formatTimestamp(
                                            message['timestamp'].toDate())
                                        : 'Sending...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          isMe ? Colors.white70 : subtitleColor,
                                    ),
                                  ),
                                  if (message['isEdited'] == true) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '(edited)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: isMe
                                            ? Colors.white70
                                            : subtitleColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 200.ms),
                    );
                  },
                );
              },
            ),
          ),
        ),

        // Message input area
        _selectedMessages.isNotEmpty
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: cardColor,
                child: Row(
                  children: [
                    Text(
                      '${_selectedMessages.length} selected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _deleteSelectedMessages,
                      tooltip: 'Delete selected messages',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _selectedMessages.clear()),
                      tooltip: 'Cancel selection',
                    ),
                  ],
                ),
              )
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) => Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Share Media',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                _buildMediaOption(
                                  Icons.photo_library,
                                  'Gallery Image',
                                  () => _pickAndSendMedia(
                                      ImageSource.gallery, false),
                                ),
                                _buildMediaOption(
                                  Icons.camera_alt,
                                  'Take Photo',
                                  () => _pickAndSendMedia(
                                      ImageSource.camera, false),
                                ),
                                _buildMediaOption(
                                  Icons.videocam,
                                  'Gallery Video',
                                  () => _pickAndSendMedia(
                                      ImageSource.gallery, true),
                                ),
                                _buildMediaOption(
                                  Icons.video_camera_back,
                                  'Record Video',
                                  () => _pickAndSendMedia(
                                      ImageSource.camera, true),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: subtitleColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.1),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        style: TextStyle(color: textColor),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () =>
                          _sendMessage(text: _messageController.text),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (dateToCheck == today) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine colors based on theme
    final brightness = Theme.of(context).brightness;
    final cardColor =
        brightness == Brightness.dark ? Colors.grey[800]! : Colors.white;
    final textColor =
        brightness == Brightness.dark ? Colors.white : Colors.black87;
    final subtitleColor =
        brightness == Brightness.dark ? Colors.grey[400]! : Colors.grey[700]!;

    return Scaffold(
      backgroundColor: widget.bgColor,
      appBar: AppBar(
        title: Text(_selectedUserId.isEmpty ? 'Chats' : _selectedUserName),
        actions: _selectedUserId.isEmpty
            ? _isSelectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _confirmAndDeleteSelectedFriends,
                      tooltip: 'Delete selected friends',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _isSelectionMode = false;
                        _selectedFriends.clear();
                      }),
                      tooltip: 'Cancel selection',
                    ),
                  ]
                : [
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: _navigateToSettings,
                      tooltip: 'Settings',
                    ),
                  ]
            : [
                _buildPopupMenu(_selectedUserId),
              ],
      ),
      floatingActionButton:
          _selectedUserId.isEmpty && !_isSelectionMode && !_isAddFriendMode
              ? FloatingActionButton(
                  onPressed: () => setState(() => _isAddFriendMode = true),
                  tooltip: 'Add Friend',
                  child: const Icon(Icons.person_add),
                ).animate().scale()
              : null,
      body: _selectedUserId.isNotEmpty
          ? _buildSelectedChatView(cardColor, textColor, subtitleColor)
          : _isAddFriendMode
              ? _buildAddFriendView(cardColor, textColor, subtitleColor)
              : _buildFriendsList(cardColor, textColor, subtitleColor),
    );
  }
}
