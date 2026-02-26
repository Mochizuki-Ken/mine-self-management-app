import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../models/app_models.dart';
import '../storages/local_store.dart';

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, List<Event>>(
  (ref) => ScheduleNotifier(),
);

class ScheduleNotifier extends StateNotifier<List<Event>> {
  ScheduleNotifier() : super(const []) {
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

  void update(String id, Event updated) {
    state = [
      for (final e in state) if (e.id == id) updated else e,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    _persist();
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    _persist();
  }
}