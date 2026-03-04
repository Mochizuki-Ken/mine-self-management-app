import '../models/app_models.dart';
import '../models/recurrence_models.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _weekStartMon(DateTime d) {
  final x = _dateOnly(d);
  return x.subtract(Duration(days: x.weekday - 1)); // Monday
}

Event _instanceForDay(RecurringEventTemplate t, DateTime day) {
  final date = _dateOnly(day);
  final start = date.add(Duration(minutes: t.startMinuteOfDay));
  final end = date.add(Duration(minutes: t.endMinuteOfDay));

  return Event(
    id: 'recur:${t.id}:${date.toIso8601String()}',
    title: t.title,
    startAt: start,
    endAt: end,
    colorValue: t.colorValue,
    busyStatus: t.busyStatus,
    location: t.location,
    description: t.description,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    source: t.source,
  );
}

bool _occursOnDay(RecurringEventTemplate t, DateTime day) {
  final d = _dateOnly(day);
  final start = _dateOnly(t.startsOn);
  if (d.isBefore(start)) return false;

  final endsOn = t.endsOn == null ? null : _dateOnly(t.endsOn!);
  if (endsOn != null && d.isAfter(endsOn)) return false;

  final rule = t.rule;

  switch (rule.type) {
    case RecurrenceType.daily:
      final interval = rule.intervalDays <= 0 ? 1 : rule.intervalDays;
      final diffDays = d.difference(start).inDays;
      return diffDays % interval == 0;

    case RecurrenceType.weekly:
      if (rule.weekdays.isEmpty) return false;
      if (!rule.weekdays.contains(d.weekday)) return false;

      final intervalWeeks = rule.intervalWeeks <= 0 ? 1 : rule.intervalWeeks;
      final diffWeeks =
          _weekStartMon(d).difference(_weekStartMon(start)).inDays ~/ 7;

      return diffWeeks % intervalWeeks == 0;
  }
}

/// Returns events (recurring instances only) for a given day after applying exceptions.
List<Event> recurringInstancesForDay({
  required DateTime day,
  required List<RecurringEventTemplate> templates,
  required List<RecurringEventException> exceptions,
}) {
  final d = _dateOnly(day);

  // Map exceptions by templateId for quick lookup
  final exForDay = <String, RecurringEventException>{};
  for (final ex in exceptions) {
    if (_dateOnly(ex.date) == d) {
      exForDay[ex.templateId] = ex;
    }
  }

  final out = <Event>[];

  for (final t in templates) {
    if (!_occursOnDay(t, d)) continue;

    final ex = exForDay[t.id];
    if (ex != null && ex.type == RecurringExceptionType.skip) {
      // “This event” deletion
      continue;
    }

    var instance = _instanceForDay(t, d);

    if (ex != null && ex.type == RecurringExceptionType.override) {
      // “Edit this occurrence only”
      final startMin = ex.startMinuteOfDay ?? t.startMinuteOfDay;
      final endMin = ex.endMinuteOfDay ?? t.endMinuteOfDay;

      instance = instance.copyWith(
        title: ex.title ?? instance.title,
        startAt: d.add(Duration(minutes: startMin)),
        endAt: d.add(Duration(minutes: endMin)),
        location: ex.location ?? instance.location,
        description: ex.description ?? instance.description,
        colorValue: ex.colorValue ?? instance.colorValue,
        busyStatus: ex.busyStatus ?? instance.busyStatus,
        updatedAt: ex.updatedAt ?? instance.updatedAt,
      );
    }

    out.add(instance);
  }

  out.sort((a, b) => a.startAt.compareTo(b.startAt));
  return out;
}

/// Build events for a day:
/// - one-off events overlapping that day
/// - recurring instances (templates expanded + exceptions applied)
List<Event> eventsForDay({
  required DateTime day,
  required List<Event> oneOffEvents,
  required List<RecurringEventTemplate> templates,
  required List<RecurringEventException> exceptions, required List<RecurringEventTemplate> recurring,
}) {
  final d0 = _dateOnly(day);
  final d1 = d0.add(const Duration(days: 1));

  final oneOffForDay =
      oneOffEvents.where((e) => e.startAt.isBefore(d1) && e.endAt.isAfter(d0)).toList();

  final recurring = recurringInstancesForDay(
    day: d0,
    templates: templates,
    exceptions: exceptions,
  );

  final all = [...oneOffForDay, ...recurring]..sort((a, b) => a.startAt.compareTo(b.startAt));
  return all;
}