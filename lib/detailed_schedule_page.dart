import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/schedule_store.dart';
// import '../testData.dart';
import 'models/app_models.dart';
import 'schedule_event_dialog.dart';

class DetailedSchedulePage extends ConsumerStatefulWidget {
  const DetailedSchedulePage({super.key});

  @override
  ConsumerState<DetailedSchedulePage> createState() => _DetailedSchedulePageState();
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

  bool _overlaps(DateTime start, DateTime end, DateTime rangeStart, DateTime rangeEnd) {
    return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
  }

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
          // ignore: deprecated_member_use
          colorValue: const Color(0xFF2A8CFF).value,
        ),
      ),
    );
    if (draft == null) return;

    final ok = await _confirm(
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
            description: draft.description?.trim().isEmpty ?? true ? null : draft.description!.trim(),
            startAt: draft.start,
            endAt: draft.end.isAfter(draft.start)
                ? draft.end
                : draft.start.add(const Duration(minutes: 30)),
            colorValue: draft.colorValue,
            busyStatus: draft.busyStatus ?? BusyStatus.busy,
            createdAt: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: this is the only correct way to get shared schedule state here:
    final all = ref.watch(scheduleProvider);

    final rangeStart = _viewStart(_anchor);
    final rangeEnd = _viewEndExclusive(_anchor);

    final items = all
        .where((e) => _overlaps(e.startAt, e.endAt, rangeStart, rangeEnd))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailed Schedule'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(onPressed: _goToday, child: const Text('Today')),
          IconButton(onPressed: _addEvent, icon: const Icon(Icons.add)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => _shiftAnchor(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Text(
                  _rangeLabel(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(onPressed: () => _shiftAnchor(1), icon: const Icon(Icons.chevron_right)),
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
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                ),
              ),
            )
          else
            for (final e in items) ...[
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirm(
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
                  child: _DetailedCard(
                    title: e.title,
                    meta: '${_hm(e.startAt)}–${_hm(e.endAt)}'
                        '${(e.location ?? '').trim().isEmpty ? '' : ' • ${(e.location ?? '').trim()}'}',
                    colorValue: e.colorValue,
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
  });

  final String title;
  final String meta;
  final int colorValue;

  @override
  Widget build(BuildContext context) {
    final accent = Color(colorValue);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
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
              color: accent.withValues(alpha: 0.9),
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
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}