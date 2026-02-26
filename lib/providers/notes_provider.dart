import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../models/app_models.dart';
import '../storages/local_store.dart';

final notesProvider = StateNotifierProvider<NotesController, List<Note>>((ref) {
  return NotesController();
});

class NotesController extends StateNotifier<List<Note>> {
  NotesController() : super(const []) {
    _init();
  }

  Future<void> _init() async {
    // No seed/test data anymore
    state = await LocalStore.loadNotes();
  }

  void _persist() => unawaited(LocalStore.saveNotes(state));

  void add(Note n) {
    state = [...state, n];
    _persist();
  }

  void update(Note updated) {
    state = [
      for (final n in state) if (n.id == updated.id) updated else n,
    ];
    _persist();
  }

  void remove(String id) {
    state = [for (final n in state) if (n.id != id) n];
    _persist();
  }
}