import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../models/app_models.dart';
import '../storages/local_store.dart';

final eventsProvider = StateNotifierProvider<EventsController, List<Event>>((ref) {
  return EventsController();
});

class EventsController extends StateNotifier<List<Event>> {
  EventsController() : super(const []) {
    _init();
  }

  Future<void> _init() async {
    final loaded = await LocalStore.loadEvents();
    state = [...loaded]..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  void _persist() => unawaited(LocalStore.saveEvents(state));

  void add(Event e) {
    state = [...state, e]..sort((a, b) => a.startAt.compareTo(b.startAt));
    _persist();
  }

  void update(String id, Event updated) {
    state = [
      for (final e in state) if (e.id == id) updated else e,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    _persist();
  }

  void remove(String id) {
    state = [for (final e in state) if (e.id != id) e]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    _persist();
  }

  void upsert(Event e) {
    final exists = state.any((x) => x.id == e.id);
    if (!exists) {
      add(e);
      return;
    }
    update(e.id, e);
  }

  void clearAll() {
    state = const [];
    _persist();
  }
}