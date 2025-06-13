import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'memo_model.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({Key? key}) : super(key: key);

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  late Box<Memo> memoBox;
  final TextEditingController _textController = TextEditingController();
  File? _image;

  @override
  void initState() {
    super.initState();
    memoBox = Hive.box<Memo>('memos');
  }

  Future<void> _addMemo() async {
    if (_textController.text.trim().isEmpty && _image == null) return;

    final memo = Memo(
      text: _textController.text.trim(),
      imagePath: _image?.path,
    );
    await memoBox.add(memo);
    _textController.clear();
    setState(() => _image = null);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _image = File(pickedFile.path));
  }

  void _deleteMemo(int index) {
    memoBox.deleteAt(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memo Notes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Enter note text'),
            ),
          ),
          if (_image != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Image.file(_image!, height: 100),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Pick Image'),
              ),
              ElevatedButton.icon(
                onPressed: _addMemo,
                icon: const Icon(Icons.save),
                label: const Text('Save Note'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: memoBox.listenable(),
              builder: (context, Box<Memo> box, _) {
                if (box.isEmpty)
                  return const Center(child: Text('No memos yet.'));
                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final memo = box.getAt(index);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(memo?.text ?? ''),
                        subtitle: memo?.imagePath != null
                            ? Image.file(File(memo!.imagePath!), height: 100)
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteMemo(index),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
