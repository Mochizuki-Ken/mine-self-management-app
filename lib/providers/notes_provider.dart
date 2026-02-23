// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/app_models.dart';

final notesProvider = StateNotifierProvider<NotesController, List<Note>>((ref) {
  return NotesController(seed: _seedNotes());
});

class NotesController extends StateNotifier<List<Note>> {
  NotesController({required List<Note> seed}) : super(seed);

  void add(Note n) => state = [...state, n];
}

List<Note> _seedNotes() {
  final now = DateTime.now();
  return [
    Note(
      id: 'n1',
      title: 'Meeting notes',
      content: '- Discuss roadmap\n- Action items\n',
      attachments: [
        NoteAttachment(
          id: 'a1',
          type: AttachmentType.link,
          uri: 'https://github.com',
          name: 'GitHub',
        ),
        NoteAttachment(
          id: 'a2',
          type: AttachmentType.file,
          uri: 'file:///storage/emulated/0/Download/spec.pdf',
          name: 'spec.pdf',
          mimeType: 'application/pdf',
        ),
      ],
      createdAt: now,
      updatedAt: now,
    ),
  ];
}