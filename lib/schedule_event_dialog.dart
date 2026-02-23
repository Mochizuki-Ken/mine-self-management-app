import 'package:flutter/material.dart';
import 'models/app_models.dart'; // add to access BusyStatus

// import '../testData.dart';

class ScheduleEventDraft {
  ScheduleEventDraft({
    required this.title,
    required this.location,
    required this.start,
    required this.end,
    required this.colorValue,
    this.description,
    this.busyStatus,
  });

  final String title;
  final String location;
  final DateTime start;
  final DateTime end;
  final int colorValue;
  final String? description;
  final BusyStatus? busyStatus;

  // static ScheduleEventDraft fromEvent(Event e) {}
}

class ScheduleEventDialog extends StatefulWidget {
  const ScheduleEventDialog({
    super.key,
    required this.dialogTitle,
    required this.initial,
  });

  final String dialogTitle;
  final ScheduleEventDraft initial;

  // Adapted to the current Event model (startAt/endAt, nullable location)
  static ScheduleEventDraft fromEvent(Event e) => ScheduleEventDraft(
        title: e.title,
        location: e.location ?? '',
        start: e.startAt,
        end: e.endAt,
        colorValue: e.colorValue,
        description: e.description,
        busyStatus: e.busyStatus,
      );

  @override
  State<ScheduleEventDialog> createState() => _ScheduleEventDialogState();
}

class _ScheduleEventDialogState extends State<ScheduleEventDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial.title);
  late final TextEditingController _location =
      TextEditingController(text: widget.initial.location);
  late final TextEditingController _description =
      TextEditingController(text: widget.initial.description ?? '');

  late DateTime _start = widget.initial.start;
  late DateTime _end = widget.initial.end;
  late int _colorValue = widget.initial.colorValue;
  late BusyStatus? _busyStatus = widget.initial.busyStatus ?? BusyStatus.busy;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return null;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (t == null) return null;

    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) {
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
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final v = await _pickDateTime(_start);
                      if (v != null) setState(() => _start = v);
                    },
                    child: Text('Start: ${_hm(_start)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final v = await _pickDateTime(_end);
                      if (v != null) setState(() => _end = v);
                    },
                    child: Text('End: ${_hm(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<BusyStatus>(
              value: _busyStatus,
              decoration: const InputDecoration(labelText: 'Busy status'),
              items: [
                for (final s in BusyStatus.values)
                  DropdownMenuItem(
                    value: s,
                    child: Text(s.name),
                  ),
              ],
              onChanged: (v) => setState(() => _busyStatus = v),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Color',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (final c in const [
                  Color(0xFF2A8CFF),
                  Color(0xFF8A2BE2),
                  Color(0xFFFFC857),
                  Color(0xFFFF4D6D),
                  Color(0xFF00D18F),
                ])
                  GestureDetector(
                    onTap: () => setState(() => _colorValue = c.value),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                        border: Border.all(
                          color: _colorValue == c.value
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
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
          onPressed: () {
            Navigator.of(context).pop(
              ScheduleEventDraft(
                title: _title.text,
                location: _location.text,
                description: _description.text,
                start: _start,
                end: _end,
                colorValue: _colorValue,
                busyStatus: _busyStatus,
              ),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}