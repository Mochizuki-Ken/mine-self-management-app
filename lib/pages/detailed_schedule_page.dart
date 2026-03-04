import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/events_provider.dart';
import '../models/app_models.dart';
import '../models/recurrence_models.dart';
import '../pages/long_term_task_page.dart';
import '../pages/note_edit_page.dart';
import '../pages/task_detail_page.dart';
import '../providers/notes_provider.dart';
import '../providers/recurring_event_exceptions_provider.dart';
import '../providers/recurring_events_provider.dart';
import '../providers/tasks_provider.dart';
import '../services/link_sync_service.dart';
import '../tools/recurrence_expand.dart';
import '../widgets/recurring_event_edit_dialog.dart';
import '../widgets/schedule_event_dialog.dart';

class DetailedSchedulePage extends ConsumerStatefulWidget {
  const DetailedSchedulePage({super.key});

  @override
  ConsumerState<DetailedSchedulePage> createState() =>
      _DetailedSchedulePageState();
}

enum ScheduleView { day, week, month, year }

class _DetailedSchedulePageState extends ConsumerState<DetailedSchedulePage> {
  ScheduleView _view = ScheduleView.day;
  DateTime _anchor = DateTime.now();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    final date = _dateOnly(d);
    final delta = date.weekday - DateTime.monday;
    return date.subtract(Duration(days: delta));
  }

  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _startOfYear(DateTime d) => DateTime(d.year, 1, 1);

  DateTime _viewStart(DateTime anchor) {
    switch (_view) {
      case ScheduleView.day:
        return _dateOnly(anchor);
      case ScheduleView.week:
        return _startOfWeek(anchor);
      case ScheduleView.month:
        return _startOfMonth(anchor);
      case ScheduleView.year:
        return _startOfYear(anchor);
    }
  }

  DateTime _viewEndExclusive(DateTime anchor) {
    final start = _viewStart(anchor);
    switch (_view) {
      case ScheduleView.day:
        return start.add(const Duration(days: 1));
      case ScheduleView.week:
        return start.add(const Duration(days: 7));
      case ScheduleView.month:
        return DateTime(start.year, start.month + 1, 1);
      case ScheduleView.year:
        return DateTime(start.year + 1, 1, 1);
    }
  }

  bool _overlaps(
    DateTime start,
    DateTime end,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) =>
      start.isBefore(rangeEnd) && end.isAfter(rangeStart);

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  String _rangeLabel() {
    final start = _viewStart(_anchor);
    final end = _viewEndExclusive(_anchor).subtract(const Duration(days: 1));
    switch (_view) {
      case ScheduleView.day:
        return '${start.year}-${_two(start.month)}-${_two(start.day)}';
      case ScheduleView.week:
        return '${start.year}-${_two(start.month)}-${_two(start.day)}'
            ' ~ ${end.year}-${_two(end.month)}-${_two(end.day)}';
      case ScheduleView.month:
        return '${start.year}-${_two(start.month)}';
      case ScheduleView.year:
        return '${start.year}';
    }
  }

  void _goToday() => setState(() => _anchor = DateTime.now());

  void _shiftAnchor(int delta) {
    setState(() {
      switch (_view) {
        case ScheduleView.day:
          _anchor = _anchor.add(Duration(days: delta));
          break;
        case ScheduleView.week:
          _anchor = _anchor.add(Duration(days: 7 * delta));
          break;
        case ScheduleView.month:
          _anchor = DateTime(_anchor.year, _anchor.month + delta, _anchor.day);
          break;
        case ScheduleView.year:
          _anchor = DateTime(_anchor.year + delta, _anchor.month, _anchor.day);
          break;
      }
    });
  }

  Future<bool> _confirm({
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

  // Parse instance id: "recur:<templateId>:<dateIso>"
  String? _templateIdFromInstanceId(String id) {
    if (!id.startsWith('recur:')) return null;
    final parts = id.split(':');
    if (parts.length < 3) return null;
    return parts[1];
  }

  DateTime? _dateFromInstanceId(String id) {
    if (!id.startsWith('recur:')) return null;
    final parts = id.split(':');
    if (parts.length < 3) return null;
    try {
      return _dateOnly(DateTime.parse(parts.sublist(2).join(':')));
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNote(String noteId) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteEditPage(noteId: noteId)),
    );
  }

  Future<void> _openTask(String taskId) async {
    final tasks = ref.read(tasksProvider);
    Task? task;
    for (final t in tasks) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }
    if (task == null) return;

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => task!.scale == TaskScale.long
            ? LongTermTaskPage(taskId: taskId)
            : TaskDetailPage(taskId: taskId),
      ),
    );
  }

  Future<void> _showLinksAndNavigate(Event e) async {
    final tasks = ref.read(tasksProvider);
    final notes = ref.read(notesProvider);

    final linkedTasks =
        tasks.where((t) => e.linkedTaskIds.contains(t.id)).toList();
    final linkedNotes =
        notes.where((n) => e.linkedNoteIds.contains(n.id)).toList();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final sheetH = MediaQuery.of(context).size.height * 0.75;
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
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
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
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
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
                              title: Text(
                                t.title.trim().isEmpty ? '(No title)' : t.title,
                              ),
                              subtitle:
                                  Text('${t.scale.name} • ${t.status.name}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                Navigator.pop(context);
                                await _openTask(t.id);
                              },
                            ),
                        const SizedBox(height: 14),
                        Text(
                          'Notes (${linkedNotes.length})',
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
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
                              leading:
                                  const Icon(Icons.sticky_note_2_outlined),
                              title: Text(
                                n.title.trim().isEmpty ? '(No title)' : n.title,
                              ),
                              subtitle: Text(
                                n.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                Navigator.pop(context);
                                await _openNote(n.id);
                              },
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

  // ---------- One-off event ----------
  Future<void> _addEvent() async {
    final start = _viewStart(_anchor);

    final draft = await showDialog<ScheduleEventDraft>(
      context: context,
      builder: (_) => ScheduleEventDialog(
        dialogTitle: 'Add event',
        initial: ScheduleEventDraft(
          title: '',
          location: '',
          start: start.add(const Duration(hours: 9)),
          end: start.add(const Duration(hours: 10)),
          colorValue: const Color(0xFF2A8CFF).value,
          linkedTaskIds: const [],
          linkedNoteIds: const [],
        ),
      ),
    );
    if (draft == null) return;

    final ok = await _confirm(
      title: 'Add event?',
      message:
          'Add "${draft.title.trim().isEmpty ? '(No title)' : draft.title.trim()}"?',
      confirmText: 'Add',
    );
    if (!ok) return;

    final now = DateTime.now();

    final created = Event(
      id: now.microsecondsSinceEpoch.toString(),
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
      createdAt: now,
      updatedAt: now,
    );

    ref.read(eventsProvider.notifier).add(created);
    ref.read(linkSyncServiceProvider).syncFromEvent(created);
  }

  Future<void> _editOneOff(Event e) async {
    final draft = await showDialog<ScheduleEventDraft>(
      context: context,
      builder: (_) => ScheduleEventDialog(
        dialogTitle: 'Edit event',
        initial: ScheduleEventDialog.fromEvent(e),
      ),
    );
    if (draft == null) return;

    final ok = await _confirm(
      title: 'Save changes?',
      message: 'Update "${e.title}"?',
      confirmText: 'Save',
    );
    if (!ok) return;

    final now = DateTime.now();

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
      updatedAt: now,
    );

    ref.read(eventsProvider.notifier).update(e.id, updated);
    ref.read(linkSyncServiceProvider).syncFromEvent(updated);
  }

  // ---------- Recurring template ----------
  Future<void> _addRecurringEvent() async {
    final draft = await showDialog<RecurringEventDraft>(
      context: context,
      builder: (_) => RecurringEventEditDialog(
        dialogTitle: 'Add recurring event',
        initialStartsOn: _viewStart(_anchor),
      ),
    );
    if (draft == null) return;

    final ok = await _confirm(
      title: 'Add recurring event?',
      message: 'Add "${draft.title}"?',
      confirmText: 'Add',
    );
    if (!ok) return;

    final now = DateTime.now();
    ref.read(recurringEventsProvider.notifier).add(
          RecurringEventTemplate(
            id: now.microsecondsSinceEpoch.toString(),
            title: draft.title,
            startMinuteOfDay: draft.startMinuteOfDay,
            endMinuteOfDay: draft.endMinuteOfDay,
            rule: draft.rule,
            startsOn: draft.startsOn,
            endsOn: draft.endsOn,
            colorValue: draft.colorValue,
            busyStatus: draft.busyStatus,
            location: draft.location,
            description: draft.description,
            linkedTaskIds: draft.linkedTaskIds ?? const [],
            linkedNoteIds: draft.linkedNoteIds ?? const [],
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> _editRecurringSeries(RecurringEventTemplate t) async {
    TimeOfDay toTime(int minuteOfDay) =>
        TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60);

    final draft = await showDialog<RecurringEventDraft>(
      context: context,
      builder: (_) => RecurringEventEditDialog(
        dialogTitle: 'Edit recurring event',
        initialTitle: t.title,
        initialLocation: t.location ?? '',
        initialDescription: t.description ?? '',
        initialStart: toTime(t.startMinuteOfDay),
        initialEnd: toTime(t.endMinuteOfDay),
        initialRepeatType: t.rule.type,
        initialSelectedWeekdays:
            t.rule.type == RecurrenceType.weekly ? t.rule.weekdays : null,
        initialStartsOn: t.startsOn,
        initialEndsOn: t.endsOn,
        initialColorValue: t.colorValue,
        initialBusyStatus: t.busyStatus,
        initialLinkedTaskIds: t.linkedTaskIds,
        initialLinkedNoteIds: t.linkedNoteIds,
      ),
    );
    if (draft == null) return;

    final ok = await _confirm(
      title: 'Save changes?',
      message: 'Update "${t.title}"?',
      confirmText: 'Save',
    );
    if (!ok) return;

    ref.read(recurringEventsProvider.notifier).update(
          t.copyWith(
            title: draft.title,
            location: draft.location,
            description: draft.description,
            startMinuteOfDay: draft.startMinuteOfDay,
            endMinuteOfDay: draft.endMinuteOfDay,
            colorValue: draft.colorValue,
            busyStatus: draft.busyStatus,
            rule: draft.rule,
            startsOn: draft.startsOn,
            endsOn: draft.endsOn,
            linkedTaskIds: draft.linkedTaskIds ?? const [],
            linkedNoteIds: draft.linkedNoteIds ?? const [],
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> _editRecurringOccurrence({
    required RecurringEventTemplate template,
    required DateTime occurrenceDay,
  }) async {
    TimeOfDay toTime(int minuteOfDay) =>
        TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60);

    final draft = await showDialog<RecurringEventDraft>(
      context: context,
      builder: (_) => RecurringEventEditDialog(
        dialogTitle: 'Edit this event',
        initialTitle: template.title,
        initialLocation: template.location ?? '',
        initialDescription: template.description ?? '',
        initialStart: toTime(template.startMinuteOfDay),
        initialEnd: toTime(template.endMinuteOfDay),
        initialRepeatType: template.rule.type,
        initialSelectedWeekdays: template.rule.type == RecurrenceType.weekly
            ? template.rule.weekdays
            : null,
        initialStartsOn: occurrenceDay,
        initialEndsOn: occurrenceDay,
        initialColorValue: template.colorValue,
        initialBusyStatus: template.busyStatus,
        initialLinkedTaskIds: template.linkedTaskIds,
        initialLinkedNoteIds: template.linkedNoteIds,
      ),
    );
    if (draft == null) return;

    final ok = await _confirm(
      title: 'Save changes?',
      message: 'Update only ${occurrenceDay.toIso8601String().split("T").first}?',
      confirmText: 'Save',
    );
    if (!ok) return;

    ref.read(recurringEventExceptionsProvider.notifier).upsertOverride(
          templateId: template.id,
          day: occurrenceDay,
          title: draft.title,
          location: draft.location,
          description: draft.description,
          startMinuteOfDay: draft.startMinuteOfDay,
          endMinuteOfDay: draft.endMinuteOfDay,
          colorValue: draft.colorValue,
          busyStatus: draft.busyStatus,
        );
  }

  Future<void> _deleteRecurringOccurrence({
    required RecurringEventTemplate template,
    required DateTime occurrenceDay,
  }) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event_busy),
                title: const Text('This event'),
                subtitle: const Text('Delete only this date'),
                onTap: () => Navigator.pop(context, 'this'),
              ),
              ListTile(
                leading: const Icon(Icons.event_repeat),
                title: const Text('This and following'),
                subtitle: const Text('Delete this date and all future events'),
                onTap: () => Navigator.pop(context, 'following'),
              ),

              // NEW: delete entire series
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Entire series (delete)'),
                subtitle: const Text('Delete the whole recurring series'),
                onTap: () => Navigator.pop(context, 'series_delete'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'this') {
      final ok = await _confirm(
        title: 'Delete this event?',
        message:
            'Delete only ${occurrenceDay.toIso8601String().split("T").first} for "${template.title}"?',
        confirmText: 'Delete',
        destructive: true,
      );
      if (!ok) return;

      // persisted by provider
      ref.read(recurringEventExceptionsProvider.notifier).addSkip(
            templateId: template.id,
            day: occurrenceDay,
          );
      return;
    }

    if (choice == 'following') {
      final ok = await _confirm(
        title: 'Delete this and following?',
        message:
            'Delete ${occurrenceDay.toIso8601String().split("T").first} and all future events for "${template.title}"?',
        confirmText: 'Delete',
        destructive: true,
      );
      if (!ok) return;

      // persisted by provider
      ref.read(recurringEventsProvider.notifier).endSeriesFromDate(
            templateId: template.id,
            fromDate: occurrenceDay,
          );
      return;
    }

    if (choice == 'series_delete') {
      final ok = await _confirm(
        title: 'Delete entire series?',
        message: 'Delete the entire series "${template.title}"?',
        confirmText: 'Delete series',
        destructive: true,
      );
      if (!ok) return;

      // IMPORTANT: delete template + exceptions, both persisted to Hive.
      await ref.read(recurringEventsProvider.notifier).remove(template.id);
      await ref
          .read(recurringEventExceptionsProvider.notifier)
          .removeForTemplate(template.id);
    }
  }

  Future<void> _handleTap(Event e, List<RecurringEventTemplate> templates) async {
    if (!e.id.startsWith('recur:')) {
      await _editOneOff(e);
      return;
    }

    final tid = _templateIdFromInstanceId(e.id);
    final day = _dateFromInstanceId(e.id);
    if (tid == null || day == null) return;

    RecurringEventTemplate? template;
    try {
      template = templates.firstWhere((x) => x.id == tid);
    } catch (_) {
      template = null;
    }
    if (template == null) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('This event'),
                subtitle:
                    const Text('Change time/color/details only on this date'),
                onTap: () => Navigator.pop(context, 'this'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar),
                title: const Text('Entire series'),
                subtitle:
                    const Text('Change repeating rule/time/color for all occurrences'),
                onTap: () => Navigator.pop(context, 'series'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'this') {
      await _editRecurringOccurrence(template: template, occurrenceDay: day);
    } else if (choice == 'series') {
      await _editRecurringSeries(template);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oneOff = ref.watch(eventsProvider);
    final templates = ref.watch(recurringEventsProvider);
    final exceptions = ref.watch(recurringEventExceptionsProvider);

    final rangeStart = _viewStart(_anchor);
    final rangeEnd = _viewEndExclusive(_anchor);

    final oneOffInRange = oneOff
        .where((e) => _overlaps(e.startAt, e.endAt, rangeStart, rangeEnd))
        .toList();

    final expandedRecurringInstances = <Event>[];
    final dayCount = rangeEnd.difference(rangeStart).inDays;
    for (var i = 0; i < dayCount; i++) {
      final day = rangeStart.add(Duration(days: i));
      expandedRecurringInstances.addAll(
        eventsForDay(
          day: day,
          oneOffEvents: const [], // Option A (avoid duplicates)
          templates: templates,
          exceptions: exceptions,
          recurring: const [],
        ),
      );
    }

    final items = [...oneOffInRange, ...expandedRecurringInstances]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailed Schedule'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(onPressed: _goToday, child: const Text('Today')),
          PopupMenuButton<String>(
            tooltip: 'Add',
            onSelected: (v) {
              if (v == 'event') _addEvent();
              if (v == 'recurring') _addRecurringEvent();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'event', child: Text('Add one-off event')),
              PopupMenuItem(value: 'recurring', child: Text('Add recurring event')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.add),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftAnchor(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _rangeLabel(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => _shiftAnchor(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<ScheduleView>(
            segments: const [
              ButtonSegment(value: ScheduleView.day, label: Text('Day')),
              ButtonSegment(value: ScheduleView.week, label: Text('Week')),
              ButtonSegment(value: ScheduleView.month, label: Text('Month')),
              ButtonSegment(value: ScheduleView.year, label: Text('Year')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  'No events in this range',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.55),
                      ),
                ),
              ),
            )
          else
            for (final e in items) ...[
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  if (e.id.startsWith('recur:')) return true;
                  return _confirm(
                    title: 'Delete event?',
                    message: 'Delete "${e.title}"?',
                    confirmText: 'Delete',
                    destructive: true,
                  );
                },
                onDismissed: (_) async {
                  if (!e.id.startsWith('recur:')) {
                    ref.read(eventsProvider.notifier).remove(e.id);
                    return;
                  }

                  final tid = _templateIdFromInstanceId(e.id);
                  final day = _dateFromInstanceId(e.id);
                  if (tid == null || day == null) return;

                  RecurringEventTemplate? template;
                  try {
                    template = templates.firstWhere((x) => x.id == tid);
                  } catch (_) {
                    template = null;
                  }
                  if (template == null) return;

                  await _deleteRecurringOccurrence(
                    template: template,
                    occurrenceDay: day,
                  );
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete, color: Colors.redAccent),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _handleTap(e, templates),
                  child: _DetailedCard(
                    title: e.id.startsWith('recur:') ? '${e.title} (Repeat)' : e.title,
                    meta: '${_hm(e.startAt)}–${_hm(e.endAt)}'
                        '${(e.location ?? '').trim().isEmpty ? '' : ' • ${(e.location ?? '').trim()}'}',
                    colorValue: e.colorValue,
                    hasLinks:
                        e.linkedTaskIds.isNotEmpty || e.linkedNoteIds.isNotEmpty,
                    onTapLinks: () => _showLinksAndNavigate(e),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _DetailedCard extends StatelessWidget {
  const _DetailedCard({
    required this.title,
    required this.meta,
    required this.colorValue,
    required this.hasLinks,
    required this.onTapLinks,
  });

  final String title;
  final String meta;
  final int colorValue;
  final bool hasLinks;
  final VoidCallback onTapLinks;

  @override
  Widget build(BuildContext context) {
    final accent = Color(colorValue);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.65),
                      ),
                ),
              ],
            ),
          ),
          if (hasLinks)
            IconButton(
              tooltip: 'Linked items',
              onPressed: onTapLinks,
              icon: const Icon(Icons.link),
            ),
        ],
      ),
    );
  }
}