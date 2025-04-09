import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ChatsPage extends StatefulWidget {
  final Color bgColor;

  const ChatsPage({Key? key, required this.bgColor}) : super(key: key);

  @override
  _ChatsPageState createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  late AnimationController _animationController;

  String _selectedUserId = '';
  String _selectedUserName = '';
  bool _isAddFriendMode = false;
  bool _isSearching = false; // ✅ this prevents the "undefined" error
  List<Map<String, dynamic>> _searchResults = []; // ✅ needed for results
  Set<String> _selectedFriends = {};
  List<String> _selectedMessages = [];
  bool _isSelectionMode = false;
  String? _chatBackgroundUrl;

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
            .where(
                (doc) => doc.id != currentUser?.uid) // optional: exclude self
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: $e')),
      );
    }
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request already sent')),
        );
        return;
      }

      await _firestore.collection('friendRequests').add({
        'senderId': currentUser?.uid,
        'receiverId': receiverId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending request: $e')),
      );
    }
  }

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

      setState(() {
        _chatBackgroundUrl = url;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error changing background: $e')),
      );
    }
  }

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected friends removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing friends: $e')),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing chat: $e')),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing friend: $e')),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected messages deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting messages: $e')),
      );
    }
  }

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
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement view profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Remove Friend'),
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveFriend();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Clear Chat'),
              onTap: () {
                Navigator.pop(context);
                _clearChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper),
              title: const Text('Change Background'),
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

  Widget _buildAddFriendView(
      Color cardColor, Color textColor, Color subtitleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search, color: subtitleColor),
            ),
            style: TextStyle(color: textColor),
          ),
        ),
        if (_isSearching) const Center(child: CircularProgressIndicator()),
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
                    color: cardColor,
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(
                        fullName,
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        user['email'],
                        style: TextStyle(color: subtitleColor),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _sendFriendRequest(user['id']),
                        child: const Text('Add Friend'),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          borderRadius: BorderRadius.circular(12),
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
                            style: TextStyle(color: textColor),
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

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting request: $e')),
      );
    }
  }

  PopupMenuButton _buildPopupMenu(String userId) {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: const Text('Report'),
          onTap: () => _reportUser(userId),
        ),
      ],
    );
  }

  Future<void> _reportUser(String userId) async {
    try {
      await _firestore.collection('reports').add({
        'reportedUserId': userId,
        'reporterId': currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User reported successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error reporting user: $e')));
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting friend request: $e')),
      );
    }
  }

  Future<void> _pickAndSendMedia(ImageSource source, bool isVideo) async {
    try {
      final XFile? media = isVideo
          ? await _imagePicker.pickVideo(source: source)
          : await _imagePicker.pickImage(source: source);

      if (media == null) return;

      final ref = _storage.ref().child(
          'chat_media/${currentUser?.uid}/${DateTime.now()}.${isVideo ? 'mp4' : 'jpg'}');

      await ref.putFile(File(media.path));
      final url = await ref.getDownloadURL();

      await _sendMessage(
        mediaUrl: url,
        mediaType: isVideo ? 'video' : 'image',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending media: $e')),
      );
    }
  }

  Future<void> _sendMessage(
      {String? text, String? mediaUrl, String? mediaType}) async {
    if ((text?.isEmpty ?? true) && mediaUrl == null) return;
    if (_selectedUserId.isEmpty) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900]! : Colors.grey[100]!;
    final cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: AppBarTheme(
          backgroundColor: isDarkMode
              ? const Color.fromARGB(255, 209, 5, 250)
              : const Color.fromARGB(255, 53, 204, 241),
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          titleTextStyle: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: _selectedUserId.isNotEmpty,
          title: Text(
            _selectedUserId.isEmpty
                ? _isSelectionMode
                    ? '${_selectedFriends.length} Selected'
                    : 'Chats'
                : _selectedUserName,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          leading: _selectedUserId.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    _selectedUserId = '';
                    _selectedUserName = '';
                    _selectedMessages.clear();
                  }),
                )
              : null,
          actions: [
            if (_selectedUserId.isEmpty && !_isAddFriendMode)
              if (_isSelectionMode && _selectedFriends.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedFriends,
                ),
            if (_selectedUserId.isEmpty && !_isSelectionMode)
              IconButton(
                icon: Icon(_isAddFriendMode ? Icons.close : Icons.person_add),
                onPressed: () =>
                    setState(() => _isAddFriendMode = !_isAddFriendMode),
              )
                  .animate()
                  .scale(duration: 200.ms, curve: Curves.easeOut)
                  .then()
                  .shimmer(duration: 700.ms),
            if (_selectedUserId.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: _showFriendOptions,
              ),
          ],
        ),
        body: Container(
          decoration: _chatBackgroundUrl != null
              ? BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(_chatBackgroundUrl!),
                    fit: BoxFit.cover,
                    opacity: 0.3,
                  ),
                )
              : null,
          child: Column(
            children: [
              Expanded(
                child: _selectedUserId.isEmpty
                    ? _isAddFriendMode
                        ? _buildAddFriendView(
                            cardColor, textColor, subtitleColor)
                        : _buildFriendsList(cardColor, textColor, subtitleColor)
                    : _buildChatView(cardColor, textColor, subtitleColor),
              ),
              if (_selectedUserId.isNotEmpty && _selectedMessages.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${_selectedMessages.length} selected',
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: _deleteSelectedMessages,
                      ),
                    ],
                  ),
                ),
              if (_selectedUserId.isNotEmpty)
                _buildMessageInput(cardColor, textColor, subtitleColor),
            ],
          ),
        ),
      ),
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
                Icon(Icons.people_outline, size: 64, color: subtitleColor)
                    .animate()
                    .scale(duration: 400.ms),
                const SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ).animate().fadeIn().slideY(begin: 0.3),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to add friends!',
                  style: TextStyle(color: subtitleColor),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
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
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final friend = snapshot.data!.docs[index];
                final isSelected = _selectedFriends.contains(friend.id);

                return ListTile(
                  title: Text(
                    '${friend['firstName']} ${friend['lastName']}',
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    friend['email'],
                    style: TextStyle(color: subtitleColor),
                  ),
                  selected: isSelected,
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedFriends.add(friend.id);
                      });
                    }
                  },
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedFriends.remove(friend.id);
                          if (_selectedFriends.isEmpty) {
                            _isSelectionMode = false;
                          }
                        } else {
                          _selectedFriends.add(friend.id);
                        }
                      });
                    } else {
                      setState(() {
                        _selectedUserId = friend.id;
                        _selectedUserName =
                            '${friend['firstName']} ${friend['lastName']}';
                      });
                      _loadChatBackground();
                    }
                  },
                  trailing: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedFriends.add(friend.id);
                              } else {
                                _selectedFriends.remove(friend.id);
                                if (_selectedFriends.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              }
                            });
                          },
                        )
                      : null,
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 100 * index))
                    .slideX(begin: 0.2, end: 0);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatView(Color cardColor, Color textColor, Color subtitleColor) {
    return StreamBuilder<QuerySnapshot>(
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

        final messages = snapshot.data!.docs;
        return ListView.builder(
          reverse: true,
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message['senderId'] == currentUser?.uid;
            final isSelected = _selectedMessages.contains(message.id);

            return GestureDetector(
              onLongPress: isMe
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
              child: Stack(
                children: [
                  Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.withOpacity(0.3)
                            : isMe
                                ? Colors.blue
                                : cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? Border.all(color: Colors.blue, width: 2)
                            : null,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message['mediaUrl'] != null) ...[
                            if (message['mediaType'] == 'image')
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  message['mediaUrl'],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (message['text'] != null)
                              const SizedBox(height: 8),
                          ],
                          if (message['text'] != null)
                            Text(
                              message['text'],
                              style: TextStyle(
                                color: isMe ? Colors.white : textColor,
                                fontSize: 16,
                              ),
                            ),
                          if (message['isEdited'] == true)
                            Text(
                              '(edited)',
                              style: TextStyle(
                                color: isMe ? Colors.white70 : subtitleColor,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().slideX(
                        begin: isMe ? 0.2 : -0.2,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                  if (isSelected)
                    Positioned(
                      top: 0,
                      right: isMe ? 0 : null,
                      left: isMe ? null : 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput(
      Color cardColor, Color textColor, Color subtitleColor) {
    final bool hasText = _messageController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.attach_file, color: textColor),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  backgroundColor: Theme.of(context).cardColor,
                  builder: (context) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMediaOption(
                            Icons.photo,
                            'Send Image',
                            () =>
                                _pickAndSendMedia(ImageSource.gallery, false)),
                        _buildMediaOption(Icons.videocam, 'Send Video',
                            () => _pickAndSendMedia(ImageSource.gallery, true)),
                        _buildMediaOption(Icons.camera_alt, 'Take Photo',
                            () => _pickAndSendMedia(ImageSource.camera, false)),
                      ],
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: textColor),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: subtitleColor),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: hasText ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: GestureDetector(
                onTap: hasText
                    ? () => _sendMessage(text: _messageController.text)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).iconTheme.color),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
