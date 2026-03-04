import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../providers/notes_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/link_picker_sheet.dart';

class ScheduleEventDraft {
  ScheduleEventDraft({
    required this.title,
    required this.location,
    required this.start,
    required this.end,
    required this.colorValue,
    this.description,
    this.busyStatus,
    this.linkedTaskIds,
    this.linkedNoteIds,
  });

  final String title;
  final String location;
  final DateTime start;
  final DateTime end;
  final int colorValue;
  final String? description;
  final BusyStatus? busyStatus;

  final List<String>? linkedTaskIds;
  final List<String>? linkedNoteIds;
}

class ScheduleEventDialog extends ConsumerStatefulWidget {
  const ScheduleEventDialog({
    super.key,
    required this.dialogTitle,
    required this.initial,
  });

  final String dialogTitle;
  final ScheduleEventDraft initial;

  static ScheduleEventDraft fromEvent(Event e) => ScheduleEventDraft(
        title: e.title,
        location: e.location ?? '',
        start: e.startAt,
        end: e.endAt,
        colorValue: e.colorValue,
        description: e.description,
        busyStatus: e.busyStatus,
        linkedTaskIds: e.linkedTaskIds,
        linkedNoteIds: e.linkedNoteIds,
      );

  @override
  ConsumerState<ScheduleEventDialog> createState() => _ScheduleEventDialogState();
}

class _ScheduleEventDialogState extends ConsumerState<ScheduleEventDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial.title);
  late final TextEditingController _location =
      TextEditingController(text: widget.initial.location);
  late final TextEditingController _description =
      TextEditingController(text: widget.initial.description ?? '');

  late DateTime _start = widget.initial.start;
  late DateTime _end = widget.initial.end;
  late int _colorValue = widget.initial.colorValue;
  late BusyStatus _busyStatus = widget.initial.busyStatus ?? BusyStatus.busy;

  late final Set<String> _linkedTaskIds =
      (widget.initial.linkedTaskIds ?? const <String>[]).toSet();
  late final Set<String> _linkedNoteIds =
      (widget.initial.linkedNoteIds ?? const <String>[]).toSet();

  static const _primaryBlue = Color(0xFF2A8CFF);

  static const _palette = <int>[
    0xFF2A8CFF,
    0xFF00BFA5,
    0xFF7C4DFF,
    0xFFFFC107,
    0xFFFF7043,
    0xFFEF5350,
    0xFF66BB6A,
    0xFFBDBDBD,
  ];

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  bool get _timeValid => _end.isAfter(_start);

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      );

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateOnly(_start),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (t == null) return;

    setState(() {
      _start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (!_end.isAfter(_start)) {
        _end = _start.add(const Duration(minutes: 30));
      }
    });
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateOnly(_end),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
    );
    if (t == null) return;

    setState(() => _end = DateTime(d.year, d.month, d.day, t.hour, t.minute));
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
          initialEventIds: const {}, // event doesn't link other one-off events
          initialRecurringTemplateIds: const {}, // ✅ DISABLED for normal events
          tasks: tasks,
          notes: notes,
          events: const [],
          recurringTemplates: const [], // ✅ DISABLED for normal events
          showTasks: true,
          showNotes: true,
          showEvents: false,
          showRecurring: false, // ✅ hide recurring selector
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
    if (title.isEmpty) {
      _showError('Title is required.');
      return;
    }
    if (!_timeValid) {
      _showError('End must be after start.');
      return;
    }

    Navigator.of(context).pop(
      ScheduleEventDraft(
        title: title,
        location: _location.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        start: _start,
        end: _end,
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _title,
                decoration: _dec('Title', hint: 'Meeting / Study / Gym...'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _location,
                decoration: _dec('Location', hint: 'Office / Home / Online...'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 4,
                minLines: 2,
                decoration: _dec('Description'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Time',
                            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (!_timeValid)
                          Text(
                            'Invalid',
                            style: tt.bodySmall?.copyWith(color: Colors.redAccent),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeButton(
                            label: 'Start',
                            dateText: _ymd(_start),
                            timeText: _hm(_start),
                            onPressed: _pickStart,
                            foreground: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeButton(
                            label: 'End',
                            dateText: _ymd(_end),
                            timeText: _hm(_end),
                            onPressed: _pickEnd,
                            foreground: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<BusyStatus>(
                      value: _busyStatus,
                      decoration: _dec('Busy status'),
                      items: [
                        for (final s in BusyStatus.values)
                          DropdownMenuItem(value: s, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => _busyStatus = v ?? _busyStatus),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ColorPickerField(
                      value: _colorValue,
                      palette: _palette,
                      onChanged: (v) => setState(() => _colorValue = v),
                      accent: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickLinks,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, color: cs.primary.withValues(alpha: 0.95)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Links',
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: outlinedStyle,
                      onPressed: () => Navigator.of(context).pop(null),
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
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.dateText,
    required this.timeText,
    required this.onPressed,
    required this.foreground,
  });

  final String label;
  final String dateText;
  final String timeText;
  final VoidCallback onPressed;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: foreground.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            dateText,
            style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
          ),
          const SizedBox(height: 2),
          Text(timeText, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ColorPickerField extends StatelessWidget {
  const _ColorPickerField({
    required this.value,
    required this.palette,
    required this.onChanged,
    required this.accent,
  });

  final int value;
  final List<int> palette;
  final ValueChanged<int> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Color',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.90), width: 1.6),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final c in palette)
            InkWell(
              onTap: () => onChanged(c),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value == c ? Colors.white : Colors.transparent,
                    width: value == c ? 2.5 : 1,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 2),
          Text(
            '#${value.toRadixString(16).toUpperCase().padLeft(8, '0')}',
            style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
          ),
        ],
      ),
    );
  }
}