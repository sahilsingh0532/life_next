import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

void main() {
  runApp(const JerryApp());
}

class JerryApp extends StatelessWidget {
  const JerryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jerry AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const ChatScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.smart_toy_rounded,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Jerry',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
            const SizedBox(height: 10),
            Text(
              'Your AI Assistant',
              style: Theme.of(context).textTheme.titleMedium,
            ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isSending = false;
  late AnimationController _bounceController;

  // 25 simple responses for Jerry
  final List<String> _jerryResponses = [
    "Hello! I'm Jerry, your AI assistant. How can I help you today?",
    "Nice to meet you! What can I do for you?",
    "That's interesting! Tell me more about it.",
    "I understand. How does that make you feel?",
    "I'd be happy to help with that!",
    "Let me think about that... I recommend trying a different approach.",
    "Based on what you're saying, I suggest considering other options.",
    "That's a great question! Here's what I know...",
    "I'm here to help you solve problems.",
    "Sometimes taking a break helps with creative thinking.",
    "Have you considered asking for others' opinions?",
    "I remember you mentioned something similar before.",
    "Let me help you break this down into smaller steps.",
    "That sounds challenging. How can I support you?",
    "I'm always learning, but here's my current understanding...",
    "Interesting perspective! I hadn't thought of it that way.",
    "Let's explore this topic further together.",
    "I'm detecting this might be important to you.",
    "Based on patterns I've noticed, this might help...",
    "I suggest trying it this way...",
    "Here's a simple solution that might work...",
    "I've helped others with similar questions before.",
    "Let me simplify that for you...",
    "The key point seems to be...",
    "Thanks for chatting with me! Is there anything else I can help with?"
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _addBotMessage(
        "Hi! I'm Jerry, your AI assistant. How can I help you today?");
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('chat_history');
    if (history != null && mounted) {
      setState(() {
        _messages.clear();
        for (final messageStr in history) {
          try {
            final messageMap = json.decode(messageStr) as Map<String, dynamic>;
            _messages.add(ChatMessage.fromJson(messageMap));
          } catch (e) {
            debugPrint('Failed to parse message: $e');
          }
        }
      });
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = _messages.map((msg) => json.encode(msg.toJson())).toList();
    await prefs.setStringList('chat_history', history);
  }

  void _addUserMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
    _saveChatHistory();
  }

  void _addBotMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _isTyping = false;
      _isSending = false;
    });
    _scrollToBottom();
    _saveChatHistory();
  }

  String _getAIResponse(String message) {
    // Simple response selection logic:
    // 1. Check for greetings
    if (message.toLowerCase().contains('hello') ||
        message.toLowerCase().contains('hi') ||
        message.toLowerCase().contains('hey')) {
      return "Hello there! How can I assist you today?";
    }

    // 2. Check for thanks
    if (message.toLowerCase().contains('thank') ||
        message.toLowerCase().contains('thanks')) {
      return "You're welcome! Is there anything else I can help with?";
    }

    // 3. Use message length to determine response type
    if (message.length < 5) {
      return "Could you please elaborate on that?";
    }

    // 4. Cycle through responses based on conversation length
    final responseIndex = _messages.length % _jerryResponses.length;
    return _jerryResponses[responseIndex];
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    _messageController.clear();
    _addUserMessage(text);

    setState(() {
      _isTyping = true;
      _isSending = true;
    });

    try {
      _bounceController.forward(from: 0.0);

      // Simulate AI thinking time
      await Future.delayed(Duration(milliseconds: 500 + (text.length * 10)));

      final response = _getAIResponse(text);
      _addBotMessage(response);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _deleteMessage(int index) {
    if (!mounted) return;
    setState(() {
      _messages.removeAt(index);
    });
    _saveChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.smart_toy_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Jerry',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Chat History'),
                  content: const Text(
                      'Are you sure you want to clear all chat history?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _messages.clear();
                            _addBotMessage(
                                "Hi! I'm Jerry, your AI assistant. How can I help you today?");
                          });
                          _saveChatHistory();
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('CLEAR'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 100,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.5),
                        )
                            .animate()
                            .scale(duration: 600.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 20),
                        Text(
                          "Start chatting with Jerry!",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return MessageBubble(
                        message: message,
                        onCopy: () => _copyToClipboard(message.text),
                        onDelete: () => _deleteMessage(index),
                      ).animate().fadeIn(
                            duration: 300.ms,
                            delay: (50 * index).ms,
                          );
                    },
                  ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    radius: 18,
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const TypingIndicator(),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 5,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.5),
                      ),
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: "Ask Jerry something...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onSubmitted: _handleSubmitted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending
                        ? null
                        : () => _handleSubmitted(_messageController.text),
                    child: AnimatedBuilder(
                      animation: _bounceController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + _bounceController.value * 0.2,
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: _isSending
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.5)
                                  : Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: _isSending
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({Key? key}) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      )..repeat(
          reverse: true, period: Duration(milliseconds: 600 + (index * 200)));
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Container(
              width: 8,
              height: 8 + (_controllers[index].value * 4),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          },
        );
      }),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  const MessageBubble({
    Key? key,
    required this.message,
    this.onCopy,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final time = _formatTimestamp(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              radius: 16,
              child: Icon(
                Icons.smart_toy_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    contentPadding: EdgeInsets.zero,
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(10),
                    content: IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (onCopy != null)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onCopy?.call();
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.copy, size: 20),
                                  SizedBox(width: 8),
                                  Text('Copy'),
                                ],
                              ),
                            ),
                          if (onDelete != null && isUser)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onDelete?.call();
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        color: isUser
                            ? Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withOpacity(0.7)
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return 'Today ${_formatTime(timestamp)}';
    } else if (messageDate == yesterday) {
      return 'Yesterday ${_formatTime(timestamp)}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${_formatTime(timestamp)}';
    }
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _selectedVoice = 'Default';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _selectedVoice = prefs.getString('selected_voice') ?? 'Default';
    });
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', _darkMode);
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setString('selected_voice', _selectedVoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'AI Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('API Status'),
            subtitle: const Text('Using local responses'),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: _darkMode,
              onChanged: (value) {
                setState(() {
                  _darkMode = value;
                });
                _saveSettings();
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _saveSettings();
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.record_voice_over),
            title: const Text('Assistant Voice'),
            subtitle: Text(_selectedVoice),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Select Voice'),
                  children: [
                    for (final voice in ['Default', 'Female', 'Male', 'Robot'])
                      SimpleDialogOption(
                        onPressed: () {
                          setState(() {
                            _selectedVoice = voice;
                          });
                          _saveSettings();
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(voice),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
