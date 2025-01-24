import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatsPage extends StatefulWidget {
  final Color bgColor;

  const ChatsPage({Key? key, required this.bgColor}) : super(key: key);

  @override
  _ChatsPageState createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  String _selectedUserId = '';
  String _selectedUserName = '';
  bool _isAddFriendMode = false;
  List<Map<String, dynamic>> _searchResults = [];

  User? get currentUser => _auth.currentUser;

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedUserId.isEmpty)
      return;

    try {
      final timestamp = FieldValue.serverTimestamp();
      final messageData = {
        'text': _messageController.text.trim(),
        'senderId': currentUser?.uid,
        'receiverId': _selectedUserId,
        'timestamp': timestamp,
      };

      // Add to sender's messages
      await _firestore
          .collection('users')
          .doc(currentUser?.uid)
          .collection('chats')
          .doc(_selectedUserId)
          .collection('messages')
          .add(messageData);

      // Add to receiver's messages
      await _firestore
          .collection('users')
          .doc(_selectedUserId)
          .collection('chats')
          .doc(currentUser?.uid)
          .collection('messages')
          .add(messageData);

      _messageController.clear();
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThan: query + 'z')
          .get();

      setState(() {
        _searchResults = usersSnapshot.docs
            .where((doc) => doc.id != currentUser?.uid)
            .map((doc) => {
                  'id': doc.id,
                  'firstName': doc['firstName'],
                  'lastName': doc['lastName'],
                  'email': doc['email'],
                })
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: $e')),
      );
    }
  }

  Future<void> _addFriend(String userId) async {
    try {
      // Add to current user's friends
      await _firestore.collection('users').doc(currentUser?.uid).update({
        'friends': FieldValue.arrayUnion([userId])
      });

      // Add current user to friend's friends list
      await _firestore.collection('users').doc(userId).update({
        'friends': FieldValue.arrayUnion([currentUser?.uid])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend added successfully!')),
      );
      setState(() => _isAddFriendMode = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding friend: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedUserId.isNotEmpty) {
          setState(() {
            _selectedUserId = '';
            _selectedUserName = '';
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          backgroundColor: Colors.grey[850],
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_selectedUserId.isNotEmpty) {
                setState(() {
                  _selectedUserId = '';
                  _selectedUserName = '';
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            _selectedUserId.isEmpty ? 'Chats' : _selectedUserName,
            style: const TextStyle(fontSize: 20),
          ),
          actions: [
            if (_selectedUserId.isEmpty)
              IconButton(
                icon: Icon(_isAddFriendMode ? Icons.close : Icons.person_add),
                onPressed: () =>
                    setState(() => _isAddFriendMode = !_isAddFriendMode),
              ),
          ],
        ),
        body: _selectedUserId.isEmpty
            ? _isAddFriendMode
                ? _buildAddFriendView()
                : _buildFriendsList()
            : _buildChatView(),
      ),
    );
  }

  Widget _buildAddFriendView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: InputDecoration(
              hintText: 'Search by email...',
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(user['firstName'][0].toUpperCase()),
                ),
                title: Text('${user['firstName']} ${user['lastName']}'),
                subtitle: Text(user['email']),
                trailing: IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () => _addFriend(user['id']),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(currentUser?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final friends = List<String>.from(snapshot.data?['friends'] ?? []);
        if (friends.isEmpty) {
          return const Center(
            child: Text(
              'No friends yet.\nTap the + button to add friends!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
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
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(friend['firstName'][0].toUpperCase()),
                  ),
                  title: Text('${friend['firstName']} ${friend['lastName']}'),
                  subtitle: Text(friend['email']),
                  onTap: () {
                    setState(() {
                      _selectedUserId = friend.id;
                      _selectedUserName =
                          '${friend['firstName']} ${friend['lastName']}';
                    });
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
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

              final messages = snapshot.data!.docs;
              return ListView.builder(
                reverse: true,
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message['senderId'] == currentUser?.uid;

                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue : Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      child: Text(
                        message['text'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[850],
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
