import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupCreatorId;

  const GroupChatScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupCreatorId,
  }) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  late AnimationController _fabAnimationController;
  late AnimationController _appBarAnimationController;
  late AnimationController _messageAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<double> _appBarAnimation;

  bool _isTyping = false;
  bool _showScrollToBottom = false;
  String _replyToMessage = '';
  String _replyToSender = '';
  bool _isEmojiPickerVisible = false;

  final List<String> _quickEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '😡',
    '🎉',
    '🔥'
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupScrollListener();
    _setupMessageListener();
  }

  void _setupAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _fabAnimationController, curve: Curves.elasticOut),
    );

    _appBarAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _appBarAnimationController, curve: Curves.easeInOut),
    );

    _appBarAnimationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final showButton = _scrollController.offset > 200;
      if (showButton != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = showButton;
        });
        if (showButton) {
          _fabAnimationController.forward();
        } else {
          _fabAnimationController.reverse();
        }
      }
    });
  }

  void _setupMessageListener() {
    _messageController.addListener(() {
      final isTyping = _messageController.text.isNotEmpty;
      if (isTyping != _isTyping) {
        setState(() {
          _isTyping = isTyping;
        });
      }
    });
  }

  Future<void> _sendMessage(String message, String type,
      {String? replyTo, String? replyToSender}) async {
    if (message.trim().isNotEmpty) {
      HapticFeedback.lightImpact();

      final messageData = {
        'senderId': _auth.currentUser?.uid,
        'message': message,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': <String, List<String>>{},
        'edited': false,
        'editedAt': null,
      };

      if (replyTo != null && replyToSender != null) {
        messageData['replyTo'] = replyTo;
        messageData['replyToSender'] = replyToSender;
      }

      await _firestore
          .collection('groups/${widget.groupId}/messages')
          .add(messageData);
      _messageController.clear();
      _clearReply();
      _scrollToBottom();

      // Send message animation
      _messageAnimationController.forward().then((_) {
        _messageAnimationController.reset();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearReply() {
    setState(() {
      _replyToMessage = '';
      _replyToSender = '';
    });
  }

  void _setReply(String message, String sender) {
    setState(() {
      _replyToMessage = message;
      _replyToSender = sender;
    });
    _messageFocusNode.requestFocus();
  }

  Future<void> _deleteGroup() async {
    final bool? confirm = await _showAnimatedDialog(
      title: 'Delete Group',
      content:
          'Are you sure you want to delete this group? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirm == true) {
      try {
        await _firestore.collection('groups').doc(widget.groupId).delete();
        if (mounted) {
          Navigator.pop(context);
          _showSnackBar(
              "Group deleted successfully", Icons.check_circle, Colors.green);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar("Error deleting group: $e", Icons.error, Colors.red);
        }
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final bool? confirm = await _showAnimatedDialog(
      title: 'Delete Message',
      content: 'Are you sure you want to delete this message?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('groups/${widget.groupId}/messages')
            .doc(messageId)
            .delete();
        if (mounted) {
          _showSnackBar("Message deleted", Icons.delete, Colors.orange);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar("Error deleting message: $e", Icons.error, Colors.red);
        }
      }
    }
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final messageRef = _firestore
          .collection('groups/${widget.groupId}/messages')
          .doc(messageId);

      await _firestore.runTransaction((transaction) async {
        final messageDoc = await transaction.get(messageRef);
        final data = messageDoc.data() as Map<String, dynamic>;
        final reactions =
            Map<String, List<String>>.from(data['reactions'] ?? {});

        if (reactions[emoji] == null) {
          reactions[emoji] = [];
        }

        if (reactions[emoji]!.contains(userId)) {
          reactions[emoji]!.remove(userId);
          if (reactions[emoji]!.isEmpty) {
            reactions.remove(emoji);
          }
        } else {
          reactions[emoji]!.add(userId);
        }

        transaction.update(messageRef, {'reactions': reactions});
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      _showSnackBar("Error adding reaction", Icons.error, Colors.red);
    }
  }

  Future<bool?> _showAnimatedDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
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
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(confirmText),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 400),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, (1 - value) * 300),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _firestore
                      .collection('groups')
                      .doc(widget.groupId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final groupData = snapshot.data!;
                    final List<dynamic> members = groupData['members'] ?? [];

                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade400,
                                      Colors.blue.shade600
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.group,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Group Info',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      widget.groupName,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey.shade50,
                                  Colors.grey.shade100
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildInfoCard('Members', '${members.length}',
                                    Icons.people),
                                _buildInfoCard(
                                    'Created', 'Today', Icons.calendar_today),
                                _buildInfoCard(
                                    'Messages', '100+', Icons.message),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Members',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _firestore
                                  .collection('users')
                                  .where(FieldPath.documentId,
                                      whereIn: members.isEmpty ? [''] : members)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                return ListView.builder(
                                  itemCount: snapshot.data!.docs.length,
                                  itemBuilder: (context, index) {
                                    final user = snapshot.data!.docs[index];
                                    final isAdmin =
                                        user.id == widget.groupCreatorId;
                                    return TweenAnimationBuilder<double>(
                                      duration: Duration(
                                          milliseconds: 300 + (index * 100)),
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      builder: (context, value, child) {
                                        return Transform.translate(
                                          offset: Offset((1 - value) * 100, 0),
                                          child: Opacity(
                                            opacity: value,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.grey
                                                        .withOpacity(0.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: ListTile(
                                                leading: Hero(
                                                  tag: 'avatar_${user.id}',
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.primaries[
                                                              index %
                                                                  Colors
                                                                      .primaries
                                                                      .length],
                                                          Colors
                                                              .primaries[index %
                                                                  Colors
                                                                      .primaries
                                                                      .length]
                                                              .shade700,
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                    ),
                                                    child: CircleAvatar(
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      child: Text(
                                                        user['firstName'][0]
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  '${user['firstName']} ${user['lastName']}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                                subtitle: Text(user['email']),
                                                trailing: isAdmin
                                                    ? Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient:
                                                              LinearGradient(
                                                            colors: [
                                                              Colors.blue
                                                                  .shade400,
                                                              Colors
                                                                  .blue.shade600
                                                            ],
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: const Text(
                                                          'Admin',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(QueryDocumentSnapshot message, int index) {
    final isSender = message.get('senderId') == _auth.currentUser?.uid;
    final reactions = Map<String, List<String>>.from(
        message.data().toString().contains('reactions')
            ? message.get('reactions') ?? {}
            : {});

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(isSender ? (1 - value) * 100 : (1 - value) * -100, 0),
          child: Opacity(
            opacity: value,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                children: [
                  if (message.data().toString().contains('replyTo'))
                    _buildReplyPreview(message),
                  GestureDetector(
                    onLongPress: () => _showMessageOptions(message, isSender),
                    child: Align(
                      alignment: isSender
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isSender
                              ? LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade600
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey.shade200,
                                    Colors.grey.shade300
                                  ],
                                ),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isSender ? 20 : 5),
                            bottomRight: Radius.circular(isSender ? 5 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isSender) _buildSenderName(message),
                            _buildMessageContent(message, isSender),
                            if (reactions.isNotEmpty)
                              _buildReactions(reactions, message.id),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(QueryDocumentSnapshot message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: Colors.blue.shade400, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replying to ${message.get('replyToSender')}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            message.get('replyTo'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSenderName(QueryDocumentSnapshot message) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(message.get('senderId')).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            snapshot.data!['firstName'],
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(QueryDocumentSnapshot message, bool isSender) {
    if (message.get('type') == 'text') {
      return Text(
        message.get('message'),
        style: TextStyle(
          fontSize: 16,
          color: isSender ? Colors.white : Colors.black87,
        ),
      );
    } else if (message.get('type') == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          message.get('message'),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 100,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildReactions(
      Map<String, List<String>> reactions, String messageId) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 4,
        children: reactions.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final hasReacted = users.contains(_auth.currentUser?.uid);

          return GestureDetector(
            onTap: () => _addReaction(messageId, emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasReacted ? Colors.blue.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      hasReacted ? Colors.blue.shade400 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  if (users.length > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${users.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasReacted
                            ? Colors.blue.shade600
                            : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showMessageOptions(QueryDocumentSnapshot message, bool isSender) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _quickEmojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      _addReaction(message.id, emoji);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              if (message.get('type') == 'text')
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(context);
                    _setReply(message.get('message'), 'User');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: message.get('message')));
                  Navigator.pop(context);
                  _showSnackBar(
                      "Copied to clipboard", Icons.content_copy, Colors.blue);
                },
              ),
              if (isSender)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: AnimatedBuilder(
          animation: _appBarAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _appBarAnimation.value) * -50),
              child: Opacity(
                opacity: _appBarAnimation.value,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore
                          .collection('groups')
                          .doc(widget.groupId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final members =
                            (snapshot.data!['members'] as List).length;
                        return Text(
                          '$members members',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              _showSnackBar("Video call feature coming soon!", Icons.videocam,
                  Colors.blue);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showGroupInfo();
                  break;
                case 'delete':
                  if (_auth.currentUser?.uid == widget.groupCreatorId) {
                    _deleteGroup();
                  } else {
                    _showSnackBar("Only admin can delete the group",
                        Icons.admin_panel_settings, Colors.orange);
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info, color: Colors.blue),
                  title: Text('Group Info'),
                ),
              ),
              if (_auth.currentUser?.uid == widget.groupCreatorId)
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Group',
                        style: TextStyle(color: Colors.red)),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_replyToMessage.isNotEmpty) _buildReplyBar(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade50, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('groups/${widget.groupId}/messages')
                    .orderBy('timestamp')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade100,
                                  Colors.blue.shade200
                                ],
                              ),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start the conversation!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemBuilder: (context, index) {
                      return _buildMessage(messages[index], index);
                    },
                  );
                },
              ),
            ),
          ),
          _buildMessageInput(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabAnimation.value,
            child: Visibility(
              visible: _showScrollToBottom,
              child: FloatingActionButton.small(
                backgroundColor: Colors.blue.shade600,
                child:
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                onPressed: _scrollToBottom,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReplyBar() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * -50),
          child: Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                  left: BorderSide(color: Colors.blue.shade400, width: 4)),
            ),
            child: Row(
              children: [
                Icon(Icons.reply, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to $_replyToSender',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _replyToMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
                  onPressed: _clearReply,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    prefixIcon: IconButton(
                      icon: Icon(
                        _isEmojiPickerVisible
                            ? Icons.keyboard
                            : Icons.emoji_emotions,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _isEmojiPickerVisible = !_isEmojiPickerVisible;
                        });
                        if (_isEmojiPickerVisible) {
                          _messageFocusNode.unfocus();
                        } else {
                          _messageFocusNode.requestFocus();
                        }
                      },
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Row(
                children: [
                  if (!_isTyping) ...[
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.image, color: Colors.white),
                        onPressed: () {
                          _showSnackBar("Image picker coming soon!",
                              Icons.image, Colors.blue);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.mic, color: Colors.white),
                        onPressed: () {
                          _showSnackBar("Voice message coming soon!", Icons.mic,
                              Colors.blue);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  AnimatedScale(
                    scale: _isTyping ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _isTyping ? Icons.send : Icons.send_outlined,
                            color: Colors.white,
                            key: ValueKey(_isTyping),
                          ),
                        ),
                        onPressed: () => _sendMessage(
                          _messageController.text,
                          'text',
                          replyTo: _replyToMessage.isNotEmpty
                              ? _replyToMessage
                              : null,
                          replyToSender:
                              _replyToSender.isNotEmpty ? _replyToSender : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _fabAnimationController.dispose();
    _appBarAnimationController.dispose();
    _messageAnimationController.dispose();
    super.dispose();
  }
}
