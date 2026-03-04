import 'package:flutter/material.dart';

/// Simple selection dialog showing a list of candidate items (title + subtitle).
/// items: list of maps with keys: id, title, subtitle (optional)
class SelectMatchDialog extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const SelectMatchDialog({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select an item'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            if (i == items.length) {
              return ListTile(
                title: const Text('None of these / Cancel'),
                onTap: () => Navigator.pop(context, null),
              );
            }
            final it = items[i];
            final title = it['title'] ?? it['name'] ?? 'Untitled';
            final subtitle = it['subtitle'] ?? it['start'] ?? it['snippet'] ?? '';
            return ListTile(
              title: Text(title),
              subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
              onTap: () => Navigator.pop(context, it),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
      ],
    );
  }
}