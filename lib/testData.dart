import 'package:flutter/material.dart';
import 'models/app_models.dart';

@immutable
class ScheduleEvent {
  const ScheduleEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.start,
    required this.end,
    required this.colorValue,
  });

  final String id;
  final String title;
  final String location;
  final DateTime start;
  final DateTime end;

  /// Store ARGB int, e.g. Color(0xFF2A8CFF).value
  final int colorValue;

  ScheduleEvent copyWith({
    String? title,
    String? location,
    DateTime? start,
    DateTime? end,
    int? colorValue,
  }) {
    return ScheduleEvent(
      id: id,
      title: title ?? this.title,
      location: location ?? this.location,
      start: start ?? this.start,
      end: end ?? this.end,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}

DateTime _todayAt(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

/// Seed events using the new Event structure.
final List<Event> seedScheduleEvents = [
  Event(
    id: 'e1',
    title: 'Standup meeting',
    location: 'Online',
    description: null,
    startAt: _todayAt(9, 30),
    endAt: _todayAt(9, 45),
    colorValue: 0xFF2A8CFF,
    busyStatus: BusyStatus.busy,
    createdAt: DateTime.now(),
  ),
  Event(
    id: 'e2',
    title: 'Deep work',
    location: 'Desk',
    description: null,
    startAt: _todayAt(10, 0),
    endAt: _todayAt(12, 0),
    colorValue: 0xFF8A2BE2,
    busyStatus: BusyStatus.busy,
    createdAt: DateTime.now(),
  ),
  Event(
    id: 'e3',
    title: 'Lunch',
    location: 'Cafe',
    description: null,
    startAt: _todayAt(12, 15),
    endAt: _todayAt(13, 0),
    colorValue: 0xFFFFC857,
    busyStatus: BusyStatus.free,
    createdAt: DateTime.now(),
  ),
  Event(
    id: 'e4',
    title: 'Dental appointment',
    location: 'Clinic',
    description: null,
    startAt: _todayAt(15, 0),
    endAt: _todayAt(15, 30),
    colorValue: 0xFFFF4D6D,
    busyStatus: BusyStatus.busy,
    createdAt: DateTime.now(),
  ),
];