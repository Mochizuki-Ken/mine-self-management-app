import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../providers/events_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/tasks_provider.dart';

List<String> _uniq(List<String> xs) => xs.toSet().toList();

class LinkSyncService {
  LinkSyncService(this.ref);
  final Ref ref;

  void syncFromEvent(Event updatedEvent) {
    _syncEventToTasksAndNotes(updatedEvent);
    _enforceClosure();
  }

  void syncFromTask(Task updatedTask) {
    _syncTaskToEventsAndNotes(updatedTask);
    _enforceClosure();
  }

  void syncFromNote(Note updatedNote) {
    _syncNoteToEventsAndTasks(updatedNote);
    _enforceClosure();
  }

  void _syncEventToTasksAndNotes(Event updatedEvent) {
    final tasks = ref.read(tasksProvider);
    final notes = ref.read(notesProvider);

    for (final t in tasks) {
      final shouldLink = updatedEvent.linkedTaskIds.contains(t.id);
      final hasLink = t.linkedEventIds.contains(updatedEvent.id);
      if (shouldLink == hasLink) continue;

      final next = shouldLink
          ? _uniq([...t.linkedEventIds, updatedEvent.id])
          : t.linkedEventIds.where((x) => x != updatedEvent.id).toList();

      ref.read(tasksProvider.notifier).update(
            t.id,
            t.copyWith(linkedEventIds: next, updatedAt: DateTime.now()),
          );
    }

    for (final n in notes) {
      final shouldLink = updatedEvent.linkedNoteIds.contains(n.id);
      final hasLink = n.linkedEventIds.contains(updatedEvent.id);
      if (shouldLink == hasLink) continue;

      final next = shouldLink
          ? _uniq([...n.linkedEventIds, updatedEvent.id])
          : n.linkedEventIds.where((x) => x != updatedEvent.id).toList();

      ref.read(notesProvider.notifier).update(
            n.copyWith(linkedEventIds: next, updatedAt: DateTime.now()),
          );
    }
  }

  void _syncTaskToEventsAndNotes(Task updatedTask) {
    final events = ref.read(eventsProvider);
    final notes = ref.read(notesProvider);

    for (final e in events) {
      final shouldLink = updatedTask.linkedEventIds.contains(e.id);
      final hasLink = e.linkedTaskIds.contains(updatedTask.id);
      if (shouldLink == hasLink) continue;

      final next = shouldLink
          ? _uniq([...e.linkedTaskIds, updatedTask.id])
          : e.linkedTaskIds.where((x) => x != updatedTask.id).toList();

      ref.read(eventsProvider.notifier).update(
            e.id,
            e.copyWith(linkedTaskIds: next, updatedAt: DateTime.now()),
          );
    }

    for (final n in notes) {
      final shouldLink = updatedTask.linkedNoteIds.contains(n.id);
      final hasLink = n.linkedTaskIds.contains(updatedTask.id);
      if (shouldLink == hasLink) continue;

      final next = shouldLink
          ? _uniq([...n.linkedTaskIds, updatedTask.id])
          : n.linkedTaskIds.where((x) => x != updatedTask.id).toList();

      ref.read(notesProvider.notifier).update(
            n.copyWith(linkedTaskIds: next, updatedAt: DateTime.now()),
          );
    }
  }

  void _syncNoteToEventsAndTasks(Note updatedNote) {
    final events = ref.read(eventsProvider);
    final tasks = ref.read(tasksProvider);

    for (final e in events) {
      final shouldLink = updatedNote.linkedEventIds.contains(e.id);
      final hasLink = e.linkedNoteIds.contains(updatedNote.id);
      if (shouldLink == hasLink) continue;

      final next = shouldLink
          ? _uniq([...e.linkedNoteIds, updatedNote.id])
          : e.linkedNoteIds.where((x) => x != updatedNote.id).toList();

      ref.read(eventsProvider.notifier).update(
            e.id,
            e.copyWith(linkedNoteIds: next, updatedAt: DateTime.now()),
          );
    }

    for (final t in tasks) {
      final shouldLink = updatedNote.linkedTaskIds.contains(t.id);
      final hasLink = t.linkedNoteIds.contains(updatedNote.id);
      if (shouldLink == hasLink) continue;

      final next = shouldLink
          ? _uniq([...t.linkedNoteIds, updatedNote.id])
          : t.linkedNoteIds.where((x) => x != updatedNote.id).toList();

      ref.read(tasksProvider.notifier).update(
            t.id,
            t.copyWith(linkedNoteIds: next, updatedAt: DateTime.now()),
          );
    }
  }

  /// Closure rules (what you asked):
  /// - If Event A ↔ Task X and Note B ↔ Task X => Event A ↔ Note B.
  /// - If Task X links recurring series => Notes linked to Task X also link that series.
  void _enforceClosure() {
    final tasks = ref.read(tasksProvider);
    final notes = ref.read(notesProvider);
    final events = ref.read(eventsProvider);

    final notesById = {for (final n in notes) n.id: n};
    final eventsById = {for (final e in events) e.id: e};

    for (final t in tasks) {
      final eventIds = t.linkedEventIds.toSet();
      final noteIds = t.linkedNoteIds.toSet();
      final recurIds = t.linkedRecurringTemplateIds.toSet();

      // Event <-> Note via Task
      if (eventIds.isNotEmpty && noteIds.isNotEmpty) {
        for (final eid in eventIds) {
          final e = eventsById[eid];
          if (e == null) continue;

          final missingNotes = noteIds.difference(e.linkedNoteIds.toSet());
          if (missingNotes.isEmpty) continue;

          final updated = e.copyWith(
            linkedNoteIds: _uniq([...e.linkedNoteIds, ...missingNotes]),
            updatedAt: DateTime.now(),
          );
          ref.read(eventsProvider.notifier).update(updated.id, updated);
          eventsById[updated.id] = updated;
        }

        for (final nid in noteIds) {
          final n = notesById[nid];
          if (n == null) continue;

          final missingEvents = eventIds.difference(n.linkedEventIds.toSet());
          if (missingEvents.isEmpty) continue;

          final updated = n.copyWith(
            linkedEventIds: _uniq([...n.linkedEventIds, ...missingEvents]),
            updatedAt: DateTime.now(),
          );
          ref.read(notesProvider.notifier).update(updated);
          notesById[updated.id] = updated;
        }
      }

      // Recurring series -> Notes via Task
      if (recurIds.isNotEmpty && noteIds.isNotEmpty) {
        for (final nid in noteIds) {
          final n = notesById[nid];
          if (n == null) continue;

          final missing = recurIds.difference(n.linkedRecurringTemplateIds.toSet());
          if (missing.isEmpty) continue;

          final updated = n.copyWith(
            linkedRecurringTemplateIds: _uniq([...n.linkedRecurringTemplateIds, ...missing]),
            updatedAt: DateTime.now(),
          );
          ref.read(notesProvider.notifier).update(updated);
          notesById[updated.id] = updated;
        }
      }
    }
  }
}

final linkSyncServiceProvider = Provider<LinkSyncService>((ref) {
  return LinkSyncService(ref);
});