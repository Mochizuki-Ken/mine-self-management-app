import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mine/models/app_models.dart';

import '../models/recurrence_models.dart';
import '../storages/local_store.dart';

final recurringEventExceptionsProvider = StateNotifierProvider<
    RecurringEventExceptionsNotifier, List<RecurringEventException>>(
  (ref) => RecurringEventExceptionsNotifier(),
);

class RecurringEventExceptionsNotifier
    extends StateNotifier<List<RecurringEventException>> {
  RecurringEventExceptionsNotifier() : super(const []) {
    _init();
  }

  Future<void> _init() async {
    state = await LocalStore.loadRecurringEventExceptions();
  }

  Future<void> _persist() => LocalStore.saveRecurringEventExceptions(state);

  Future<void> addSkip({
    required String templateId,
    required DateTime day,
  }) async {
    final id = 'skip:$templateId:${DateTime(day.year, day.month, day.day).toIso8601String()}';
    state = [
      ...state.where((e) => e.id != id),
      RecurringEventException(
        id: id,
        templateId: templateId,
        date: DateTime(day.year, day.month, day.day),
        type: RecurringExceptionType.skip,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
    await _persist();
  }

  Future<void> upsertOverride({
    required String templateId,
    required DateTime day,
    String? title,
    int? startMinuteOfDay,
    int? endMinuteOfDay,
    String? location,
    String? description,
    int? colorValue,
    BusyStatus? busyStatus,
  }) async {
    final dateOnly = DateTime(day.year, day.month, day.day);
    final id = 'override:$templateId:${dateOnly.toIso8601String()}';

    final now = DateTime.now();
    state = [
      for (final e in state)
        if (e.id == id)
          e.copyWith(
            type: RecurringExceptionType.override,
            title: title,
            startMinuteOfDay: startMinuteOfDay,
            endMinuteOfDay: endMinuteOfDay,
            location: location,
            description: description,
            colorValue: colorValue,
            busyStatus: busyStatus,
            updatedAt: now,
          )
        else
          e,
      if (state.every((e) => e.id != id))
        RecurringEventException(
          id: id,
          templateId: templateId,
          date: dateOnly,
          type: RecurringExceptionType.override,
          title: title,
          startMinuteOfDay: startMinuteOfDay,
          endMinuteOfDay: endMinuteOfDay,
          location: location,
          description: description,
          colorValue: colorValue,
          busyStatus: busyStatus,
          createdAt: now,
          updatedAt: now,
        ),
    ];

    await _persist();
  }

  /// NEW: delete all exceptions for a series (used when deleting template)
  Future<void> removeForTemplate(String templateId) async {
    state = [for (final e in state) if (e.templateId != templateId) e];
    await _persist();
  }

  Future<void> clearAll() async {
    state = const [];
    await _persist();
  }
}