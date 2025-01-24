import 'package:flutter/material.dart';

class CreateGroupDialog extends StatelessWidget {
  final List<String> selectedUsers;

  const CreateGroupDialog({Key? key, required this.selectedUsers})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController groupNameController = TextEditingController();

    return AlertDialog(
      title: const Text('Create Group'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: groupNameController,
            decoration: const InputDecoration(
              hintText: 'Enter group name',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final groupName = groupNameController.text.trim();
            if (groupName.isNotEmpty) {
              Navigator.pop(context, groupName);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group name cannot be empty')),
              );
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
