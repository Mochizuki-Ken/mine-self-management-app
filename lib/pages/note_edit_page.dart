import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../providers/notes_provider.dart';
import '../tools/app_lang.dart';

/// If [noteId] is null => create new note.
/// If [noteId] is not null => edit existing note.
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
  bool _initialized = false;

  TextEditingController? _title;
  TextEditingController? _content;

  // “All detail” fields
  NoteFormat _format = NoteFormat.markdown;
  bool _pinned = false;
  bool _archived = false;
  final List<String> _tags = [];
  final List<NoteAttachment> _attachments = [];

  @override
  void dispose() {
    _title?.dispose();
    _content?.dispose();
    super.dispose();
  }

  void _ensureInitialized(Note? existing) {
    if (_initialized) return;
    _initialized = true;

    _title = TextEditingController(
      text: existing?.title ?? widget.initialTitle,
    );
    _content = TextEditingController(
      text: existing?.content ?? widget.initialContent,
    );

    _format = existing?.format ?? NoteFormat.markdown;
    _pinned = existing?.pinned ?? false;
    _archived = existing?.archived ?? false;

    _tags
      ..clear()
      ..addAll(existing?.tags ?? const []);

    _attachments
      ..clear()
      ..addAll(existing?.attachments ?? const []);
  }

  Future<void> _editTags(BuildContext context) async {
    final controller = TextEditingController(text: _tags.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit tags'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'tag1, tag2, tag3',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;

    final parsed = result
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _tags
        ..clear()
        ..addAll(parsed);
    });
  }

  Future<NoteAttachment?> _editAttachmentDialog(
    BuildContext context, {
    NoteAttachment? initial,
  }) async {
    AttachmentType type = initial?.type ?? AttachmentType.link;

    final uri = TextEditingController(text: initial?.uri ?? '');
    final name = TextEditingController(text: initial?.name ?? '');
    final mime = TextEditingController(text: initial?.mimeType ?? '');
    final size = TextEditingController(text: initial?.sizeBytes?.toString() ?? '');

    final result = await showDialog<NoteAttachment>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(initial == null ? 'Add attachment' : 'Edit attachment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AttachmentType>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: AttachmentType.link, child: Text('Link')),
                    DropdownMenuItem(value: AttachmentType.file, child: Text('File')),
                    DropdownMenuItem(value: AttachmentType.image, child: Text('Image')),
                    DropdownMenuItem(value: AttachmentType.audio, child: Text('Audio')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? AttachmentType.link),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: uri,
                  decoration: const InputDecoration(labelText: 'URI (url or local path)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name (optional)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mime,
                  decoration: const InputDecoration(labelText: 'MIME type (optional)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: size,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Size bytes (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final u = uri.text.trim();
                if (u.isEmpty) return;

                final bytes = int.tryParse(size.text.trim());

                final id = initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString();

                Navigator.pop(
                  context,
                  NoteAttachment(
                    id: id,
                    type: type,
                    uri: u,
                    name: name.text.trim().isEmpty ? null : name.text.trim(),
                    mimeType: mime.text.trim().isEmpty ? null : mime.text.trim(),
                    sizeBytes: bytes,
                    meta: initial?.meta ?? const {},
                    createdAt: initial?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    uri.dispose();
    name.dispose();
    mime.dispose();
    size.dispose();

    return result;
  }

  IconData _attachmentIcon(AttachmentType t) {
    switch (t) {
      case AttachmentType.image:
        return Icons.image_outlined;
      case AttachmentType.audio:
        return Icons.mic_none_outlined;
      case AttachmentType.file:
        return Icons.insert_drive_file_outlined;
      case AttachmentType.link:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLangProvider);

    final notes = ref.watch(notesProvider);
    final existing = widget.noteId == null
        ? null
        : notes.where((n) => n.id == widget.noteId).cast<Note?>().firstOrNull;

    _ensureInitialized(existing);

    final titleCtrl = _title!;
    final contentCtrl = _content!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'New note' : 'Edit note'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Done',
            onPressed: () {
              final now = DateTime.now();

              final title = titleCtrl.text.trim();
              final content = contentCtrl.text;

              if (widget.noteId == null) {
                final note = Note(
                  id: now.microsecondsSinceEpoch.toString(),
                  title: title.isEmpty ? '(No title)' : title,
                  content: content,
                  format: _format,
                  tags: List.unmodifiable(_tags),
                  pinned: _pinned,
                  archived: _archived,
                  attachments: List.unmodifiable(_attachments),
                  createdAt: now,
                  updatedAt: now,
                );
                ref.read(notesProvider.notifier).add(note);
              } else {
                if (existing == null) {
                  Navigator.of(context).pop();
                  return;
                }

                final updated = existing.copyWith(
                  title: title.isEmpty ? '(No title)' : title,
                  content: content,
                  format: _format,
                  tags: List.unmodifiable(_tags),
                  pinned: _pinned,
                  archived: _archived,
                  attachments: List.unmodifiable(_attachments),
                  updatedAt: now,
                );
                ref.read(notesProvider.notifier).update(updated);
              }

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
            controller: titleCtrl,
            decoration: InputDecoration(
              labelText: 'Title',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentCtrl,
            minLines: 8,
            maxLines: 20,
            decoration: InputDecoration(
              labelText: 'Content',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),

          // Format
          DropdownButtonFormField<NoteFormat>(
            value: _format,
            items: const [
              DropdownMenuItem(value: NoteFormat.markdown, child: Text('Markdown')),
              DropdownMenuItem(value: NoteFormat.plainText, child: Text('Plain text')),
            ],
            onChanged: (v) => setState(() => _format = v ?? NoteFormat.markdown),
            decoration: InputDecoration(
              labelText: 'Format',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 12),

          // Flags
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: _pinned,
                  onChanged: (v) => setState(() => _pinned = v),
                  title: const Text('Pinned'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _archived,
                  onChanged: (v) => setState(() => _archived = v),
                  title: const Text('Archived'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tags
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tags',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => _editTags(context),
                child: const Text('Edit'),
              ),
            ],
          ),
          if (_tags.isEmpty)
            Text(
              'No tags',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final tag in _tags) Chip(label: Text(tag))],
            ),

          const SizedBox(height: 18),

          // Attachments
          Row(
            children: [
              Expanded(
                child: Text(
                  'Attachments',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final a = await _editAttachmentDialog(context);
                  if (a == null) return;
                  setState(() => _attachments.add(a));
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_attachments.isEmpty)
            Text(
              'No attachments',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
            )
          else
            ...List.generate(_attachments.length, (i) {
              final a = _attachments[i];
              final label = a.name ?? a.uri;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Icon(_attachmentIcon(a.type)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () async {
                        final updated = await _editAttachmentDialog(context, initial: a);
                        if (updated == null) return;
                        setState(() => _attachments[i] = updated);
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: () => setState(() => _attachments.removeAt(i)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 18),
          Text(
            'Tip: voice input creates a note draft; attachments are manual for now.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

/// tiny helper without adding collection package
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}