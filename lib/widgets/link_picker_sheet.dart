import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/recurrence_models.dart';

class LinkPickerResult {
  const LinkPickerResult({
    required this.taskIds,
    required this.noteIds,
    required this.eventIds,
    required this.recurringTemplateIds,
  });

  final Set<String> taskIds;
  final Set<String> noteIds;
  final Set<String> eventIds;
  final Set<String> recurringTemplateIds;
}

class LinkPickerSheet extends StatefulWidget {
  const LinkPickerSheet({
    super.key,
    required this.initialTaskIds,
    required this.initialNoteIds,
    required this.initialEventIds,
    required this.initialRecurringTemplateIds,
    required this.tasks,
    required this.notes,
    required this.events,
    required this.recurringTemplates,
    this.showTasks = true,
    this.showNotes = true,
    this.showEvents = true,
    this.showRecurring = true,
    this.title = 'Links',
  });

  final Set<String> initialTaskIds;
  final Set<String> initialNoteIds;
  final Set<String> initialEventIds;
  final Set<String> initialRecurringTemplateIds;

  final List<Task> tasks;
  final List<Note> notes;
  final List<Event> events;
  final List<RecurringEventTemplate> recurringTemplates;

  final bool showTasks;
  final bool showNotes;
  final bool showEvents;
  final bool showRecurring;

  final String title;

  @override
  State<LinkPickerSheet> createState() => _LinkPickerSheetState();
}

class _LinkPickerSheetState extends State<LinkPickerSheet> {
  late final Set<String> _taskIds = {...widget.initialTaskIds};
  late final Set<String> _noteIds = {...widget.initialNoteIds};
  late final Set<String> _eventIds = {...widget.initialEventIds};
  late final Set<String> _recurringTemplateIds = {...widget.initialRecurringTemplateIds};

  String _q = '';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final q = _q.trim().toLowerCase();

    final tasks = q.isEmpty
        ? widget.tasks
        : widget.tasks.where((t) => t.title.toLowerCase().contains(q)).toList();
    final notes = q.isEmpty
        ? widget.notes
        : widget.notes.where((n) => n.title.toLowerCase().contains(q)).toList();
    final events = q.isEmpty
        ? widget.events
        : widget.events.where((e) => e.title.toLowerCase().contains(q)).toList();
    final recurring = q.isEmpty
        ? widget.recurringTemplates
        : widget.recurringTemplates.where((t) => t.title.toLowerCase().contains(q)).toList();

    final media = MediaQuery.of(context);
    final sheetHeight = (media.size.height - media.viewInsets.bottom) * 0.85;

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(text, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
        );

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + media.viewInsets.bottom,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      LinkPickerResult(
                        taskIds: _taskIds,
                        noteIds: _noteIds,
                        eventIds: _eventIds,
                        recurringTemplateIds: _recurringTemplateIds,
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search...',
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    if (widget.showTasks) ...[
                      sectionTitle('Tasks (${widget.tasks.length})'),
                      if (widget.tasks.isEmpty)
                        Text('No tasks',
                            style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)))
                      else
                        for (final t in tasks)
                          CheckboxListTile(
                            value: _taskIds.contains(t.id),
                            onChanged: (v) => setState(() {
                              if (v == true) _taskIds.add(t.id);
                              if (v == false) _taskIds.remove(t.id);
                            }),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(t.title.trim().isEmpty ? '(No title)' : t.title),
                            subtitle: Text('${t.scale.name} • ${t.status.name}'),
                          ),
                    ],
                    if (widget.showNotes) ...[
                      sectionTitle('Notes (${widget.notes.length})'),
                      if (widget.notes.isEmpty)
                        Text('No notes',
                            style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)))
                      else
                        for (final n in notes)
                          CheckboxListTile(
                            value: _noteIds.contains(n.id),
                            onChanged: (v) => setState(() {
                              if (v == true) _noteIds.add(n.id);
                              if (v == false) _noteIds.remove(n.id);
                            }),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(n.title.trim().isEmpty ? '(No title)' : n.title),
                          ),
                    ],
                    if (widget.showEvents) ...[
                      sectionTitle('Events (${widget.events.length})'),
                      if (widget.events.isEmpty)
                        Text('No events',
                            style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)))
                      else
                        for (final e in events)
                          CheckboxListTile(
                            value: _eventIds.contains(e.id),
                            onChanged: (v) => setState(() {
                              if (v == true) _eventIds.add(e.id);
                              if (v == false) _eventIds.remove(e.id);
                            }),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(e.title.trim().isEmpty ? '(No title)' : e.title),
                          ),
                    ],
                    if (widget.showRecurring) ...[
                      sectionTitle('Recurring series (${widget.recurringTemplates.length})'),
                      if (widget.recurringTemplates.isEmpty)
                        Text('No recurring series',
                            style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)))
                      else
                        for (final t in recurring)
                          CheckboxListTile(
                            value: _recurringTemplateIds.contains(t.id),
                            onChanged: (v) => setState(() {
                              if (v == true) _recurringTemplateIds.add(t.id);
                              if (v == false) _recurringTemplateIds.remove(t.id);
                            }),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(t.title.trim().isEmpty ? '(No title)' : t.title),
                            subtitle: Text(t.rule.type.name),
                          ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}