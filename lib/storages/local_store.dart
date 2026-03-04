import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/app_models.dart';
import '../models/recurrence_models.dart';
import '../providers/settings_provider.dart';
import 'serializers.dart';

class LocalStore {
  static const _box = 'mine_store';

  static const _kTasks = 'tasks';
  static const _kNotes = 'notes';
  static const _kEvents = 'events';

  static const _kRecurringEvents = 'recurring_events';
  static const _kRecurringEventExceptions = 'recurring_event_exceptions';

  static const _kSettings = 'settings';

  static Future<Box> _open() => Hive.openBox(_box);

  // -------------------- TASKS --------------------

  static Future<void> saveTasks(List<Task> tasks) async {
    final b = await _open();
    await b.put(_kTasks, jsonEncode(tasks.map(taskToJson).toList()));
  }

  static Future<List<Task>> loadTasks() async {
    final b = await _open();
    final raw = b.get(_kTasks);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw as String) as List;
    return decoded
        .map((e) => taskFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> clearTasks() async {
    final b = await _open();
    await b.delete(_kTasks);
  }

  // -------------------- NOTES --------------------

  static Future<void> saveNotes(List<Note> notes) async {
    final b = await _open();
    await b.put(_kNotes, jsonEncode(notes.map(noteToJson).toList()));
  }

  static Future<List<Note>> loadNotes() async {
    final b = await _open();
    final raw = b.get(_kNotes);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw as String) as List;
    return decoded
        .map((e) => noteFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> clearNotes() async {
    final b = await _open();
    await b.delete(_kNotes);
  }

  // -------------------- EVENTS --------------------

  static Future<void> saveEvents(List<Event> events) async {
    final b = await _open();
    await b.put(_kEvents, jsonEncode(events.map(eventToJson).toList()));
  }

  static Future<List<Event>> loadEvents() async {
    final b = await _open();
    final raw = b.get(_kEvents);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw as String) as List;
    return decoded
        .map((e) => eventFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> clearEvents() async {
    final b = await _open();
    await b.delete(_kEvents);
  }

  // -------------------- RECURRING TEMPLATES --------------------

  static Future<void> saveRecurringEvents(
    List<RecurringEventTemplate> templates,
  ) async {
    final b = await _open();
    await b.put(
      _kRecurringEvents,
      jsonEncode(templates.map(recurringEventTemplateToJson).toList()),
    );
  }

  static Future<List<RecurringEventTemplate>> loadRecurringEvents() async {
    final b = await _open();
    final raw = b.get(_kRecurringEvents);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw as String) as List;
    return decoded
        .map(
          (e) => recurringEventTemplateFromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  static Future<void> clearRecurringEvents() async {
    final b = await _open();
    await b.delete(_kRecurringEvents);
  }

  // -------------------- RECURRING EXCEPTIONS --------------------

  static Future<void> saveRecurringEventExceptions(
    List<RecurringEventException> exceptions,
  ) async {
    final b = await _open();
    await b.put(
      _kRecurringEventExceptions,
      jsonEncode(exceptions.map(recurringExceptionToJson).toList()),
    );
  }

  static Future<List<RecurringEventException>> loadRecurringEventExceptions() async {
    final b = await _open();
    final raw = b.get(_kRecurringEventExceptions);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw as String) as List;
    return decoded
        .map(
          (e) => recurringExceptionFromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  static Future<void> clearRecurringEventExceptions() async {
    final b = await _open();
    await b.delete(_kRecurringEventExceptions);
  }

  // -------------------- SETTINGS --------------------

  static Future<void> saveSettings(SettingsState settings) async {
    final b = await _open();
    await b.put(_kSettings, jsonEncode(settingsToJson(settings)));
  }

  static Future<SettingsState?> loadSettings() async {
    final b = await _open();
    final raw = b.get(_kSettings);
    if (raw == null) return null;
    return settingsFromJson(
      Map<String, dynamic>.from(jsonDecode(raw as String) as Map),
    );
  }

  static Future<void> clearSettings() async {
    final b = await _open();
    await b.delete(_kSettings);
  }

  // -------------------- CLEAR ALL (APP DATA) --------------------

  /// Clears all app data stored in Hive for this app.
  ///
  /// If you want to keep settings, remove `_kSettings` from the deletes.
  static Future<void> clearAll() async {
    final b = await _open();
    await Future.wait([
      b.delete(_kTasks),
      b.delete(_kNotes),
      b.delete(_kEvents),
      b.delete(_kRecurringEvents),
      b.delete(_kRecurringEventExceptions),
      b.delete(_kSettings),
    ]);
  }
}