import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class MemoScreen extends StatefulWidget {
  @override
  _MemoScreenState createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  TextEditingController _controller = TextEditingController();
  List<Message> messages = [];
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text("Memo"),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              String query = await _showSearchDialog();
              setState(() {
                messages = messages.where((message) {
                  return message.text.contains(query);
                }).toList();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return ListTile(
                  title: Text(message.text),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(message.timestamp),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        messages.removeAt(index);
                      });
                    },
                  ),
                  onTap: () {
                    if (message.media != null) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: message.media!,
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.camera_alt),
                  onPressed: () => _pickMedia(ImageSource.camera),
                ),
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: () => _pickMedia(ImageSource.gallery),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      setState(() {
                        messages.add(Message(
                          text: _controller.text,
                          timestamp: DateTime.now(),
                        ));
                        _controller.clear();
                      });
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

  Future<void> _pickMedia(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        messages.add(Message(
          text: 'Sent an image',
          timestamp: DateTime.now(),
          media: Image.file(File(pickedFile.path)),
        ));
      });
    }
  }

  Future<String> _showSearchDialog() async {
    String query = '';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Search Messages'),
          content: TextField(
            onChanged: (value) {
              query = value;
            },
            decoration: InputDecoration(hintText: 'Search here'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Search'),
            ),
          ],
        );
      },
    );
    return query;
  }
}

class Message {
  final String text;
  final DateTime timestamp;
  final Widget? media;

  Message({
    required this.text,
    required this.timestamp,
    this.media,
  });
}
