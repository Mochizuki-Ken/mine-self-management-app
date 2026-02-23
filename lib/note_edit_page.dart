import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tools/app_lang.dart';

/// If [noteId] is null => create new note.
/// If [noteId] is not null => edit existing note (TODO: wire to notesProvider).
class NoteEditPage extends ConsumerStatefulWidget {
  const NoteEditPage({
    super.key,
    this.noteId,
    this.initialTitle = '',
    this.initialContent = '',
  });

  final String? noteId;
  final String initialTitle;
  final String initialContent;

  @override
  ConsumerState<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends ConsumerState<NoteEditPage> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initialTitle);
  late final TextEditingController _content =
      TextEditingController(text: widget.initialContent);

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLangProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'New note' : 'Edit note'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Done',
            onPressed: () {
              // TODO: save to notesProvider (add/update) + pop
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: 'Title',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 8,
            maxLines: 20,
            decoration: InputDecoration(
              labelText: 'Content',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'AI will handle add/edit actions in the future.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}