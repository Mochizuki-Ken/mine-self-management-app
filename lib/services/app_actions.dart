
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// ---------- Field extraction helpers ----------

T? _asType<T>(dynamic v) {
  if (v == null) return null;
  try {
    return v as T;
  } catch (_) {
    return null;
  }
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

/// Read a field from either a Map or object with getter.
/// Tries several common names for start/end/title/etc.
dynamic _readField(dynamic obj, List<String> candidates) {
  if (obj == null) return null;
  if (obj is Map) {
    for (final c in candidates) {
      if (obj.containsKey(c)) return obj[c];
    }
    return null;
  }
  // typed object: attempt dynamic access via common getters
  for (final c in candidates) {
    try {
      final dyn = obj as dynamic;
      final res = dyn is Map ? dyn[c] : _dField(dyn, c);
      if (res != null) return res;
    } catch (_) {
      // ignore and continue
    }
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
        // try toJson fallback
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

/// Extract event start DateTime (tries common fields)
DateTime? _eventStart(dynamic e) {
  final candidates = ['startAt', 'start', 'begin', 'from'];
  for (final c in candidates) {
    final v = _readField(e, [c]);
    final dt = _toDateTime(v);
    if (dt != null) return dt;
  }
  // as fallback, check nested map keys
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
  // fallback: some objects may have duration; try start + durationMinutes
  final dur = _readField(e, ['durationMinutes', 'duration']);
  final start = _eventStart(e);
  if (start != null && dur != null) {
    final minutes = int.tryParse(dur.toString()) ?? 0;
    if (minutes > 0) return start.add(Duration(minutes: minutes));
  }
  return null;
}

/// Extract title
String _title(dynamic e) {
  final v = _readField(e, ['title', 'name', 'summary']);
  return _str(v) ?? '';
}

/// Extract description / content
String _description(dynamic e) {
  final v = _readField(e, ['description', 'content', 'notes']);
  return _str(v) ?? '';
}

/// Extract id
String? _id(dynamic e) {
  final v = _readField(e, ['id', 'uid', 'eventId']);
  return _str(v);
}

/// ---------- Core functions ----------

/// Find free time slots between [start, end) given existing events list.
/// events: List<dynamic> where each event should have start/end (DateTime or ISO string).
List<TimeSlot> findFreeSlots(List<dynamic> events, DateTime start, DateTime end,
    {Duration minDuration = const Duration(minutes: 30)}) {
  if (!start.isBefore(end)) return [];

  // Collect busy intervals that overlap [start, end)
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

  // Sort busy intervals
  busy.sort((a, b) => a[0].compareTo(b[0]));

  // Merge intervals
  final List<List<DateTime>> merged = [];
  for (final seg in busy) {
    if (merged.isEmpty) {
      merged.add([seg[0], seg[1]]);
    } else {
      final last = merged.last;
      if (!seg[0].isAfter(last[1])) {
        // overlap
        if (seg[1].isAfter(last[1])) last[1] = seg[1];
      } else {
        merged.add([seg[0], seg[1]]);
      }
    }
  }

  // Compute gaps
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

List<Map<String, String>> freeSlotsToJson(List<TimeSlot> slots) {
  return slots.map((s) => s.toJson()).toList();
}

/// Return the currently ongoing event (that includes now) or the next upcoming event after now.
/// If query is provided, filter by text match (title/description).
dynamic getClosestEvent(List<dynamic> events, DateTime now, {String? query}) {
  final List<Map<String, dynamic>> ongoing = [];
  final List<Map<String, dynamic>> upcoming = [];

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

/// Return events overlapping [start,end)
List<dynamic> eventsInRange(List<dynamic> events, DateTime start, DateTime end) {
  final out = <dynamic>[];
  for (final e in events) {
    final s = _eventStart(e);
    final en = _eventEnd(e);
    if (s == null || en == null) continue;
    if (s.isBefore(end) && en.isAfter(start)) out.add(e);
  }
  return out;
}

/// Simple tokenization
Set<String> _tokenize(String? s) {
  if (s == null || s.trim().isEmpty) return {};
  final tokens = s.toLowerCase().split(RegExp(r'\W+')).where((t) => t.isNotEmpty).toSet();
  return tokens;
}

/// Search events by text, return list of { item: event, score: double }
List<Map<String, dynamic>> searchEventsByText(List<dynamic> events, String query, {int limit = 6}) {
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

/// Search tasks
List<Map<String, dynamic>> searchTasksByText(List<dynamic> tasks, String query, {int limit = 6}) {
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

/// Search notes
List<Map<String, dynamic>> searchNotesByText(List<dynamic> notes, String query, {int limit = 6}) {
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

/// Suggest linked items (very simple heuristic):
/// - search tasks/notes/events for token overlap with title/description
/// - return up to maxSuggestions items with a confidence score
List<Map<String, dynamic>> suggestLinkedItems({
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

  final taskMatches = searchTasksByText(tasks, query, limit: maxSuggestions);
  final noteMatches = searchNotesByText(notes, query, limit: maxSuggestions);
  final eventMatches = searchEventsByText(events, query, limit: maxSuggestions);

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

List<Map<String, dynamic>> suggestionsToJson(List<Map<String, dynamic>> suggestions) {
  return suggestions.map((s) {
    final out = Map<String, dynamic>.from(s);
    // ensure numeric types are proper
    if (out.containsKey('confidence')) out['confidence'] = (out['confidence'] as num).toDouble();
    return out;
  }).toList();
}

/// Return the first free slot from now until end of day that meets minDuration
TimeSlot? nextFreeSlotToday({required DateTime now, required List<dynamic> events, Duration minDuration = const Duration(minutes: 15)}) {
  final start = now;
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final slots = findFreeSlots(events, start, end, minDuration: minDuration);
  if (slots.isEmpty) return null;
  return slots.first;
}

/// ---------- AppActions class (wrapper) ----------
/// Provides instance methods that the rest of the app expects to call.
/// Read-only helpers delegate to the functions above. Write operations are placeholders
/// that you must implement to integrate with your data layer (providers/notifiers/DB).

class AppActions {
  AppActions();

  // Read-only delegations
  List<TimeSlot> findFreeSlots(List<dynamic> events, DateTime start, DateTime end, {Duration minDuration = const Duration(minutes: 30)}) =>
      findFreeSlots(events, start, end, minDuration: minDuration); // Note: name clash with function — below we disambiguate

  List<Map<String, String>> freeSlotsToJson(List<TimeSlot> slots) => freeSlotsToJson(slots);

  dynamic getClosestEvent(List<dynamic> events, DateTime now, {String? query}) => getClosestEvent(events, now, query: query);

  List<dynamic> eventsInRange(List<dynamic> events, DateTime start, DateTime end) => eventsInRange(events, start, end);

  List<Map<String, dynamic>> searchEventsByText(List<dynamic> events, String query, {int limit = 6}) => searchEventsByText(events, query, limit: limit);

  List<Map<String, dynamic>> searchTasksByText(List<dynamic> tasks, String query, {int limit = 6}) => searchTasksByText(tasks, query, limit: limit);

  List<Map<String, dynamic>> searchNotesByText(List<dynamic> notes, String query, {int limit = 6}) => searchNotesByText(notes, query, limit: limit);

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
      suggestLinkedItems(
        title: title,
        description: description,
        start: start,
        end: end,
        tasks: tasks,
        notes: notes,
        events: events,
        maxSuggestions: maxSuggestions,
      );

  List<Map<String, dynamic>> suggestionsToJson(List<Map<String, dynamic>> suggestions) => suggestionsToJson(suggestions);

  TimeSlot? nextFreeSlotTodayLocal({required DateTime now, required List<dynamic> events, Duration minDuration = const Duration(minutes: 15)}) =>
      nextFreeSlotToday(now: now, events: events, minDuration: minDuration);

  // NOTE: Because top-level function names and method names are the same, if you encounter analysis issues,
  // rename either the top-level functions or the methods here. They intentionally delegate to the functions above.

  // ---------- Placeholder write methods (must implement) ----------
  // These methods should perform actual writes via your providers/notifiers/DB.
  // They currently throw UnimplementedError to force the developer to implement them.

  Future<void> createEventFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    // TODO: Implement: create a new event in your provider/db using the fields from payload.
    // Example steps:
    // 1) validate required fields: title, start or (date+startTime), and end or durationMinutes
    // 2) normalize/parse dates to DateTime
    // 3) construct your Event model and call ref.read(eventsProvider.notifier).add(event)
    //
    // For now:
    throw UnimplementedError('createEventFromPayload not implemented. Implement creation using your events provider or database.');
  }

  Future<void> editEventFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    // TODO: Implement: update an existing event identified by payload["id"] with new fields.
    // Example:
    // final id = payload['id'] as String;
    // final existing = ref.read(eventsProvider).firstWhere((e) => e.id == id);
    // final updated = existing.copyWith(...); await ref.read(eventsProvider.notifier).update(id, updated);
    throw UnimplementedError('editEventFromPayload not implemented. Implement update using your events provider or database.');
  }

  Future<void> deleteEventById(String id, WidgetRef ref) async {
    // TODO: Implement deletion using your events provider/db
    // Example: await ref.read(eventsProvider.notifier).remove(id);
    throw UnimplementedError('deleteEventById not implemented. Implement deletion using your events provider or database.');
  }

  Future<void> createTaskFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    // TODO: Implement task creation
    throw UnimplementedError('createTaskFromPayload not implemented. Implement task creation using your tasks provider or database.');
  }

  Future<void> editTaskFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    // TODO: Implement task editing
    throw UnimplementedError('editTaskFromPayload not implemented. Implement task editing using your tasks provider or database.');
  }

  Future<void> deleteTaskById(String id, WidgetRef ref) async {
    // TODO: Implement task deletion
    throw UnimplementedError('deleteTaskById not implemented. Implement task deletion using your tasks provider or database.');
  }

  Future<void> createNoteFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    // TODO: Implement note creation
    throw UnimplementedError('createNoteFromPayload not implemented. Implement note creation using your notes provider or database.');
  }

  Future<void> editNoteFromPayload(Map<String, dynamic> payload, WidgetRef ref) async {
    // TODO: Implement note editing
    throw UnimplementedError('editNoteFromPayload not implemented. Implement note editing using your notes provider or database.');
  }

  Future<void> deleteNoteById(String id, WidgetRef ref) async {
    // TODO: Implement note deletion
    throw UnimplementedError('deleteNoteById not implemented. Implement note deletion using your notes provider or database.');
  }
}