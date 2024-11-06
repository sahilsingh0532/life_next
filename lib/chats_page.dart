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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedContact = '';
  String _contactName = 'Contact Name'; // Placeholder for contact name
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
            return GestureDetector(
              onLongPress: () async {
                bool? confirmDelete = await showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Delete Message'),
                      content:
                          Text('Are you sure you want to delete this message?'),
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
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                padding: EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message['text'],
                      style: TextStyle(color: Colors.white, fontSize: 16.0),
                    ),
                    SizedBox(height: 5.0),
                    Text(
                      message['sender'],
                      style: TextStyle(color: Colors.white54, fontSize: 12.0),
                    ),
                  ],
                ),
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
                  _contactName = contact['name'];
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
        backgroundColor: widget.bgColor.withOpacity(0.9),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _selectedContact.isEmpty ? 'Chats' : _contactName,
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
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
                              filled: true,
                              fillColor: Colors.grey[700],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide.none,
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
