// country_page.dart - Country-specific Page

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'community.dart';
import 'group_page.dart';

class CountryPage extends StatefulWidget {
  final CountryInfo country;

  const CountryPage({Key? key, required this.country}) : super(key: key);

  @override
  _CountryPageState createState() => _CountryPageState();
}

class _CountryPageState extends State<CountryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Community> communities = [];
  bool isLoading = true;
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    fetchCommunities();
  }

  Future<void> fetchCommunities() async {
    setState(() {
      isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .get();

      List<Community> loadedCommunities = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        loadedCommunities.add(Community(
          id: doc.id,
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          adminId: data['adminId'] ?? '',
          members: List<String>.from(data['members'] ?? []),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
        ));
      }

      setState(() {
        communities = loadedCommunities;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching communities: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showCreateCommunityDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Community in ${widget.country.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Community Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _createCommunity(nameController.text.trim(),
                    descriptionController.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCommunity(String name, String description) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .add({
        'name': name,
        'description': description,
        'adminId': currentUserId,
        'members': [currentUserId],
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community created successfully!')),
      );

      // Refresh the list
      fetchCommunities();
    } catch (e) {
      print('Error creating community: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create community')),
      );
    }
  }

  void _navigateToCommunity(Community community) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityDetailPage(
          country: widget.country,
          community: community,
          isAdmin: community.adminId == currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.country.name} Communities'),
        backgroundColor: widget.country.colors[0],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _showCreateCommunityDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Community'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.country.colors.length > 1
                    ? widget.country.colors[1]
                    : Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : communities.isEmpty
                    ? Center(
                        child: Text(
                          'No communities found in ${widget.country.name}.\nCreate one to get started!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: communities.length,
                        itemBuilder: (context, index) {
                          final community = communities[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            elevation: 3,
                            child: ListTile(
                              title: Text(
                                community.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Text(
                                community.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () => _navigateToCommunity(community),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class Community {
  final String id;
  final String name;
  final String description;
  final String adminId;
  final List<String> members;
  final DateTime createdAt;

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.adminId,
    required this.members,
    required this.createdAt,
  });
}

class CommunityDetailPage extends StatefulWidget {
  final CountryInfo country;
  final Community community;
  final bool isAdmin;

  const CommunityDetailPage({
    Key? key,
    required this.country,
    required this.community,
    required this.isAdmin,
  }) : super(key: key);

  @override
  _CommunityDetailPageState createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Group> groups = [];
  bool isLoading = true;
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    fetchGroups();
  }

  Future<void> fetchGroups() async {
    setState(() {
      isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .get();

      List<Group> loadedGroups = [];
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        loadedGroups.add(Group(
          id: doc.id,
          name: data['name'] ?? '',
          joinCode: data['joinCode'] ?? '',
          operatorId: data['operatorId'] ?? '',
          adminIds: List<String>.from(data['adminIds'] ?? []),
          memberIds: List<String>.from(data['memberIds'] ?? []),
          createdAt: (data['createdAt'] as Timestamp).toDate(),
        ));
      }

      setState(() {
        groups = loadedGroups;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching groups: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final joinCode = generateRandomCode();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Join Code: $joinCode',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Share this code with others to let them join your group.'),
          ],
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
                await _createGroup(nameController.text.trim(), joinCode);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  String generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
        6, (_) => chars[DateTime.now().microsecond % chars.length]).join();
  }

  Future<void> _createGroup(String name, String joinCode) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .add({
        'name': name,
        'joinCode': joinCode,
        'operatorId': currentUserId,
        'adminIds': [currentUserId],
        'memberIds': [currentUserId],
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created successfully!')),
      );

      // Refresh the list
      fetchGroups();
    } catch (e) {
      print('Error creating group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create group')),
      );
    }
  }

  void _showJoinGroupDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Enter Join Code',
                border: OutlineInputBorder(),
              ),
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
              if (codeController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await _joinGroup(codeController.text.trim());
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinGroup(String joinCode) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('countries')
          .doc(widget.country.name.toLowerCase())
          .collection('communities')
          .doc(widget.community.id)
          .collection('groups')
          .where('joinCode', isEqualTo: joinCode)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid join code')),
        );
        return;
      }

      String groupId = snapshot.docs.first.id;
      Map<String, dynamic> groupData =
          snapshot.docs.first.data() as Map<String, dynamic>;

      List<String> memberIds = List<String>.from(groupData['memberIds'] ?? []);

      if (memberIds.contains(currentUserId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You are already a member of this group')),
        );
        return;
      }

      // Check if admin approval is required
      bool requiresApproval = groupData['requiresAdminApproval'] ?? false;

      if (requiresApproval) {
        // Add to pending members
        await _firestore
            .collection('countries')
            .doc(widget.country.name.toLowerCase())
            .collection('communities')
            .doc(widget.community.id)
            .collection('groups')
            .doc(groupId)
            .update({
          'pendingMembers': FieldValue.arrayUnion([currentUserId]),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Join request sent. Waiting for admin approval.')),
        );
      } else {
        // Add directly to members
        await _firestore
            .collection('countries')
            .doc(widget.country.name.toLowerCase())
            .collection('communities')
            .doc(widget.community.id)
            .collection('groups')
            .doc(groupId)
            .update({
          'memberIds': FieldValue.arrayUnion([currentUserId]),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the group!')),
        );
      }

      // Refresh the list
      fetchGroups();
    } catch (e) {
      print('Error joining group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join group')),
      );
    }
  }

  void _navigateToGroup(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupPage(
          country: widget.country,
          community: widget.community,
          group: group,
          isOperator: group.operatorId == currentUserId,
          isAdmin: group.adminIds.contains(currentUserId),
        ),
      ),
    ).then((_) => fetchGroups());
  }

  void _showCommunityMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.isAdmin)
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Add Members'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddMembersDialog();
                  },
                ),
              if (widget.isAdmin)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Change Group Name'),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangeNameDialog();
                  },
                ),
              if (widget.isAdmin)
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Group Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    _showGroupSettingsDialog();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Community Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showCommunityInfoDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMembersDialog() {
    final linkController = TextEditingController();
    String inviteLink = 'https://community.app/join/${widget.community.id}';
    linkController.text = inviteLink;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this link to invite members:'),
            const SizedBox(height: 10),
            TextField(
              controller: linkController,
              readOnly: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    // Copy to clipboard functionality would go here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                  },
                ),
              ),
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
    nameController.text = widget.community.name;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Community Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'New Community Name',
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
                // Update community name in Firestore
                try {
                  await _firestore
                      .collection('countries')
                      .doc(widget.country.name.toLowerCase())
                      .collection('communities')
                      .doc(widget.community.id)
                      .update({
                    'name': nameController.text.trim(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Community name updated successfully')),
                  );
                } catch (e) {
                  print('Error updating community name: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to update community name')),
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

  void _showCommunityInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.community.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description: ${widget.community.description}'),
            const SizedBox(height: 12),
            Text('Members: ${widget.community.members.length}'),
            const SizedBox(height: 12),
            Text(
                'Created: ${widget.community.createdAt.toString().split('.')[0]}'),
            const SizedBox(height: 12),
            Text(widget.isAdmin ? 'Role: Admin' : 'Role: Member'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.community.name),
        backgroundColor: widget.country.colors[0],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showCommunityMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showCreateGroupDialog,
                    icon: const Icon(Icons.group_add),
                    label: const Text('Create Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.country.colors.length > 1
                          ? widget.country.colors[1]
                          : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showJoinGroupDialog,
                    icon: const Icon(Icons.login),
                    label: const Text('Join Group'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : groups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.group,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No groups found in this community.',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Create a group or join one to get started!',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          bool isOperator = group.operatorId == currentUserId;
                          bool isAdmin = group.adminIds.contains(currentUserId);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            elevation: 3,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: widget.country.colors[0],
                                child: Text(
                                  group.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                group.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                isOperator
                                    ? 'Role: Operator • ${group.memberIds.length} members'
                                    : isAdmin
                                        ? 'Role: Admin • ${group.memberIds.length} members'
                                        : '${group.memberIds.length} members',
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () => _navigateToGroup(group),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class Group {
  final String id;
  final String name;
  final String joinCode;
  final String operatorId;
  final List<String> adminIds;
  final List<String> memberIds;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.operatorId,
    required this.adminIds,
    required this.memberIds,
    required this.createdAt,
  });
}
