import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';

class CommunityPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final countries = [
      {
        'name': 'India',
        'image':
            'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?q=80&w=1200',
        'color': Colors.orange[800],
        'description': 'Discover vibrant Indian communities',
      },
      {
        'name': 'China',
        'image':
            'https://images.unsplash.com/photo-1547981609-4b6bfe67ca0b?q=80&w=1200',
        'color': Colors.red[800],
        'description': 'Connect with Chinese culture',
      },
      {
        'name': 'Japan',
        'image':
            'https://images.unsplash.com/photo-1480796927426-f609979314bd?q=80&w=1200',
        'color': Colors.pink[800],
        'description': 'Join Japanese communities',
      },
      {
        'name': 'South Korea',
        'image':
            'https://images.unsplash.com/photo-1517154421773-0529f29ea451?q=80&w=1200',
        'color': Colors.blue[800],
        'description': 'Experience Korean culture',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Communities',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[100]!, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: countries.length,
                itemBuilder: (context, index) => _buildCountryCard(
                  context,
                  countries[index],
                  index,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _showJoinDialog(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Join Community with Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryCard(
      BuildContext context, Map<String, dynamic> country, int index) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: country['color'],
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CountryCommunityPage(country: country),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: NetworkImage(country['image']!),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.4),
                BlendMode.darken,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  country['name']!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  country['description']!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fadeIn()
        .scale(begin: Offset(0.8, 0.8))
        .move(begin: Offset(0, 50));
  }

  void _showJoinDialog(BuildContext context) {
    final _codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Community'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Enter Invite Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = _codeController.text.trim();
              if (code.isEmpty) return;

              try {
                final query = await FirebaseFirestore.instance
                    .collection('communities')
                    .where('inviteCode', isEqualTo: code)
                    .get();

                if (query.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid invite code')),
                  );
                  return;
                }

                final community = query.docs.first;
                final requiresApproval =
                    community.data()['requiresAdminApproval'] ?? true;
                final currentUser = FirebaseAuth.instance.currentUser;

                if (requiresApproval) {
                  await community.reference.update({
                    'pendingMembers': FieldValue.arrayUnion([currentUser?.uid])
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Join request sent to admin')),
                  );
                } else {
                  await community.reference.update({
                    'members': FieldValue.arrayUnion([currentUser?.uid])
                  });
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommunityChat(
                        communityId: community.id,
                        communityName: community.data()['name'],
                      ),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error joining community: $e')),
                );
              }
            },
            child: Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryTile(BuildContext context, Map<String, dynamic> country) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CountryCommunityPage(country: country),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(country['image']!),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.4),
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: Text(
            country['name']!,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
        ),
      ),
    ).animate().fadeIn().slide(begin: Offset(0, 0.2));
  }
}

class CountryCommunityPage extends StatefulWidget {
  final Map<String, dynamic> country;

  const CountryCommunityPage({Key? key, required this.country})
      : super(key: key);

  @override
  _CountryCommunityPageState createState() => _CountryCommunityPageState();
}

class _CountryCommunityPageState extends State<CountryCommunityPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  String _communityName = '';
  String _description = '';

  void _createCommunity() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Community'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Community Name'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a name' : null,
                onSaved: (value) => _communityName = value ?? '',
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter a description'
                    : null,
                onSaved: (value) => _description = value ?? '',
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                _formKey.currentState?.save();
                final communityId = Uuid().v4();
                final inviteCode = Uuid().v4().substring(0, 8);

                await _firestore
                    .collection('communities')
                    .doc(communityId)
                    .set({
                  'name': _communityName,
                  'description': _description,
                  'country': widget.country['name'],
                  'createdAt': FieldValue.serverTimestamp(),
                  'adminId': _auth.currentUser?.uid,
                  'admins': [_auth.currentUser?.uid],
                  'members': [_auth.currentUser?.uid],
                  'inviteCode': inviteCode,
                  'requiresAdminApproval': true,
                });

                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunityChat(
                      communityId: communityId,
                      communityName: _communityName,
                    ),
                  ),
                );
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.country['name']} Communities'),
        backgroundColor: widget.country['color'],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createCommunity,
        child: Icon(Icons.add),
        backgroundColor: widget.country['color'],
      ).animate().scale(delay: 300.ms),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('communities')
            .where('country', isEqualTo: widget.country['name'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final communities = snapshot.data!.docs;

          if (communities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 64,
                    color: Colors.grey,
                  ).animate().scale(duration: 400.ms),
                  SizedBox(height: 16),
                  Text(
                    'No communities yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn().slideY(begin: 0.3),
                  SizedBox(height: 8),
                  Text(
                    'Create one to get started!',
                    style: TextStyle(color: Colors.grey),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final community = communities[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: widget.country['color'],
                    child: Text(
                      community['name'][0].toUpperCase(),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(community['name']),
                  subtitle: Text(
                    community['description'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommunityChat(
                        communityId: community.id,
                        communityName: community['name'],
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 100 * index))
                  .slideX(begin: 0.2, end: 0);
            },
          );
        },
      ),
    );
  }
}

class CommunityChat extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityChat({
    Key? key,
    required this.communityId,
    required this.communityName,
  }) : super(key: key);

  @override
  _CommunityChatState createState() => _CommunityChatState();
}

class _CommunityChatState extends State<CommunityChat> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final doc = await _firestore
        .collection('communities')
        .doc(widget.communityId)
        .get();

    setState(() {
      _isAdmin =
          (doc.data()?['admins'] as List).contains(_auth.currentUser?.uid);
    });
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAdmin) ...[
              ListTile(
                leading: Icon(Icons.person_add),
                title: Text('Add Members'),
                onTap: () => _showInviteLink(),
              ),
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Change Group Name'),
                onTap: () => _changeCommunityName(),
              ),
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Group Settings'),
                onTap: () => _showGroupSettings(),
              ),
            ],
            ListTile(
              leading: Icon(Icons.info),
              title: Text('Community Info'),
              onTap: () => _showCommunityInfo(),
            ),
            ListTile(
              leading: Icon(Icons.group),
              title: Text('Manage Members'),
              onTap: () {
                Navigator.pop(context);
                _showMemberManagement();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteLink() async {
    final doc = await _firestore
        .collection('communities')
        .doc(widget.communityId)
        .get();

    final inviteCode = doc.data()?['inviteCode'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invite Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this code to invite members:'),
            SizedBox(height: 16),
            SelectableText(
              inviteCode,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _changeCommunityName() {
    final _nameController = TextEditingController(text: widget.communityName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Community Name'),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: 'New Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestore
                  .collection('communities')
                  .doc(widget.communityId)
                  .update({'name': _nameController.text});
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showGroupSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Group Settings'),
        content: StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('communities')
              .doc(widget.communityId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return CircularProgressIndicator();
            }

            final requiresApproval =
                snapshot.data?['requiresAdminApproval'] ?? true;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text('Require Admin Approval'),
                  subtitle: Text(
                    'New members need admin approval to join',
                  ),
                  value: requiresApproval,
                  onChanged: (value) async {
                    await _firestore
                        .collection('communities')
                        .doc(widget.communityId)
                        .update({'requiresAdminApproval': value});
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMemberManagement() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Member Management'),
        content: StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('communities')
              .doc(widget.communityId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return CircularProgressIndicator();
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final members = List<String>.from(data['members'] ?? []);
            final pendingMembers =
                List<String>.from(data['pendingMembers'] ?? []);

            return Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pendingMembers.isNotEmpty) ...[
                    Text(
                      'Pending Requests',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...pendingMembers
                        .map((uid) => FutureBuilder<DocumentSnapshot>(
                              future:
                                  _firestore.collection('users').doc(uid).get(),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData) {
                                  return ListTile(title: Text('Loading...'));
                                }
                                final userData = userSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                return ListTile(
                                  title: Text(userData['firstName'] +
                                      ' ' +
                                      userData['lastName']),
                                  subtitle: Text(userData['email']),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.check,
                                            color: Colors.green),
                                        onPressed: () async {
                                          await _firestore
                                              .collection('communities')
                                              .doc(widget.communityId)
                                              .update({
                                            'members':
                                                FieldValue.arrayUnion([uid]),
                                            'pendingMembers':
                                                FieldValue.arrayRemove([uid]),
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.close,
                                            color: Colors.red),
                                        onPressed: () async {
                                          await _firestore
                                              .collection('communities')
                                              .doc(widget.communityId)
                                              .update({
                                            'pendingMembers':
                                                FieldValue.arrayRemove([uid]),
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ))
                        .toList(),
                  ],
                  SizedBox(height: 16),
                  Text(
                    'Members',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...members
                      .map((uid) => FutureBuilder<DocumentSnapshot>(
                            future:
                                _firestore.collection('users').doc(uid).get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return ListTile(title: Text('Loading...'));
                              }
                              final userData = userSnapshot.data!.data()
                                  as Map<String, dynamic>;
                              return ListTile(
                                title: Text(userData['firstName'] +
                                    ' ' +
                                    userData['lastName']),
                                subtitle: Text(userData['email']),
                                trailing: IconButton(
                                  icon: Icon(Icons.remove_circle,
                                      color: Colors.red),
                                  onPressed: () async {
                                    await _firestore
                                        .collection('communities')
                                        .doc(widget.communityId)
                                        .update({
                                      'members': FieldValue.arrayRemove([uid]),
                                      'admins': FieldValue.arrayRemove([uid]),
                                    });
                                  },
                                ),
                              );
                            },
                          ))
                      .toList(),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCommunityInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Community Info'),
        content: StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('communities')
              .doc(widget.communityId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return CircularProgressIndicator();
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final memberCount = (data['members'] as List).length;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Name: ${data['name']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Description: ${data['description']}'),
                SizedBox(height: 8),
                Text('Members: $memberCount'),
                SizedBox(height: 8),
                Text(
                  'Created: ${(data['createdAt'] as Timestamp).toDate().toString()}',
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.communityName),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: _showOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('communities')
                  .doc(widget.communityId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final message = snapshot.data!.docs[index];
                    final isMe = message['senderId'] == _auth.currentUser?.uid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                message['senderName'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isMe ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            if (message['imageUrl'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  message['imageUrl'],
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (message['text'] != null)
                              Text(
                                message['text'],
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn().slideX(begin: isMe ? 0.2 : -0.2);
                  },
                );
              },
            ),
          ),
          if (_isAdmin)
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.photo),
                    onPressed: () {
                      // Implement image upload
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: () async {
                      if (_messageController.text.trim().isNotEmpty) {
                        await _firestore
                            .collection('communities')
                            .doc(widget.communityId)
                            .collection('messages')
                            .add({
                          'text': _messageController.text.trim(),
                          'senderId': _auth.currentUser?.uid,
                          'senderName': _auth.currentUser?.displayName,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        _messageController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
