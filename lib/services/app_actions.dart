import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../models/recurrence_models.dart';
import '../providers/events_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/recurring_events_provider.dart';
// import '../providers/recurring_event_exceptions_provider.dart';

/// Slot returned by findFreeSlots / nextFreeSlotToday
class TimeSlot {
  final DateTime start;
  final DateTime end;

  TimeSlot(this.start, this.end);

  Map<String, String> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };
}


String? _str(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) {
    try {
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }
  return null;
}

int? _hhmmToMinutes(String? hhmm) {
  if (hhmm == null || hhmm.trim().isEmpty) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// Read a field from either a Map or object with getter.
dynamic _readField(dynamic obj, List<String> candidates) {
  if (obj == null) return null;
  if (obj is Map) {
    for (final c in candidates) {
      if (obj.containsKey(c)) return obj[c];
    }
    return null;
  }
  for (final c in candidates) {
    try {
      final dyn = obj as dynamic;
      final res = dyn is Map ? dyn[c] : _dField(dyn, c);
      if (res != null) return res;
    } catch (_) {}
  }
  return null;
}

/// Safe dynamic getter using try/catch; returns null on failure.
dynamic _dField(dynamic d, String field) {
  try {
    switch (field) {
      case 'id':
        return d.id;
      case 'title':
        return d.title;
      case 'description':
        return d.description;
      case 'content':
        return d.content;
      case 'startAt':
        return d.startAt;
      case 'start':
        return d.start;
      case 'endAt':
        return d.endAt;
      case 'end':
        return d.end;
      case 'location':
        return d.location;
      case 'due':
        return d.due;
      default:
        try {
          final map = d.toJson();
          return map[field];
        } catch (_) {
          return null;
        }
    }
  } catch (_) {
    return null;
  }
}

/// Extract event start DateTime
DateTime? _eventStart(dynamic e) {
  final candidates = ['startAt', 'start', 'begin', 'from'];
  for (final c in candidates) {
    final v = _readField(e, [c]);
    final dt = _toDateTime(v);
    if (dt != null) return dt;
  }
  if (e is Map) {
    if (e.containsKey('time') && e['time'] is Map) {
      final s = _toDateTime(e['time']['start']);
      if (s != null) return s;
    }
  }
  return null;
}

/// Extract event end DateTime
DateTime? _eventEnd(dynamic e) {
  final candidates = ['endAt', 'end', 'until', 'to'];
  for (final c in candidates) {
    final v = _readField(e, [c]);
    final dt = _toDateTime(v);
    if (dt != null) return dt;
  }
  final dur = _readField(e, ['durationMinutes', 'duration']);
  final start = _eventStart(e);
  if (start != null && dur != null) {
    final minutes = int.tryParse(dur.toString()) ?? 0;
    if (minutes > 0) return start.add(Duration(minutes: minutes));
  }
  return null;
}

String _title(dynamic e) {
  final v = _readField(e, ['title', 'name', 'summary']);
  return _str(v) ?? '';
}

String _description(dynamic e) {
  final v = _readField(e, ['description', 'content', 'notes']);
  return _str(v) ?? '';
}


/// ---------- Core (private) functions to avoid recursion ----------

List<TimeSlot> _findFreeSlotsCore(List<dynamic> events, DateTime start, DateTime end,
    {Duration minDuration = const Duration(minutes: 30)}) {
  if (!start.isBefore(end)) return [];

  final List<List<DateTime>> busy = [];
  for (final e in events) {
    final s = _eventStart(e);
    final en = _eventEnd(e);
    if (s == null || en == null) continue;
    if (en.isBefore(start) || s.isAfter(end) || en.isAtSameMomentAs(start)) continue;
    final s2 = s.isBefore(start) ? start : s;
    final e2 = en.isAfter(end) ? end : en;
    if (!s2.isBefore(e2)) continue;
    busy.add([s2, e2]);
  }

  busy.sort((a, b) => a[0].compareTo(b[0]));

  final List<List<DateTime>> merged = [];
  for (final seg in busy) {
    if (merged.isEmpty) {
      merged.add([seg[0], seg[1]]);
    } else {
      final last = merged.last;
      if (!seg[0].isAfter(last[1])) {
        if (seg[1].isAfter(last[1])) last[1] = seg[1];
      } else {
        merged.add([seg[0], seg[1]]);
      }
    }
  }

  final List<TimeSlot> free = [];
  DateTime cursor = start;
  for (final m in merged) {
    final s = m[0];
    final en = m[1];
    if (cursor.isBefore(s)) {
      if (s.difference(cursor) >= minDuration) free.add(TimeSlot(cursor, s));
    }
    cursor = en.isAfter(cursor) ? en : cursor;
  }
  if (cursor.isBefore(end)) {
    if (end.difference(cursor) >= minDuration) free.add(TimeSlot(cursor, end));
  }

  return free;
}

List<Map<String, String>> _freeSlotsToJsonCore(List<TimeSlot> slots) => slots.map((s) => s.toJson()).toList();

dynamic _getClosestEventCore(List<dynamic> events, DateTime now, {String? query}) {
  final ongoing = <Map<String, dynamic>>[];
  final upcoming = <Map<String, dynamic>>[];

  for (final e in events) {
    final s = _eventStart(e);
    final en = _eventEnd(e);
    if (s == null || en == null) continue;
    if (s.isBefore(now) && en.isAfter(now)) {
      ongoing.add({'end': en, 'event': e});
    } else if (s.isAfter(now) || s.isAtSameMomentAs(now)) {
      upcoming.add({'start': s, 'event': e});
    }
  }

  if (query != null && query.trim().isNotEmpty) {
    final qTokens = _tokenize(query);
    ongoing.retainWhere((m) {
      final t = _title(m['event']);
      return _tokenize(t).intersection(qTokens).isNotEmpty || t.toLowerCase().contains(query.toLowerCase());
    });
    upcoming.retainWhere((m) {
      final t = _title(m['event']);
      return _tokenize(t).intersection(qTokens).isNotEmpty || t.toLowerCase().contains(query.toLowerCase());
    });
  }

  if (ongoing.isNotEmpty) {
    ongoing.sort((a, b) => (a['end'] as DateTime).compareTo(b['end'] as DateTime));
    return ongoing.first['event'];
  }
  if (upcoming.isNotEmpty) {
    upcoming.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
    return upcoming.first['event'];
  }
  return null;
}

List<dynamic> _eventsInRangeCore(List<dynamic> events, DateTime start, DateTime end) {
  final out = <dynamic>[];
  for (final e in events) {
    final s = _eventStart(e);
    final en = _eventEnd(e);
    if (s == null || en == null) continue;
    if (s.isBefore(end) && en.isAfter(start)) out.add(e);
  }
  return out;
}

Set<String> _tokenize(String? s) {
  if (s == null || s.trim().isEmpty) return {};
  return s.toLowerCase().split(RegExp(r'\W+')).where((t) => t.isNotEmpty).toSet();
}

List<Map<String, dynamic>> _searchEventsByTextCore(List<dynamic> events, String query, {int limit = 6}) {
  final q = query.trim();
  if (q.isEmpty) return [];
  final qTokens = _tokenize(q);
  final results = <Map<String, dynamic>>[];

  for (final e in events) {
    final text = '${_title(e)} ${_description(e)} ${_readField(e, ['location']) ?? ''}';
    final tTokens = _tokenize(text);
    double score = 0.0;
    if (tTokens.isNotEmpty && qTokens.isNotEmpty) {
      final inter = tTokens.intersection(qTokens).length;
      final uni = tTokens.union(qTokens).length;
      score = uni > 0 ? inter / uni : 0.0;
    }
    if (text.toLowerCase().contains(q.toLowerCase())) score += 0.1;
    if (score > 0.0) results.add({'item': e, 'score': score});
  }

  results.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  if (results.length > limit) return results.sublist(0, limit);
  return results;
}

List<Map<String, dynamic>> _searchTasksByTextCore(List<dynamic> tasks, String query, {int limit = 6}) {
  final q = query.trim();
  if (q.isEmpty) return [];
  final results = <Map<String, dynamic>>[];
  final qTokens = _tokenize(q);
  for (final t in tasks) {
    final text = '${_readField(t, ['title']) ?? ''} ${_readField(t, ['description']) ?? ''}';
    final tokens = _tokenize(text);
    double score = tokens.isNotEmpty && qTokens.isNotEmpty ? (tokens.intersection(qTokens).length / tokens.union(qTokens).length) : 0.0;
    if (text.toLowerCase().contains(q.toLowerCase())) score += 0.1;
    if (score > 0) results.add({'item': t, 'score': score});
  }
  results.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  if (results.length > limit) return results.sublist(0, limit);
  return results;
}

List<Map<String, dynamic>> _searchNotesByTextCore(List<dynamic> notes, String query, {int limit = 6}) {
  final q = query.trim();
  if (q.isEmpty) return [];
  final results = <Map<String, dynamic>>[];
  final qTokens = _tokenize(q);
  for (final n in notes) {
    final text = '${_readField(n, ['title']) ?? ''} ${_readField(n, ['content', 'body', 'description']) ?? ''}';
    final tokens = _tokenize(text);
    double score = tokens.isNotEmpty && qTokens.isNotEmpty ? (tokens.intersection(qTokens).length / tokens.union(qTokens).length) : 0.0;
    if (text.toLowerCase().contains(q.toLowerCase())) score += 0.1;
    if (score > 0) results.add({'item': n, 'score': score});
  }
  results.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  if (results.length > limit) return results.sublist(0, limit);
  return results;
}

List<Map<String, dynamic>> _searchRecurringEventsByTextCore(List<RecurringEventTemplate> templates, String query, {int limit = 6}) {
  final q = query.trim();
  if (q.isEmpty) return [];
  final qTokens = _tokenize(q);
  final results = <Map<String, dynamic>>[];
  for (final t in templates) {
    final text = '${t.title} ${t.description ?? ''} ${t.location ?? ''}';
    final tokens = _tokenize(text);
    double score = tokens.isNotEmpty && qTokens.isNotEmpty ? (tokens.intersection(qTokens).length / tokens.union(qTokens).length) : 0.0;
    if (text.toLowerCase().contains(q.toLowerCase())) score += 0.1;
    if (score > 0) results.add({'item': t, 'score': score});
  }
  results.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  if (results.length > limit) return results.sublist(0, limit);
  return results;
}

List<Map<String, dynamic>> _suggestLinkedItemsCore({
  required String title,
  String? description,
  DateTime? start,
  DateTime? end,
  required List<dynamic> tasks,
  required List<dynamic> notes,
  required List<dynamic> events,
  int maxSuggestions = 3,
}) {
  final query = '$title ${description ?? ''}'.trim();
  if (query.isEmpty) return [];

  final taskMatches = _searchTasksByTextCore(tasks, query, limit: maxSuggestions);
  final noteMatches = _searchNotesByTextCore(notes, query, limit: maxSuggestions);
  final eventMatches = _searchEventsByTextCore(events, query, limit: maxSuggestions);

  final suggestions = <Map<String, dynamic>>[];

  for (final m in taskMatches) {
    final t = m['item'];
    suggestions.add({
      'type': 'task',
      'title': _readField(t, ['title']) ?? _title(t),
      'content': _readField(t, ['description']) ?? '',
      'reason': 'Similar task title/content',
      'confidence': (m['score'] as double) * 0.9 + 0.05
    });
  }
  for (final m in noteMatches) {
    final n = m['item'];
    suggestions.add({
      'type': 'note',
      'title': _readField(n, ['title']) ?? _title(n),
      'content': (_readField(n, ['content', 'description']) ?? _description(n))!,
      'reason': 'Related note content',
      'confidence': (m['score'] as double) * 0.9 + 0.03
    });
  }
  for (final m in eventMatches) {
    final e = m['item'];
    suggestions.add({
      'type': 'event',
      'title': _title(e),
      'start': _eventStart(e)?.toIso8601String(),
      'end': _eventEnd(e)?.toIso8601String(),
      'reason': 'Similar event title/time',
      'confidence': (m['score'] as double) * 0.85 + 0.02
    });
  }

  suggestions.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
  if (suggestions.length > maxSuggestions) return suggestions.sublist(0, maxSuggestions);
  return suggestions;
}

List<Map<String, dynamic>> _suggestionsToJsonCore(List<Map<String, dynamic>> suggestions) {
  return suggestions.map((s) {
    final out = Map<String, dynamic>.from(s);
    if (out.containsKey('confidence')) out['confidence'] = (out['confidence'] as num).toDouble();
    return out;
  }).toList();
}

TimeSlot? _nextFreeSlotTodayCore({required DateTime now, required List<dynamic> events, Duration minDuration = const Duration(minutes: 15)}) {
  final start = now;
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final slots = _findFreeSlotsCore(events, start, end, minDuration: minDuration);
  if (slots.isEmpty) return null;
  return slots.first;
}

/// ---------- AppActions class (public API) ----------
class AppActions {
  AppActions();

  // Read-only delegations to core
  List<TimeSlot> findFreeSlots(List<dynamic> events, DateTime start, DateTime end, {Duration minDuration = const Duration(minutes: 30)}) =>
      _findFreeSlotsCore(events, start, end, minDuration: minDuration);

  List<Map<String, String>> freeSlotsToJson(List<TimeSlot> slots) => _freeSlotsToJsonCore(slots);

  dynamic getClosestEvent(List<dynamic> events, DateTime now, {String? query}) =>
      _getClosestEventCore(events, now, query: query);

  List<dynamic> eventsInRange(List<dynamic> events, DateTime start, DateTime end) =>
      _eventsInRangeCore(events, start, end);

  List<Map<String, dynamic>> searchEventsByText(List<dynamic> events, String query, {int limit = 6}) =>
      _searchEventsByTextCore(events, query, limit: limit);

  List<Map<String, dynamic>> searchTasksByText(List<dynamic> tasks, String query, {int limit = 6}) =>
      _searchTasksByTextCore(tasks, query, limit: limit);

  List<Map<String, dynamic>> searchNotesByText(List<dynamic> notes, String query, {int limit = 6}) =>
      _searchNotesByTextCore(notes, query, limit: limit);

  List<Map<String, dynamic>> searchRecurringEventsByText(List<RecurringEventTemplate> templates, String query, {int limit = 6}) =>
      _searchRecurringEventsByTextCore(templates, query, limit: limit);

  List<Map<String, dynamic>> suggestLinkedItems({
    required String title,
    String? description,
    DateTime? start,
    DateTime? end,
    required List<dynamic> tasks,
    required List<dynamic> notes,
    required List<dynamic> events,
    int maxSuggestions = 3,
  }) =>
      _suggestLinkedItemsCore(
        title: title,
        description: description,
        start: start,
        end: end,
        tasks: tasks,
        notes: notes,
        events: events,
        maxSuggestions: maxSuggestions,
      );

  List<Map<String, dynamic>> suggestionsToJson(List<Map<String, dynamic>> suggestions) =>
      _suggestionsToJsonCore(suggestions);

  TimeSlot? nextFreeSlotTodayLocal({required DateTime now, required List<dynamic> events, Duration minDuration = const Duration(minutes: 15)}) =>
      _nextFreeSlotTodayCore(now: now, events: events, minDuration: minDuration);

  // ---------- Write methods ----------

  Future<void> createEventFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    final title = (payload['title'] as String?)?.trim();
    if (title == null || title.isEmpty) throw ArgumentError('title is required');

    DateTime? start;
    DateTime? end;

    if (payload['start'] != null) start = DateTime.tryParse(payload['start'].toString());
    if (payload['end'] != null) end = DateTime.tryParse(payload['end'].toString());

    if (start != null && end == null && payload['durationMinutes'] != null) {
      final mins = int.tryParse(payload['durationMinutes'].toString());
      if (mins != null && mins > 0) end = start.add(Duration(minutes: mins));
    }

    if (start == null || end == null) {
      throw ArgumentError('start and end (or durationMinutes) are required');
    }

    final location = (payload['location'] as String?) ?? '';
    final description = (payload['description'] as String?) ?? '';
    final id = (payload['id'] as String?) ?? const Uuid().v4();

    final event = Event(
      id: id,
      title: title,
      description: description,
      location: location,
      startAt: start,
      endAt: end,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      source: ItemSource.ai,
    );

    ref.read(eventsProvider.notifier).add(event);
  }

  Future<void> editEventFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    final id = (payload['id'] as String?) ?? '';
    if (id.isEmpty) throw ArgumentError('id is required for edit');

    final notifier = ref.read(eventsProvider.notifier);
    final current = ref.read(eventsProvider).firstWhere(
          (e) => e.id == id,
          orElse: () => throw ArgumentError('event not found'),
        );

    DateTime? start = current.startAt;
    DateTime? end = current.endAt;

    if (payload['start'] != null) start = DateTime.tryParse(payload['start'].toString()) ?? start;
    if (payload['end'] != null) end = DateTime.tryParse(payload['end'].toString()) ?? end;


    final updated = current.copyWith(
      title: (payload['title'] as String?) ?? current.title,
      description: (payload['description'] as String?) ?? current.description,
      location: (payload['location'] as String?) ?? current.location,
      startAt: start,
      endAt: end,
      updatedAt: DateTime.now(),
      source: ItemSource.ai,
    );

    notifier.update(id, updated);
  }

  Future<void> deleteEventById(String id, WidgetRef ref) async {
    if (id.isEmpty) throw ArgumentError('id is required for delete');
    ref.read(eventsProvider.notifier).remove(id);
  }

  Future<void> createTaskFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    final title = (payload['title'] as String?)?.trim();
    if (title == null || title.isEmpty) throw ArgumentError('title is required');

    final description = (payload['description'] as String?) ?? '';
    final id = (payload['id'] as String?) ?? const Uuid().v4();

    TaskDue due = const TaskDue.none();
    if (payload['due'] != null) {
      final dt = DateTime.tryParse(payload['due'].toString());
      if (dt != null) due = TaskDue.at(dt);
    }

    final now = DateTime.now();
    final task = Task(
      id: id,
      title: title,
      description: description,
      due: due,
      createdAt: now,
      updatedAt: now,
      source: ItemSource.ai,
    );

    ref.read(tasksProvider.notifier).add(task);
  }

  Future<void> editTaskFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    final id = (payload['id'] as String?) ?? '';
    if (id.isEmpty) throw ArgumentError('id is required for edit');

    final notifier = ref.read(tasksProvider.notifier);
    final current = ref.read(tasksProvider).firstWhere(
          (t) => t.id == id,
          orElse: () => throw ArgumentError('task not found'),
        );

    TaskDue due = current.due;
    if (payload['due'] != null) {
      final dt = DateTime.tryParse(payload['due'].toString());
      if (dt != null) due = TaskDue.at(dt);
    }

    final updated = current.copyWith(
      title: (payload['title'] as String?) ?? current.title,
      description: (payload['description'] as String?) ?? current.description,
      due: due,
      updatedAt: DateTime.now(),
      source: ItemSource.ai,
    );

    notifier.update(id, updated);
  }

  Future<void> deleteTaskById(String id, WidgetRef ref) async {
    if (id.isEmpty) throw ArgumentError('id is required for delete');
    ref.read(tasksProvider.notifier).remove(id);
  }

  Future<void> createNoteFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    final title = (payload['title'] as String?)?.trim();
    if (title == null || title.isEmpty) throw ArgumentError('title is required');

    final content = (payload['content'] as String?) ?? (payload['description'] as String?) ?? '';
    final id = (payload['id'] as String?) ?? const Uuid().v4();
    final now = DateTime.now();

    final note = Note(
      id: id,
      title: title,
      content: content,
      format: NoteFormat.markdown,
      createdAt: now,
      updatedAt: now,
      source: ItemSource.ai,
    );

    ref.read(notesProvider.notifier).add(note);
  }

  Future<void> editNoteFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    final id = (payload['id'] as String?) ?? '';
    if (id.isEmpty) throw ArgumentError('id is required for edit');

    final notifier = ref.read(notesProvider.notifier);
    final current = ref.read(notesProvider).firstWhere(
          (n) => n.id == id,
          orElse: () => throw ArgumentError('note not found'),
        );

    final updated = current.copyWith(
      title: (payload['title'] as String?) ?? current.title,
      content: (payload['content'] as String?) ?? (payload['description'] as String?) ?? current.content,
      updatedAt: DateTime.now(),
      source: ItemSource.ai,
    );

    notifier.update(updated);
  }

  Future<void> deleteNoteById(String id, WidgetRef ref) async {
    if (id.isEmpty) throw ArgumentError('id is required for delete');
    ref.read(notesProvider.notifier).remove(id);
  }

  // ---------- Recurring events ----------

  RecurrenceRule _buildRule(Map<String, dynamic> payload) {
    final recur = (payload['recurrence'] as Map?)?.cast<String, dynamic>() ?? {};
    final typeStr = (recur['type'] as String? ?? '').toLowerCase();
    if (typeStr == 'weekly') {
      final intervalWeeks = int.tryParse(recur['intervalWeeks']?.toString() ?? '') ?? 1;
      final weekdaysRaw = recur['weekdays'] as List?;
      final weekdays = weekdaysRaw == null
          ? <int>{}
          : weekdaysRaw.map((e) => int.tryParse(e.toString()) ?? -1).where((e) => e >= 1 && e <= 7).toSet();
      return RecurrenceRule.weekly(intervalWeeks: max(1, intervalWeeks), weekdays: weekdays.isEmpty ? {DateTime.monday} : weekdays);
    }
    // default daily
    final intervalDays = int.tryParse(recur['intervalDays']?.toString() ?? '') ?? 1;
    return RecurrenceRule.daily(intervalDays: max(1, intervalDays));
  }

  int _extractMinuteOfDay(Map<String, dynamic> payload, String keyTime, {String? fallbackTimeKey, int? durationMinutes, int? fromMinute}) {
    // try direct minute
    final minuteRaw = payload[keyTime + 'MinuteOfDay'];
    if (minuteRaw != null) {
      final m = int.tryParse(minuteRaw.toString());
      if (m != null && m >= 0 && m < 1440) return m;
    }

    // try HH:mm
    final hhmmRaw = payload[keyTime] ?? (fallbackTimeKey != null ? payload[fallbackTimeKey] : null);
    final m2 = _hhmmToMinutes(_str(hhmmRaw));
    if (m2 != null) return m2;

    // try ISO DateTime -> take time part
    final dt = _toDateTime(hhmmRaw);
    if (dt != null) return dt.hour * 60 + dt.minute;

    // compute from duration
    if (durationMinutes != null && fromMinute != null && durationMinutes > 0) {
      return fromMinute + durationMinutes;
    }

    throw ArgumentError('missing $keyTime');
  }

  Future<void> createRecurringEventFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    final title = (payload['title'] as String?)?.trim();
    if (title == null || title.isEmpty) throw ArgumentError('title is required');

    final startsOn = _toDateTime(payload['startsOn']) ??
        _toDateTime(payload['startDate']) ??
        _toDateTime(payload['date']) ??
        _toDateTime(payload['start'])?.toLocal();
    if (startsOn == null) throw ArgumentError('startsOn (date) is required');

    final durationMinutes = payload['durationMinutes'] == null ? null : int.tryParse(payload['durationMinutes'].toString());

    final startMinute = _extractMinuteOfDay(payload, 'startTime',
        fallbackTimeKey: 'start', durationMinutes: null, fromMinute: null);
    final endMinute =
        _extractMinuteOfDay(payload, 'endTime', fallbackTimeKey: 'end', durationMinutes: durationMinutes, fromMinute: startMinute);

    if (endMinute <= startMinute) {
      throw ArgumentError('endTime must be after startTime');
    }

    final rule = _buildRule(payload);
    final endsOn = _toDateTime(payload['endsOn']);

    final template = RecurringEventTemplate(
      id: (payload['id'] as String?) ?? const Uuid().v4(),
      title: title,
      startMinuteOfDay: startMinute,
      endMinuteOfDay: endMinute,
      colorValue: 0xFF2A8CFF,
      busyStatus: BusyStatus.busy,
      location: payload['location'] as String?,
      description: payload['description'] as String?,
      linkedTaskIds: const [],
      linkedNoteIds: const [],
      rule: rule,
      startsOn: DateTime(startsOn.year, startsOn.month, startsOn.day),
      endsOn: endsOn == null ? null : DateTime(endsOn.year, endsOn.month, endsOn.day),
      source: ItemSource.ai,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(recurringEventsProvider.notifier).add(template);
  }

  Future<void> editRecurringEventFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    final id = (payload['id'] as String?) ?? '';
    if (id.isEmpty) throw ArgumentError('id is required for edit');

    final notifier = ref.read(recurringEventsProvider.notifier);
    final current = ref.read(recurringEventsProvider).firstWhere(
          (t) => t.id == id,
          orElse: () => throw ArgumentError('recurring event not found'),
        );

    int startMinute = current.startMinuteOfDay;
    int endMinute = current.endMinuteOfDay;

    final durationMinutes = payload['durationMinutes'] == null ? null : int.tryParse(payload['durationMinutes'].toString());

    if (payload.containsKey('startTime') || payload.containsKey('start')) {
      startMinute = _extractMinuteOfDay(payload, 'startTime', fallbackTimeKey: 'start');
    }
    if (payload.containsKey('endTime') || payload.containsKey('end') || durationMinutes != null) {
      endMinute = _extractMinuteOfDay(payload, 'endTime', fallbackTimeKey: 'end', durationMinutes: durationMinutes, fromMinute: startMinute);
    }
    if (endMinute <= startMinute) throw ArgumentError('endTime must be after startTime');

    RecurrenceRule rule = current.rule;
    if (payload.containsKey('recurrence')) {
      rule = _buildRule(payload);
    }

    DateTime? startsOn = current.startsOn;
    if (payload['startsOn'] != null || payload['startDate'] != null || payload['date'] != null) {
      final s = _toDateTime(payload['startsOn'] ?? payload['startDate'] ?? payload['date'] ?? payload['start']);
      if (s != null) startsOn = DateTime(s.year, s.month, s.day);
    }

    DateTime? endsOn = current.endsOn;
    if (payload['endsOn'] != null) {
      final e = _toDateTime(payload['endsOn']);
      if (e != null) endsOn = DateTime(e.year, e.month, e.day);
    }

    final updated = current.copyWith(
      title: (payload['title'] as String?) ?? current.title,
      description: (payload['description'] as String?) ?? current.description,
      location: (payload['location'] as String?) ?? current.location,
      startMinuteOfDay: startMinute,
      endMinuteOfDay: endMinute,
      rule: rule,
      startsOn: startsOn,
      endsOn: endsOn,
      updatedAt: DateTime.now(),
      source: ItemSource.ai,
    );

    await notifier.update(updated);
  }

  Future<void> deleteRecurringEventById(String id, WidgetRef ref) async {
    if (id.isEmpty) throw ArgumentError('id is required for delete');
    await ref.read(recurringEventsProvider.notifier).remove(id);
  }
}