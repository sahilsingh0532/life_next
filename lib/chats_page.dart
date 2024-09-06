import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatsPage extends StatefulWidget {
  final Color bgColor;

  ChatsPage({required this.bgColor});

  @override
  _ChatsPageState createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _inviteController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedContact = '';
  User? get currentUser => _auth.currentUser;

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty && _selectedContact.isNotEmpty) {
      await _firestore.collection('messages').add({
        'text': _messageController.text,
        'sender': currentUser?.email,
        'receiver': _selectedContact,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
    }
  }

  Future<void> _showInviteDialog() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Invite a Friend'),
          content: TextField(
            controller: _inviteController,
            decoration: InputDecoration(hintText: 'Enter email'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final email = _inviteController.text;
                // Check if user exists
                final userDoc = await _firestore
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .get();
                if (userDoc.docs.isNotEmpty) {
                  // User exists
                  final userId = userDoc.docs.first.id;
                  setState(() {
                    _selectedContact = userId;
                  });
                  Navigator.of(context).pop();
                } else {
                  // User does not exist
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('User not found')));
                }
              },
              child: Text('Invite'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('messages')
          .where('receiver', isEqualTo: _selectedContact)
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return Center(child: Text('No messages yet.'));
        }

        return ListView.builder(
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            var message = messages[index];
            return ListTile(
              title: Text(
                message['text'],
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                message['sender'],
                style: TextStyle(color: Colors.white54),
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  bool? confirmDelete = await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Delete Message'),
                        content: Text(
                            'Are you sure you want to delete this message?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmDelete ?? false) {
                    await _firestore
                        .collection('messages')
                        .doc(message.id)
                        .delete();
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContactsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final contacts = snapshot.data!.docs;
        return ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            var contact = contacts[index];
            return ListTile(
              title: Text(
                contact['name'],
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(() {
                  _selectedContact = contact['email'];
                });
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.bgColor,
      appBar: AppBar(
        backgroundColor: widget.bgColor.withOpacity(0.7),
        elevation: 0,
        title: Text('Chats', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: Colors.white),
            onPressed: _showInviteDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _selectedContact.isEmpty
            ? _buildContactsList()
            : Column(
                children: [
                  Expanded(child: _buildMessageList()),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Enter a message',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10.0,
                                horizontal: 15.0,
                              ),
                            ),
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        IconButton(
                          icon: Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
