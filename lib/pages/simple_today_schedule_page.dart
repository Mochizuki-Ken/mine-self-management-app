import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/schedule_store.dart';
// import '../testData.dart';
import '../models/app_models.dart';
import '../schedule_event_dialog.dart';

class SimpleTodaySchedulePage extends ConsumerWidget {
  const SimpleTodaySchedulePage({super.key});

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _overlaps(DateTime start, DateTime end, DateTime rangeStart, DateTime rangeEnd) {
    return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: Colors.redAccent) : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(scheduleProvider);

    final todayStart = _dateOnly(DateTime.now());
    final todayEnd = todayStart.add(const Duration(days: 1));

    final items = all
        .where((e) => _overlaps(e.startAt, e.endAt, todayStart, todayEnd))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Today Schedule'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: () async {
              final now = DateTime.now();
              final draft = await showDialog<ScheduleEventDraft>(
                context: context,
                builder: (_) => ScheduleEventDialog(
                  dialogTitle: 'Add event',
                  initial: ScheduleEventDraft(
                    title: '',
                    location: '',
                    start: DateTime(now.year, now.month, now.day, 9, 0),
                    end: DateTime(now.year, now.month, now.day, 9, 30),
                    colorValue: const Color(0xFF2A8CFF).value,
                  ),
                ),
              );
              if (draft == null) return;

              final ok = await _confirm(
                context,
                title: 'Add event?',
                message: 'Add "${draft.title.trim().isEmpty ? '(No title)' : draft.title.trim()}"?',
                confirmText: 'Add',
              );
              if (!ok) return;

              ref.read(scheduleProvider.notifier).add(
                    Event(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: draft.title.trim().isEmpty ? '(No title)' : draft.title.trim(),
                      location: draft.location.trim(),
                      description: draft.description?.trim().isEmpty ?? true
                          ? null
                          : draft.description!.trim(),
                      startAt: draft.start,
                      endAt: draft.end.isAfter(draft.start)
                          ? draft.end
                          : draft.start.add(const Duration(minutes: 30)),
                      colorValue: draft.colorValue,
                      busyStatus: draft.busyStatus ?? BusyStatus.busy,
                      createdAt: DateTime.now(),
                    ),
                  );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = items[i];
          final c = Color(e.colorValue);

          return Dismissible(
            key: ValueKey(e.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirm(
              context,
              title: 'Delete event?',
              message: 'Delete "${e.title}"?',
              confirmText: 'Delete',
              destructive: true,
            ),
            onDismissed: (_) => ref.read(scheduleProvider.notifier).remove(e.id),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.delete, color: Colors.redAccent),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final draft = await showDialog<ScheduleEventDraft>(
                  context: context,
                  builder: (_) => ScheduleEventDialog(
                    dialogTitle: 'Edit event',
                    initial: ScheduleEventDialog.fromEvent(e),
                  ),
                );
                if (draft == null) return;

                final ok = await _confirm(
                  context,
                  title: 'Save changes?',
                  message: 'Update "${e.title}"?',
                  confirmText: 'Save',
                );
                if (!ok) return;

                ref.read(scheduleProvider.notifier).update(
                      e.id,
                      e.copyWith(
                        title: draft.title.trim().isEmpty ? '(No title)' : draft.title.trim(),
                        location: draft.location.trim(),
                        description: draft.description?.trim().isEmpty ?? true
                            ? null
                            : draft.description!.trim(),
                        startAt: draft.start,
                        endAt: draft.end.isAfter(draft.start)
                            ? draft.end
                            : draft.start.add(const Duration(minutes: 30)),
                        colorValue: draft.colorValue,
                        busyStatus: draft.busyStatus ?? e.busyStatus,
                        updatedAt: DateTime.now(),
                      ),
                    );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_hm(e.startAt)}–${_hm(e.endAt)}'
                            '${(e.location ?? '').trim().isEmpty ? '' : ' • ${(e.location ?? '').trim()}'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.35)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}