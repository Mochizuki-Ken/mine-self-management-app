import 'dart:convert';
import 'package:hive/hive.dart';

import '../models/app_models.dart';
import '../providers/settings_provider.dart';
import 'serializers.dart';

class LocalStore {
  static const _box = 'mine_store';

  static const _kTasks = 'tasks';
  static const _kNotes = 'notes';
  static const _kEvents = 'events';
  static const _kSchedule = 'schedule';
  static const _kSettings = 'settings';

  static Future<Box> _open() => Hive.openBox(_box);

  static Future<void> saveTasks(List<Task> tasks) async {
    final b = await _open();
    await b.put(_kTasks, jsonEncode(tasks.map(taskToJson).toList()));
  }

  static Future<List<Task>> loadTasks() async {
    final b = await _open();
    final raw = b.get(_kTasks);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw as String) as List;
    return decoded.map((e) => taskFromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static Future<void> saveNotes(List<Note> notes) async {
    final b = await _open();
    await b.put(_kNotes, jsonEncode(notes.map(noteToJson).toList()));
  }

  static Future<List<Note>> loadNotes() async {
    final b = await _open();
    final raw = b.get(_kNotes);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw as String) as List;
    return decoded.map((e) => noteFromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static Future<void> saveEvents(List<Event> events) async {
    final b = await _open();
    await b.put(_kEvents, jsonEncode(events.map(eventToJson).toList()));
  }

  static Future<List<Event>> loadEvents() async {
    final b = await _open();
    final raw = b.get(_kEvents);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw as String) as List;
    return decoded.map((e) => eventFromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  // Schedule (separate from eventsProvider)
  static Future<void> saveScheduleEvents(List<Event> events) async {
    final b = await _open();
    await b.put(_kSchedule, jsonEncode(events.map(eventToJson).toList()));
  }

  static Future<List<Event>> loadScheduleEvents() async {
    final b = await _open();
    final raw = b.get(_kSchedule);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw as String) as List;
    return decoded.map((e) => eventFromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

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
}