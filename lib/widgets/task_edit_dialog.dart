import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_models.dart';
import '../../providers/events_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/recurring_events_provider.dart';
import '../../widgets/link_picker_sheet.dart';

class TaskDraft {
  TaskDraft({
    required this.title,
    required this.description,
    required this.due,
    required this.linkedNoteIds,
    required this.linkedEventIds,
    required this.linkedRecurringTemplateIds,
  });

  final String title;
  final String description;
  final TaskDue? due;

  final List<String> linkedNoteIds;
  final List<String> linkedEventIds;
  final List<String> linkedRecurringTemplateIds;
}

class TaskEditDialog extends ConsumerStatefulWidget {
  const TaskEditDialog({
    super.key,
    required this.dialogTitle,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialDue,
    this.initialLinkedNoteIds = const [],
    this.initialLinkedEventIds = const [],
    this.initialLinkedRecurringTemplateIds = const [],
  });

  final String dialogTitle;
  final String initialTitle;
  final String initialDescription;
  final TaskDue? initialDue;

  final List<String> initialLinkedNoteIds;
  final List<String> initialLinkedEventIds;
  final List<String> initialLinkedRecurringTemplateIds;

  @override
  ConsumerState<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends ConsumerState<TaskEditDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initialTitle);
  late final TextEditingController _description =
      TextEditingController(text: widget.initialDescription);

  late TaskDue? _due = widget.initialDue;
  late TaskDueType _dueType = widget.initialDue?.type ?? TaskDueType.none;

  late final Set<String> _linkedNoteIds = {...widget.initialLinkedNoteIds};
  late final Set<String> _linkedEventIds = {...widget.initialLinkedEventIds};
  late final Set<String> _linkedRecurringTemplateIds = {
    ...widget.initialLinkedRecurringTemplateIds
  };

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(BuildContext context, {DateTime? initial}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, {DateTime? initial}) {
    final now = DateTime.now();
    return showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
  }

  Future<void> _pickDueValue(BuildContext context) async {
    switch (_dueType) {
      case TaskDueType.none:
        setState(() => _due = const TaskDue.none());
        return;
      case TaskDueType.at:
        final d = await _pickDate(context, initial: _due?.at);
        if (d == null) return;
        final t = await _pickTime(context, initial: _due?.at);
        if (t == null) return;
        final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        setState(() => _due = TaskDue.at(dt));
        return;
      case TaskDueType.on:
        final d = await _pickDate(context, initial: _due?.on);
        if (d == null) return;
        final only = DateTime(d.year, d.month, d.day);
        setState(() => _due = TaskDue.on(only));
        return;
      case TaskDueType.month:
        final d = await _pickDate(context, initial: _due?.on ?? _due?.at);
        if (d == null) return;
        setState(() => _due = TaskDue.month(year: d.year, month: d.month));
        return;
    }
  }

  String _fmtDue(TaskDue? due) {
    if (due == null || due.type == TaskDueType.none) return 'No due';
    String two(int n) => n.toString().padLeft(2, '0');
    switch (due.type) {
      case TaskDueType.at:
        final d = due.at!;
        return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
      case TaskDueType.on:
        final d = due.on!;
        return '${d.year}-${two(d.month)}-${two(d.day)}';
      case TaskDueType.month:
        return '${due.year}-${two(due.month!)}';
      case TaskDueType.none:
        return 'No due';
    }
  }

  Future<void> _pickLinks() async {
    final notes = ref.read(notesProvider);
    final events = ref.read(eventsProvider);
    final recurring = ref.read(recurringEventsProvider);

    final res = await showModalBottomSheet<LinkPickerResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // nicer rounded sheet
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: LinkPickerSheet(
          title: 'Links',
          initialTaskIds: const {},
          initialNoteIds: _linkedNoteIds,
          initialEventIds: _linkedEventIds,
          initialRecurringTemplateIds: _linkedRecurringTemplateIds,
          tasks: const [],
          notes: notes,
          events: events,
          recurringTemplates: recurring,
          showTasks: false,
          showNotes: true,
          showEvents: true,
          showRecurring: true,
        ),
      ),
    );

    if (res == null) return;
    setState(() {
      _linkedNoteIds
        ..clear()
        ..addAll(res.noteIds);
      _linkedEventIds
        ..clear()
        ..addAll(res.eventIds);
      _linkedRecurringTemplateIds
        ..clear()
        ..addAll(res.recurringTemplateIds);
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final notesCount = _linkedNoteIds.length;
    final eventsCount = _linkedEventIds.length;
    final recurringCount = _linkedRecurringTemplateIds.length;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (more iOS-like than AlertDialog)
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

              // Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _title,
                        textInputAction: TextInputAction.next,
                        decoration: _dec('Title'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 8,
                        decoration: _dec('Description'),
                      ),
                      const SizedBox(height: 12),

                      // Due + type in a nicer card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event_outlined),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Due date',
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  _fmtDue(_due),
                                  style: tt.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.70),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<TaskDueType>(
                                    value: _dueType,
                                    decoration: _dec('Type'),
                                    borderRadius: BorderRadius.circular(14),
                                    items: TaskDueType.values
                                        .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t.name),
                                            ))
                                        .toList(),
                                    onChanged: (t) {
                                      if (t == null) return;
                                      setState(() {
                                        _dueType = t;
                                        if (t == TaskDueType.none) {
                                          _due = const TaskDue.none();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 14,
                                      ),
                                    ),
                                    onPressed: () => _pickDueValue(context),
                                    child: const Text('Pick'),
                                  ),
                                ),
                                if (_dueType != TaskDueType.none &&
                                    _due?.type != TaskDueType.none)
                                  IconButton(
                                    tooltip: 'Clear',
                                    onPressed: () => setState(() {
                                      _dueType = TaskDueType.none;
                                      _due = const TaskDue.none();
                                    }),
                                    icon: const Icon(Icons.close),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Links row as a card
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
                              const Icon(Icons.link),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Links',
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                '$notesCount Notes • $eventsCount Events • $recurringCount Series',
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Actions (bottom aligned, iOS-ish)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(
                        TaskDraft(
                          title: _title.text,
                          description: _description.text,
                          due: _due,
                          linkedNoteIds: _linkedNoteIds.toList(),
                          linkedEventIds: _linkedEventIds.toList(),
                          linkedRecurringTemplateIds:
                              _linkedRecurringTemplateIds.toList(),
                        ),
                      ),
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