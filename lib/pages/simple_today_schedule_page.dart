import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/events_provider.dart';
import '../models/app_models.dart';
import '../providers/notes_provider.dart';
import '../providers/tasks_provider.dart';
import '../services/link_sync_service.dart';
import '../widgets/schedule_event_dialog.dart';

class SimpleTodaySchedulePage extends ConsumerWidget {
  const SimpleTodaySchedulePage({super.key});

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _overlaps(DateTime start, DateTime end, DateTime rangeStart, DateTime rangeEnd) {
    return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  // Returns minutes until start (>0), minutes until end if ongoing (<=0 start & >0 end),
  // or minutes since end if finished.
  int _minutesToBoundary(Event e, DateTime now) {
    if (now.isBefore(e.startAt)) {
      return e.startAt.difference(now).inMinutes;
    }
    if (now.isBefore(e.endAt)) {
      return e.endAt.difference(now).inMinutes;
    }
    return -now.difference(e.endAt).inMinutes; // negative => already ended
  }

  bool _isOngoing(Event e, DateTime now) =>
      !now.isBefore(e.startAt) && now.isBefore(e.endAt);

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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.redAccent)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _showLinksSheet(BuildContext context, WidgetRef ref, Event e) async {
    final tasks = ref.read(tasksProvider);
    final notes = ref.read(notesProvider);

    final linkedTasks = tasks.where((t) => e.linkedTaskIds.contains(t.id)).toList();
    final linkedNotes = notes.where((n) => e.linkedNoteIds.contains(n.id)).toList();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final sheetH = MediaQuery.of(context).size.height * 0.70;
        final tt = Theme.of(context).textTheme;

        return SafeArea(
          child: SizedBox(
            height: sheetH,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Linked items',
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        Text(
                          'Tasks (${linkedTasks.length})',
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        if (linkedTasks.isEmpty)
                          Text(
                            'No linked tasks',
                            style: tt.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.60),
                            ),
                          )
                        else
                          for (final t in linkedTasks)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                t.scale == TaskScale.long
                                    ? Icons.folder_open
                                    : Icons.check_circle_outline,
                              ),
                              title: Text(t.title.trim().isEmpty ? '(No title)' : t.title),
                              subtitle: Text('${t.scale.name} • ${t.status.name}'),
                            ),
                        const SizedBox(height: 14),
                        Text(
                          'Notes (${linkedNotes.length})',
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        if (linkedNotes.isEmpty)
                          Text(
                            'No linked notes',
                            style: tt.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.60),
                            ),
                          )
                        else
                          for (final n in linkedNotes)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.sticky_note_2_outlined),
                              title: Text(n.title.trim().isEmpty ? '(No title)' : n.title),
                              subtitle: Text(
                                n.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// "Closest" event = first ongoing, otherwise next upcoming.
  /// Returns event id (or null if none).
  String? _closestEventId(List<Event> items, DateTime now) {
    // Ongoing events: pick the one ending soonest.
    final ongoing = items.where((e) => _isOngoing(e, now)).toList()
      ..sort((a, b) => a.endAt.compareTo(b.endAt));
    if (ongoing.isNotEmpty) return ongoing.first.id;

    // Upcoming: pick the one starting soonest.
    final upcoming = items.where((e) => now.isBefore(e.startAt)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (upcoming.isNotEmpty) return upcoming.first.id;

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(eventsProvider);

    final todayStart = _dateOnly(DateTime.now());
    final todayEnd = todayStart.add(const Duration(days: 1));

    final items = all
        .where((e) => _overlaps(e.startAt, e.endAt, todayStart, todayEnd))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final now = DateTime.now();
    final closestId = _closestEventId(items, now);

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
                    linkedTaskIds: const [],
                    linkedNoteIds: const [],
                  ),
                ),
              );
              if (draft == null) return;

              final ok = await _confirm(
                context,
                title: 'Add event?',
                message:
                    'Add "${draft.title.trim().isEmpty ? '(No title)' : draft.title.trim()}"?',
                confirmText: 'Add',
              );
              if (!ok) return;

              final createdAt = DateTime.now();

              final created = Event(
                id: createdAt.microsecondsSinceEpoch.toString(),
                title: draft.title.trim().isEmpty ? '(No title)' : draft.title.trim(),
                location: draft.location.trim().isEmpty ? null : draft.location.trim(),
                description: draft.description?.trim().isEmpty ?? true
                    ? null
                    : draft.description!.trim(),
                startAt: draft.start,
                endAt: draft.end.isAfter(draft.start)
                    ? draft.end
                    : draft.start.add(const Duration(minutes: 30)),
                colorValue: draft.colorValue,
                busyStatus: draft.busyStatus ?? BusyStatus.busy,
                linkedTaskIds: draft.linkedTaskIds ?? const [],
                linkedNoteIds: draft.linkedNoteIds ?? const [],
                createdAt: createdAt,
                updatedAt: createdAt,
              );

              ref.read(eventsProvider.notifier).add(created);
              ref.read(linkSyncServiceProvider).syncFromEvent(created);
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
          final baseAccent = Color(e.colorValue);
          final hasLinks = e.linkedTaskIds.isNotEmpty || e.linkedNoteIds.isNotEmpty;

          final isClosest = closestId != null && e.id == closestId;
          final isOngoing = _isOngoing(e, now);
          final minutes = _minutesToBoundary(e, now);

          // Color logic for countdown:
          // - upcoming: cyan-ish
          // - ongoing: orange
          // - ended: grey
          final Color counterColor;
          final String counterText;
          if (now.isBefore(e.startAt)) {
            counterColor = const Color(0xFF4DD0E1); // light cyan
            counterText = 'Starts in ${minutes}m';
          } else if (now.isBefore(e.endAt)) {
            counterColor = const Color(0xFFFFB74D); // light orange
            counterText = 'Ends in ${minutes}m';
          } else {
            counterColor = Colors.white.withValues(alpha: 0.45);
            counterText = '${minutes.abs()}m ago';
          }

          // Closest highlight: light green
          final highlightBorder = isClosest
              ? const Color(0xFF69F0AE) // light green
              : Colors.white.withValues(alpha: 0.08);

          final highlightBg = isClosest
              ? const Color(0xFF69F0AE).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06);

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
            onDismissed: (_) => ref.read(eventsProvider.notifier).remove(e.id),
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

                final updated = e.copyWith(
                  title: draft.title.trim().isEmpty ? '(No title)' : draft.title.trim(),
                  location: draft.location.trim().isEmpty ? null : draft.location.trim(),
                  description: draft.description?.trim().isEmpty ?? true
                      ? null
                      : draft.description!.trim(),
                  startAt: draft.start,
                  endAt: draft.end.isAfter(draft.start)
                      ? draft.end
                      : draft.start.add(const Duration(minutes: 30)),
                  colorValue: draft.colorValue,
                  busyStatus: draft.busyStatus ?? e.busyStatus,
                  linkedTaskIds: draft.linkedTaskIds ?? const [],
                  linkedNoteIds: draft.linkedNoteIds ?? const [],
                  updatedAt: DateTime.now(),
                );

                ref.read(eventsProvider.notifier).update(e.id, updated);
                ref.read(linkSyncServiceProvider).syncFromEvent(updated);
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: highlightBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: highlightBorder, width: isClosest ? 1.8 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isClosest ? const Color(0xFF69F0AE) : baseAccent)
                            .withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: counterColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: counterColor.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Text(
                                  counterText,
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: counterColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_hm(e.startAt)}–${_hm(e.endAt)}'
                            '${(e.location ?? '').trim().isEmpty ? '' : ' • ${(e.location ?? '').trim()}'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                          ),
                          if (isOngoing)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Ongoing',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFFFFB74D),
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasLinks)
                      IconButton(
                        tooltip: 'Linked items',
                        onPressed: () => _showLinksSheet(context, ref, e),
                        icon: const Icon(Icons.link),
                      ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
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