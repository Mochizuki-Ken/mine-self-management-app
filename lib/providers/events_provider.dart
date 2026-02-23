import 'package:flutter_riverpod/legacy.dart';
import '../models/app_models.dart';

final eventsProvider =
    StateNotifierProvider<EventsController, List<Event>>((ref) {
  return EventsController(seed: _seedEvents());
});

class EventsController extends StateNotifier<List<Event>> {
  EventsController({required List<Event> seed})
      : super(List.of(seed)..sort((a, b) => a.startAt.compareTo(b.startAt)));

  void add(Event e) =>
      state = [...state, e]..sort((a, b) => a.startAt.compareTo(b.startAt));

  void update(Event e) => state = [
        for (final x in state) if (x.id == e.id) e else x,
      ]..sort((a, b) => a.startAt.compareTo(b.startAt));

  void remove(String id) =>
      state = state.where((x) => x.id != id).toList()
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
}

List<Event> _seedEvents() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return [
    Event(
      id: 'e1',
      title: 'Daily standup',
      startAt: today.add(const Duration(hours: 10)),
      endAt: today.add(const Duration(hours: 10, minutes: 30)),
      colorValue: 0xFFFF5A5F,
      busyStatus: BusyStatus.busy,
      createdAt: now,
    ),
    Event(
      id: 'e2',
      title: 'Lunch (free)',
      startAt: today.add(const Duration(hours: 12)),
      endAt: today.add(const Duration(hours: 13)),
      colorValue: 0xFF00D18F,
      busyStatus: BusyStatus.free,
      createdAt: now,
    ),
    Event(
      id: 'e3',
      title: 'Focus work',
      startAt: today.add(const Duration(hours: 15)),
      endAt: today.add(const Duration(hours: 16, minutes: 30)),
      colorValue: 0xFFFFC857,
      busyStatus: BusyStatus.busy,
      createdAt: now,
    ),
  ];
}