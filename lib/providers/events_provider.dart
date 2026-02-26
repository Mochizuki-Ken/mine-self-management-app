import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../models/app_models.dart';
import '../storages/local_store.dart';

final eventsProvider =
    StateNotifierProvider<EventsController, List<Event>>((ref) {
  return EventsController();
});

class EventsController extends StateNotifier<List<Event>> {
  EventsController() : super(const []) {
    _init();
  }

  Future<void> _init() async {
    // No seed/test data anymore
    final loaded = await LocalStore.loadEvents();
    state = [...loaded]..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  void _persist() => unawaited(LocalStore.saveEvents(state));

  void add(Event e) {
    state = [...state, e]..sort((a, b) => a.startAt.compareTo(b.startAt));
    _persist();
  }

  void update(Event e) {
    state = [
      for (final x in state) if (x.id == e.id) e else x,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    _persist();
  }

  void remove(String id) {
    state = state.where((x) => x.id != id).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    _persist();
  }
}