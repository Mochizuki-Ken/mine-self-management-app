import 'package:flutter/material.dart';
import '../models/app_models.dart';

class TaskDraft {
  TaskDraft({
    required this.title,
    required this.description,
    required this.due,
  });

  final String title;
  final String description;
  final TaskDue? due;
}

class TaskEditDialog extends StatefulWidget {
  const TaskEditDialog({
    super.key,
    required this.dialogTitle,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialDue,
  });

  final String dialogTitle;
  final String initialTitle;
  final String initialDescription;
  final TaskDue? initialDue;

  @override
  State<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<TaskEditDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initialTitle);
  late final TextEditingController _description =
      TextEditingController(text: widget.initialDescription);

  late TaskDue? _due = widget.initialDue;
  late TaskDueType _dueType =
      widget.initialDue?.type ?? TaskDueType.none;

  Future<DateTime?> _pickDate(BuildContext context,
      {DateTime? initial}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<TimeOfDay?> _pickTime(BuildContext context,
      {DateTime? initial}) {
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
    if (due == null || due.type == TaskDueType.none) return 'No due date';
    String two(int n) => n.toString().padLeft(2, '0');
    switch (due.type) {
      case TaskDueType.at:
        final d = due.at!;
        return 'Due: ${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
      case TaskDueType.on:
        final d = due.on!;
        return 'Due: ${d.year}-${two(d.month)}-${two(d.day)}';
      case TaskDueType.month:
        return 'Due: ${due.year}-${two(due.month!)}';
      case TaskDueType.none:
        return 'No due date';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueTypes = TaskDueType.values;

    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TaskDueType>(
                    value: _dueType,
                    decoration: const InputDecoration(labelText: 'Due type'),
                    items: dueTypes
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
                    onPressed: () => _pickDueValue(context),
                    child: Text(_fmtDue(_due)),
                  ),
                ),
                if (_dueType != TaskDueType.none &&
                    _due?.type != TaskDueType.none)
                  IconButton(
                    tooltip: 'Clear due',
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            TaskDraft(
              title: _title.text,
              description: _description.text,
              due: _due,
            ),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}