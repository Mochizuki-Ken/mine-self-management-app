import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_models.dart';
import '../../providers/tasks_provider.dart';
import '../widgets/task_edit_dialog.dart';

class TodayTasksPage extends ConsumerWidget {
  const TodayTasksPage({super.key});

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isToday(TaskDue due) {
    final s = _dateOnly(DateTime.now());
    final e = s.add(const Duration(days: 1));

    switch (due.type) {
      case TaskDueType.none:
        return false;

      case TaskDueType.at:
        final d = due.at!;
        return d.isAfter(s) && d.isBefore(e);

      case TaskDueType.on:
        final d = due.on!;
        final dd = _dateOnly(d);
        return dd.isAtSameMomentAs(s);

      case TaskDueType.month:
        // month-only due is not a "today task"
        return false;
    }
  }

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(tasksProvider);

    // Today tasks should be short tasks + due today (at/on)
    final today = all
        .where((t) => t.scale == TaskScale.short)
        .where((t) => _isToday(t.due))
        .toList()
      ..sort((a, b) {
        final done = (a.status == TaskStatus.done ? 1 : 0) -
            (b.status == TaskStatus.done ? 1 : 0);
        if (done != 0) return done;

        DateTime ad;
        DateTime bd;

        if (a.due.type == TaskDueType.at) {
          ad = a.due.at!;
        } else if (a.due.type == TaskDueType.on) {
          ad = _dateOnly(a.due.on!).add(const Duration(hours: 23, minutes: 59));
        } else {
          ad = DateTime.fromMillisecondsSinceEpoch(0);
        }

        if (b.due.type == TaskDueType.at) {
          bd = b.due.at!;
        } else if (b.due.type == TaskDueType.on) {
          bd = _dateOnly(b.due.on!).add(const Duration(hours: 23, minutes: 59));
        } else {
          bd = DateTime.fromMillisecondsSinceEpoch(0);
        }

        return ad.compareTo(bd);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today Tasks'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: () async {
              final draft = await showDialog<TaskDraft>(
                context: context,
                builder: (_) => const TaskEditDialog(
                  dialogTitle: 'Add task',
                  initialTitle: '',
                  initialDescription: '',
                  initialDue: null,
                ),
              );
              if (draft == null) return;

              final ok = await _confirm(
                context,
                title: 'Add task?',
                message:
                    'Add "${draft.title.trim().isEmpty ? '(No title)' : draft.title.trim()}"?',
                confirmText: 'Add',
              );
              if (!ok) return;

              final now = DateTime.now();

              ref.read(tasksProvider.notifier).add(
                    Task(
                      id: now.microsecondsSinceEpoch.toString(),
                      title: draft.title.trim().isEmpty
                          ? '(No title)'
                          : draft.title.trim(),
                      description: draft.description.trim().isEmpty
                          ? null
                          : draft.description.trim(),
                      createdAt: now,
                      updatedAt: now,
                      scale: TaskScale.short,
                      due: draft.due ?? const TaskDue.none(),
                      status: TaskStatus.todo,
                    ),
                  );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: today.isEmpty
          ? Center(
              child: Text(
                'No tasks due today',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withOpacity(0.55),
                    ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: today.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final task = today[i];

                return Dismissible(
                  key: ValueKey(task.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirm(
                    context,
                    title: 'Delete task?',
                    message: 'Delete "${task.title}"?',
                    confirmText: 'Delete',
                    destructive: true,
                  ),
                  onDismissed: (_) =>
                      ref.read(tasksProvider.notifier).remove(task.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete, color: Colors.redAccent),
                  ),
                  child: _TaskCard(
                    task: task,
                    onToggleDone: () =>
                        ref.read(tasksProvider.notifier).toggleDone(task.id),
                    onEdit: () async {
                      final draft = await showDialog<TaskDraft>(
                        context: context,
                        builder: (_) => TaskEditDialog(
                          dialogTitle: 'Edit task',
                          initialTitle: task.title,
                          initialDescription: task.description ?? '',
                          initialDue: task.due,
                        ),
                      );
                      if (draft == null) return;

                      final ok = await _confirm(
                        context,
                        title: 'Save changes?',
                        message: 'Update "${task.title}"?',
                        confirmText: 'Save',
                      );
                      if (!ok) return;

                      final now = DateTime.now();

                      ref.read(tasksProvider.notifier).update(
                            task.id,
                            task.copyWith(
                              title: draft.title.trim().isEmpty
                                  ? '(No title)'
                                  : draft.title.trim(),
                              description: draft.description.trim().isEmpty
                                  ? null
                                  : draft.description.trim(),
                              due: draft.due ?? const TaskDue.none(),
                              updatedAt: now,
                            ),
                          );
                    },
                    onDelete: () async {
                      final ok = await _confirm(
                        context,
                        title: 'Delete task?',
                        message: 'Delete "${task.title}"?',
                        confirmText: 'Delete',
                        destructive: true,
                      );
                      if (!ok) return;
                      ref.read(tasksProvider.notifier).remove(task.id);
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _fmtDueTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final isDone = task.status == TaskStatus.done;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: isDone ? 'Mark as not done' : 'Mark as done',
              onPressed: onToggleDone,
              icon: Icon(isDone ? Icons.check_box : Icons.check_box_outline_blank),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? Colors.white.withOpacity(0.55)
                          : Colors.white.withOpacity(0.92),
                    ),
                  ),
                  if ((task.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      style: tt.bodySmall
                          ?.copyWith(color: Colors.white.withOpacity(0.65)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (task.due.type == TaskDueType.at && task.due.at != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Due ${_fmtDueTime(task.due.at!)}',
                      style: tt.bodySmall
                          ?.copyWith(color: Colors.white.withOpacity(0.65)),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
          ],
        ),
      ),
    );
  }
}