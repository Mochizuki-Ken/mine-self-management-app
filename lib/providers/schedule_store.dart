import 'package:flutter_riverpod/legacy.dart';

import '../models/app_models.dart';
import '../testData.dart';

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, List<Event>>(
  (ref) => ScheduleNotifier(),
);

class ScheduleNotifier extends StateNotifier<List<Event>> {
  ScheduleNotifier() : super(List.of(seedScheduleEvents));

  void add(Event e) {
    state = [...state, e]..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  void update(String id, Event updated) {
    state = [
      for (final e in state) if (e.id == id) updated else e,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}