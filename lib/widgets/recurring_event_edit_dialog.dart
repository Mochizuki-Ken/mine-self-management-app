import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../models/recurrence_models.dart';
import '../providers/notes_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/link_picker_sheet.dart';

class RecurringEventDraft {
  const RecurringEventDraft({
    required this.title,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    required this.rule,
    required this.startsOn,
    this.endsOn,
    required this.colorValue,
    required this.busyStatus,
    this.location,
    this.description,
    this.linkedTaskIds,
    this.linkedNoteIds,
  });

  final String title;
  final int startMinuteOfDay;
  final int endMinuteOfDay;
  final RecurrenceRule rule;
  final DateTime startsOn; // date-only
  final DateTime? endsOn; // date-only
  final int colorValue;
  final BusyStatus busyStatus;
  final String? location;
  final String? description;

  final List<String>? linkedTaskIds;
  final List<String>? linkedNoteIds;
}

class RecurringEventEditDialog extends ConsumerStatefulWidget {
  RecurringEventEditDialog({
    super.key,
    this.dialogTitle = 'Add recurring event',
    this.initialTitle = '',
    this.initialLocation = '',
    this.initialDescription = '',
    this.initialStart = const TimeOfDay(hour: 12, minute: 0),
    this.initialEnd = const TimeOfDay(hour: 13, minute: 0),
    this.initialRepeatType = RecurrenceType.daily,
    this.initialSelectedWeekdays,
    DateTime? initialStartsOn,
    this.initialEndsOn,
    this.initialColorValue = 0xFF2A8CFF,
    this.initialBusyStatus = BusyStatus.busy,
    this.initialLinkedTaskIds = const [],
    this.initialLinkedNoteIds = const [],
  }) : initialStartsOn = initialStartsOn ?? DateTime.now();

  final String dialogTitle;

  final String initialTitle;
  final String initialLocation;
  final String initialDescription;

  final TimeOfDay initialStart;
  final TimeOfDay initialEnd;

  final RecurrenceType initialRepeatType;
  final Set<int>? initialSelectedWeekdays;

  final DateTime initialStartsOn;
  final DateTime? initialEndsOn;

  final int initialColorValue;
  final BusyStatus initialBusyStatus;

  final List<String> initialLinkedTaskIds;
  final List<String> initialLinkedNoteIds;

  @override
  ConsumerState<RecurringEventEditDialog> createState() =>
      _RecurringEventEditDialogState();
}

class _RecurringEventEditDialogState extends ConsumerState<RecurringEventEditDialog> {
  static const _primaryBlue = Color(0xFF2A8CFF);

  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _description;

  late TimeOfDay _start;
  late TimeOfDay _end;

  late RecurrenceType _repeatType;
  late Set<int> _weekdays;

  late DateTime _startsOn;
  DateTime? _endsOn;

  late int _colorValue;
  late BusyStatus _busyStatus;

  late final Set<String> _linkedTaskIds = {...widget.initialLinkedTaskIds};
  late final Set<String> _linkedNoteIds = {...widget.initialLinkedNoteIds};

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _location = TextEditingController(text: widget.initialLocation);
    _description = TextEditingController(text: widget.initialDescription);

    _start = widget.initialStart;
    _end = widget.initialEnd;

    _repeatType = widget.initialRepeatType;
    _weekdays =
        (widget.initialSelectedWeekdays ?? <int>{1, 2, 3, 4, 5}).toSet();

    _startsOn = _dateOnly(widget.initialStartsOn);
    _endsOn =
        widget.initialEndsOn == null ? null : _dateOnly(widget.initialEndsOn!);

    _colorValue = widget.initialColorValue;
    _busyStatus = widget.initialBusyStatus;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int _minuteOfDay(TimeOfDay t) => t.hour * 60 + t.minute;

  String _fmtTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return weekday.toString();
    }
  }

  Future<void> _pickStartTime() async {
    final t = await showTimePicker(context: context, initialTime: _start);
    if (t == null) return;
    setState(() => _start = t);
  }

  Future<void> _pickEndTime() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t == null) return;
    setState(() => _end = t);
  }

  Future<void> _pickStartsOn() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (d == null) return;
    setState(() => _startsOn = _dateOnly(d));
  }

  Future<void> _pickEndsOn() async {
    final base = _endsOn ?? _startsOn;
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: _startsOn,
      lastDate: DateTime(2100, 12, 31),
    );
    if (d == null) return;
    setState(() => _endsOn = _dateOnly(d));
  }

  void _clearEndsOn() => setState(() => _endsOn = null);

  void _toggleWeekday(int weekday) {
    setState(() {
      if (_weekdays.contains(weekday)) {
        _weekdays.remove(weekday);
      } else {
        _weekdays.add(weekday);
      }
    });
  }

  bool get _timeValid => _minuteOfDay(_end) > _minuteOfDay(_start);

  RecurrenceRule _buildRule() {
    switch (_repeatType) {
      case RecurrenceType.daily:
        return const RecurrenceRule.daily(intervalDays: 1);
      case RecurrenceType.weekly:
        return RecurrenceRule.weekly(intervalWeeks: 1, weekdays: _weekdays);
    }
  }

  void _setColor(int v) => setState(() => _colorValue = v);

  Widget _colorDot(int v) {
    final selected = _colorValue == v;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _setColor(v),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Color(v),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.25),
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }

  Future<void> _pickLinks() async {
    final tasks = ref.read(tasksProvider);
    final notes = ref.read(notesProvider);

    final res = await showModalBottomSheet<LinkPickerResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: LinkPickerSheet(
          title: 'Links',
          initialTaskIds: _linkedTaskIds,
          initialNoteIds: _linkedNoteIds,
          initialEventIds: const {},
          initialRecurringTemplateIds: const {},
          tasks: tasks,
          notes: notes,
          events: const [],
          recurringTemplates: const [],
          showTasks: true,
          showNotes: true,
          showEvents: false,
          showRecurring: false,
        ),
      ),
    );

    if (res == null) return;
    setState(() {
      _linkedTaskIds
        ..clear()
        ..addAll(res.taskIds);
      _linkedNoteIds
        ..clear()
        ..addAll(res.noteIds);
    });
  }

  void _submit() {
    final title = _title.text.trim();
    final location = _location.text.trim();
    final description = _description.text.trim();

    if (title.isEmpty) {
      _showError('Title is required.');
      return;
    }
    if (!_timeValid) {
      _showError('End time must be later than start time.');
      return;
    }
    if (_repeatType == RecurrenceType.weekly && _weekdays.isEmpty) {
      _showError('Pick at least one weekday.');
      return;
    }

    Navigator.pop(
      context,
      RecurringEventDraft(
        title: title,
        location: location.isEmpty ? null : location,
        description: description.isEmpty ? null : description,
        startMinuteOfDay: _minuteOfDay(_start),
        endMinuteOfDay: _minuteOfDay(_end),
        rule: _buildRule(),
        startsOn: _startsOn,
        endsOn: _endsOn,
        colorValue: _colorValue,
        busyStatus: _busyStatus,
        linkedTaskIds: _linkedTaskIds.toList(),
        linkedNoteIds: _linkedNoteIds.toList(),
      ),
    );
  }

  void _showError(String msg) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invalid input'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final linksSummary = '${_linkedTaskIds.length} tasks • ${_linkedNoteIds.length} notes';

    const palette = <int>[
      0xFF2A8CFF,
      0xFF00BFA5,
      0xFF7C4DFF,
      0xFFFFC107,
      0xFFFF7043,
      0xFFEF5350,
      0xFF66BB6A,
      0xFFBDBDBD,
    ];

    final filledStyle = FilledButton.styleFrom(
      backgroundColor: _primaryBlue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    );
    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: cs.primary,
      side: BorderSide(color: cs.primary.withValues(alpha: 0.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(vertical: 14),
    );

    final media = MediaQuery.of(context);
    final availableHeight = media.size.height -
        media.padding.top -
        media.padding.bottom -
        media.viewInsets.bottom;
    final dialogHeight = availableHeight * 0.92;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          height: dialogHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                // header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.dialogTitle,
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // body scroll
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _title,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _location,
                          decoration: InputDecoration(
                            labelText: 'Location',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _description,
                          maxLines: 4,
                          minLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // links
                        InkWell(
                          onTap: _pickLinks,
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.link,
                                    color: cs.primary.withValues(alpha: 0.95)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Links',
                                    style: tt.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                Text(
                                  linksSummary,
                                  style: tt.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.70),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Text(
                          'Color',
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [for (final c in palette) _colorDot(c)],
                        ),

                        const SizedBox(height: 14),

                        Text(
                          'Time',
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: outlinedStyle,
                                onPressed: _pickStartTime,
                                child: Text('Start  ${_fmtTime(_start)}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                style: outlinedStyle,
                                onPressed: _pickEndTime,
                                child: Text('End  ${_fmtTime(_end)}'),
                              ),
                            ),
                          ],
                        ),
                        if (!_timeValid) ...[
                          const SizedBox(height: 6),
                          Text(
                            'End time must be later than start time.',
                            style: tt.bodySmall?.copyWith(color: Colors.redAccent),
                          ),
                        ],

                        const SizedBox(height: 14),

                        Text(
                          'Repeat',
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<RecurrenceType>(
                          segments: const [
                            ButtonSegment(
                              value: RecurrenceType.daily,
                              label: Text('Daily'),
                            ),
                            ButtonSegment(
                              value: RecurrenceType.weekly,
                              label: Text('Weekly'),
                            ),
                          ],
                          selected: {_repeatType},
                          onSelectionChanged: (s) =>
                              setState(() => _repeatType = s.first),
                        ),
                        if (_repeatType == RecurrenceType.weekly) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Weekdays',
                            style: tt.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in const [1, 2, 3, 4, 5, 6, 7])
                                FilterChip(
                                  label: Text(_weekdayLabel(d)),
                                  selected: _weekdays.contains(d),
                                  onSelected: (_) => _toggleWeekday(d),
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 14),

                        Text(
                          'Range',
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: outlinedStyle,
                          onPressed: _pickStartsOn,
                          child: Text(
                            'Starts  ${_startsOn.toIso8601String().split("T").first}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: outlinedStyle,
                                onPressed: _pickEndsOn,
                                child: Text(
                                  _endsOn == null
                                      ? 'Ends  (none)'
                                      : 'Ends  ${_endsOn!.toIso8601String().split("T").first}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (_endsOn != null)
                              OutlinedButton(
                                style: outlinedStyle,
                                onPressed: _clearEndsOn,
                                child: const Text('Clear'),
                              ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<BusyStatus>(
                          value: _busyStatus,
                          decoration: InputDecoration(
                            labelText: 'Busy status',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: BusyStatus.values
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _busyStatus = v ?? _busyStatus),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: outlinedStyle,
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: filledStyle,
                        onPressed: _submit,
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}