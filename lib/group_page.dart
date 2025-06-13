// group_page.dart - Group Details and Chat Page
// this is for communities page

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:life_next/country_page.dart';
import 'community.dart';
import 'package:flutter/services.dart';

class GroupPage extends StatefulWidget {
  final CountryInfo country;
  final Community community;
  final Group group;
  final bool isOperator;
  final bool isAdmin;

  const GroupPage({
    Key? key,
    required this.country,
    required this.community,
    required this.group,
    required this.isOperator,
    required this.isAdmin,
  }) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<QuerySnapshot> _messagesStream;
  late String currentUserId;
  bool isLoading = true;
  List<String> pendingMembers = [];

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    setupMessagesStream();
    if (widget.isOperator || widget.isAdmin) {
      fetchPendingMembers();
    }
  }

  void setupMessagesStream() {
    _messagesStream = _firestore
        .collection('countries')
        .doc(widget.country.name.toLowerCase())
        .collection('communities')
        .doc(widget.community.id)
        .collection('groups')
        .doc(widget.group.id)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> fetchPendingMembers() async {
    try {
      DocumentSnapshot groupDoc = await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .doc(widget.group.id)
          .get();

      if (groupDoc.exists) {
        Map<String, dynamic> data = groupDoc.data() as Map<String, dynamic>;
        if (data.containsKey('pendingMembers')) {
          setState(() {
            pendingMembers = List<String>.from(data['pendingMembers'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error fetching pending members: $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    if (!(widget.isOperator || widget.isAdmin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can send messages')),
      );
      return;
    }

    try {
      await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .doc(widget.group.id)
          .collection('messages')
          .add({
        'text': text,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      _messageController.clear();
      // Scroll to bottom after sending message
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Future<void> _sendImage() async {
    if (!(widget.isOperator || widget.isAdmin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can send images')),
      );
      return;
    }

    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    try {
      // Upload image to Firebase Storage
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('group_images')
          .child(widget.group.id)
          .child('$fileName.jpg');

      await storageRef.putFile(File(image.path));
      String downloadUrl = await storageRef.getDownloadURL();

      // Add message with image URL
      await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .doc(widget.group.id)
          .collection('messages')
          .add({
        'imageUrl': downloadUrl,
        'senderId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'image',
      });
    } catch (e) {
      print('Error sending image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send image')),
      );
    }
  }

  void _showGroupMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.isOperator || widget.isAdmin)
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Add Members'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddMembersDialog();
                  },
                ),
              if (widget.isOperator)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Change Group Name'),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangeNameDialog();
                  },
                ),
              if (widget.isOperator)
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Group Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    _showGroupSettingsDialog();
                  },
                ),
              if (widget.isOperator || widget.isAdmin)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Manage Members'),
                  onTap: () {
                    Navigator.pop(context);
                    _showManageMembersDialog();
                  },
                ),
              if (pendingMembers.isNotEmpty &&
                  (widget.isOperator || widget.isAdmin))
                ListTile(
                  leading: const Icon(Icons.person_add_alt),
                  title: Text('Pending Requests (${pendingMembers.length})'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPendingRequestsDialog();
                  },
                ),
              if (widget.isOperator)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Manage Admins'),
                  onTap: () {
                    Navigator.pop(context);
                    _showManageAdminsDialog();
                  },
                ),
              if (widget.isOperator)
                ListTile(
                  leading: const Icon(Icons.delete_forever),
                  title: const Text('Delete Group'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteGroupDialog();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Group Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showGroupInfoDialog();
                },
              ),
              if (!widget.isOperator)
                ListTile(
                  leading: const Icon(Icons.exit_to_app),
                  title: const Text('Leave Group'),
                  onTap: () {
                    Navigator.pop(context);
                    _showLeaveGroupDialog();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMembersDialog() {
    final codeController = TextEditingController();
    codeController.text = widget.group.joinCode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code to invite members:'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: codeController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.group.joinCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Join code copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangeNameDialog() {
    final nameController = TextEditingController();
    nameController.text = widget.group.name;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Group Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'New Group Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                // Update group name in Firestore
                try {
                  await _firestore
                      .collection('countries')
                      .doc(widget.country.name.toLowerCase())
                      .collection('communities')
                      .doc(widget.community.id)
                      .collection('groups')
                      .doc(widget.group.id)
                      .update({
                    'name': nameController.text.trim(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Group name updated successfully')),
                  );
                } catch (e) {
                  print('Error updating group name: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to update group name')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showGroupSettingsDialog() {
    bool requireApproval = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Group Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Require Admin Approval for New Members'),
                  value: requireApproval,
                  onChanged: (value) {
                    setState(() {
                      requireApproval = value;
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
                onPressed: () async {
                  Navigator.pop(context);
                  // Save settings to Firestore
                  try {
                    await _firestore
                        .collection('countries')
                        .doc(widget.country.name.toLowerCase())
                        .collection('communities')
                        .doc(widget.community.id)
                        .collection('groups')
                        .doc(widget.group.id)
                        .update({
                      'requiresAdminApproval': requireApproval,
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Settings updated successfully')),
                    );
                  } catch (e) {
                    print('Error updating settings: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Failed to update settings')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPendingRequestsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending Join Requests'),
        content: Container(
          width: double.maxFinite,
          child: pendingMembers.isEmpty
              ? const Text('No pending requests')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: pendingMembers.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text('User ID: ${pendingMembers[index]}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _handleMemberRequest(
                                pendingMembers[index], true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _handleMemberRequest(
                                pendingMembers[index], false),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMemberRequest(String userId, bool approve) async {
    try {
      if (approve) {
        // Add user to members
        await _firestore
            .collection('countries')
            .doc(widget.country.name.toLowerCase())
            .collection('communities')
            .doc(widget.community.id)
            .collection('groups')
            .doc(widget.group.id)
            .update({
          'memberIds': FieldValue.arrayUnion([userId]),
          'pendingMembers': FieldValue.arrayRemove([userId]),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User approved and added to the group')),
        );
      } else {
        // Remove user from pending
        await _firestore
            .collection('countries')
            .doc(widget.country.name.toLowerCase())
            .collection('communities')
            .doc(widget.community.id)
            .collection('groups')
            .doc(widget.group.id)
            .update({
          'pendingMembers': FieldValue.arrayRemove([userId]),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User request rejected')),
        );
      }

      // Update local state
      setState(() {
        pendingMembers.remove(userId);
      });

      Navigator.pop(context);
    } catch (e) {
      print('Error handling member request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to process request')),
      );
    }
  }

  void _showManageMembersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Members'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.group.memberIds.length,
            itemBuilder: (context, index) {
              String memberId = widget.group.memberIds[index];
              bool isGroupOperator = memberId == widget.group.operatorId;
              bool isGroupAdmin = widget.group.adminIds.contains(memberId);

              return ListTile(
                title: Text(
                  isGroupOperator
                      ? 'User: $memberId (Operator)'
                      : isGroupAdmin
                          ? 'User: $memberId (Admin)'
                          : 'User: $memberId',
                ),
                trailing: memberId != currentUserId &&
                        !isGroupOperator &&
                        (widget.isOperator || (widget.isAdmin && !isGroupAdmin))
                    ? IconButton(
                        icon:
                            const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _removeGroupMember(memberId),
                      )
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeGroupMember(String memberId) async {
    try {
      await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .doc(widget.group.id)
          .update({
        'memberIds': FieldValue.arrayRemove([memberId]),
        'adminIds': FieldValue.arrayRemove([memberId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error removing member: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove member')),
      );
    }
  }

  void _showManageAdminsDialog() {
    List<String> members = List.from(widget.group.memberIds);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Admins'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: members.length,
            itemBuilder: (context, index) {
              String memberId = members[index];
              bool isOperator = memberId == widget.group.operatorId;
              bool isAdmin = widget.group.adminIds.contains(memberId);

              if (isOperator) return Container(); // Skip operator in this list

              return ListTile(
                title: Text('User: $memberId'),
                subtitle: Text(isAdmin ? 'Admin' : 'Member'),
                trailing: Switch(
                  value: isAdmin,
                  onChanged: (value) {
                    if (value) {
                      _promoteToAdmin(memberId);
                    } else {
                      _demoteFromAdmin(memberId);
                    }
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _promoteToAdmin(String memberId) async {
    try {
      await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .doc(widget.group.id)
          .update({
        'adminIds': FieldValue.arrayUnion([memberId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User promoted to admin')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error promoting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to promote user')),
      );
    }
  }

  Future<void> _demoteFromAdmin(String memberId) async {
    try {
      await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .doc(widget.group.id)
          .update({
        'adminIds': FieldValue.arrayRemove([memberId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User demoted from admin')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error demoting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to demote user')),
      );
    }
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
            'Are you sure you want to delete this group? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteGroup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    try {
      await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .doc(widget.group.id)
          .delete();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted successfully')),
      );
    } catch (e) {
      print('Error deleting group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete group')),
      );
    }
  }

  void _showGroupInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.group.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join Code: ${widget.group.joinCode}'),
            const SizedBox(height: 12),
            Text('Members: ${widget.group.memberIds.length}'),
            const SizedBox(height: 12),
            Text('Created: ${widget.group.createdAt.toString().split('.')[0]}'),
            const SizedBox(height: 12),
            Text(
              widget.isOperator
                  ? 'Role: Operator'
                  : widget.isAdmin
                      ? 'Role: Admin'
                      : 'Role: Member',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _leaveGroup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveGroup() async {
    try {
      await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .doc(widget.group.id)
          .update({
        'memberIds': FieldValue.arrayRemove([currentUserId]),
        'adminIds': FieldValue.arrayRemove([currentUserId]),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have left the group')),
      );
    } catch (e) {
      print('Error leaving group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to leave group')),
      );
    }
  }

  Widget _buildMessage(DocumentSnapshot message) {
    Map<String, dynamic> data = message.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderId'] == currentUserId;
    String messageType = data['type'] ?? 'text';

    DateTime? timestamp;
    if (data['timestamp'] != null) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser)
            const CircleAvatar(
              backgroundColor: Colors.grey,
              radius: 16,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? widget.country.colors[0].withOpacity(0.7)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (messageType == 'text')
                    Text(
                      data['text'] ?? '',
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black,
                      ),
                    )
                  else if (messageType == 'image')
                    InkWell(
                      onTap: () {
                        // Show full-size image
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                backgroundColor: Colors.black,
                                iconTheme:
                                    const IconThemeData(color: Colors.white),
                              ),
                              backgroundColor: Colors.black,
                              body: Center(
                                child: InteractiveViewer(
                                  child: Image.network(data['imageUrl']),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['imageUrl'],
                          width: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return SizedBox(
                              width: 200,
                              height: 150,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('HH:mm').format(timestamp),
                        style: TextStyle(
                          color: isCurrentUser ? Colors.white70 : Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isCurrentUser)
            const CircleAvatar(
              backgroundColor: Colors.grey,
              radius: 16,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        backgroundColor: widget.country.colors[0],
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: _showGroupMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot message = snapshot.data!.docs[index];
                    return _buildMessage(message);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (widget.isOperator || widget.isAdmin)
                  IconButton(
                    icon: const Icon(Icons.photo),
                    onPressed: _sendImage,
                  ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _sendMessage(value);
                      }
                    },
                    enabled: widget.isOperator || widget.isAdmin,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: widget.isOperator || widget.isAdmin
                      ? () => _sendMessage(_messageController.text)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InteractiveViewer extends StatelessWidget {
  final Widget child;

  const InteractiveViewer({Key? key, required this.child}) : super(key: key);

  get Flutter => null;

  @override
  Widget build(BuildContext context) {
    return Flutter.InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: child,
    );
  }
}
