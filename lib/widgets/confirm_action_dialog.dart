import 'package:flutter/material.dart';

/// Confirmation dialog for instructions (create/edit/delete)
/// payloadPreview: Map that will be rendered as key/value summary
class ConfirmActionDialog extends StatelessWidget {
  final String title;
  final Map<String, dynamic> payloadPreview;
  final bool destructive;
  const ConfirmActionDialog({
    super.key,
    required this.title,
    required this.payloadPreview,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final entries = payloadPreview.entries.toList();
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: entries.length,
          itemBuilder: (_, idx) {
            final e = entries[idx];
            return ListTile(
              title: Text(e.key),
              subtitle: Text(e.value?.toString() ?? ''),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          style: destructive ? ElevatedButton.styleFrom(backgroundColor: Colors.red) : null,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}