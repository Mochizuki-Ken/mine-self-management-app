import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mine/providers/recurring_event_exceptions_provider.dart';

import '../models/recurrence_models.dart';
import '../storages/local_store.dart';

final recurringEventsProvider =
    StateNotifierProvider<RecurringEventsNotifier, List<RecurringEventTemplate>>(
  (ref) => RecurringEventsNotifier(ref),
);

class RecurringEventsNotifier extends StateNotifier<List<RecurringEventTemplate>> {
  RecurringEventsNotifier(this._ref) : super(const []) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    state = await LocalStore.loadRecurringEvents();
  }

  Future<void> _persist() => LocalStore.saveRecurringEvents(state);

  Future<void> add(RecurringEventTemplate t) async {
    state = [...state, t];
    await _persist();
  }

  Future<void> update(RecurringEventTemplate t) async {
    state = [for (final x in state) if (x.id == t.id) t else x];
    await _persist();
  }

  /// Deletes the series AND its exceptions from storage.
  Future<void> remove(String id) async {
    state = [for (final x in state) if (x.id != id) x];
    await _persist();

    // Also delete exceptions belonging to this template.
    // Requires recurring_event_exceptions_provider.dart to have removeForTemplate()
    await _ref.read(recurringEventExceptionsProvider.notifier).removeForTemplate(id);
  }

  Future<void> clearAll() async {
    state = const [];
    await _persist();
  }

  Future<void> endSeriesFromDate({
    required String templateId,
    required DateTime fromDate,
  }) async {
    final endOn = DateTime(fromDate.year, fromDate.month, fromDate.day)
        .subtract(const Duration(days: 1));

    state = [
      for (final t in state)
        if (t.id == templateId) t.copyWith(endsOn: endOn, updatedAt: DateTime.now()) else t
    ];
    await _persist();
  }
}