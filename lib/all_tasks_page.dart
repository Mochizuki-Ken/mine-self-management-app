import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../providers/task_store.dart';
import 'task_edit_dialog.dart';

class AllTasksPage extends ConsumerWidget {
  const AllTasksPage({super.key});

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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _sortDue(TaskDue due) {
    switch (due.type) {
      case TaskDueType.none:
        return DateTime.fromMillisecondsSinceEpoch(0);
      case TaskDueType.at:
        return due.at!;
      case TaskDueType.on:
        return _dateOnly(due.on!).add(const Duration(hours: 23, minutes: 59));
      case TaskDueType.month:
        final y = due.year!;
        final m = due.month!;
        final firstNextMonth =
            (m == 12) ? DateTime(y + 1, 1, 1) : DateTime(y, m + 1, 1);
        return firstNextMonth.subtract(const Duration(minutes: 1));
    }
  }

  String _fmtDue(TaskDue due) {
    String two(int n) => n.toString().padLeft(2, '0');
    switch (due.type) {
      case TaskDueType.none:
        return '';
      case TaskDueType.at:
        final d = due.at!;
        return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
      case TaskDueType.on:
        final d = due.on!;
        return '${d.year}-${two(d.month)}-${two(d.day)}';
      case TaskDueType.month:
        return '${due.year}-${two(due.month!)}';
    }
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(tasksProvider);

    final longTermTasks = all.where((t) => t.scale == TaskScale.long).toList()
      ..sort((a, b) => _sortDue(a.due).compareTo(_sortDue(b.due)));
    final shortTermTasks = all.where((t) => t.scale == TaskScale.short).toList()
      ..sort((a, b) => _sortDue(a.due).compareTo(_sortDue(b.due)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
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
                message: 'Add "${draft.title.trim().isEmpty ? '(No title)' : draft.title.trim()}"?',
                confirmText: 'Add',
              );
              if (!ok) return;

              final now = DateTime.now();

              ref.read(tasksProvider.notifier).add(
                    Task(
                      id: now.microsecondsSinceEpoch.toString(),
                      title: draft.title.trim().isEmpty ? '(No title)' : draft.title.trim(),
                      description: draft.description.trim().isEmpty ? null : draft.description.trim(),
                      createdAt: now,
                      updatedAt: now,
                      scale: TaskScale.short,
                      due: draft.due ?? const TaskDue.none(),
                      status: TaskStatus.todo,
                      priority: TaskPriority.normal,
                    ),
                  );
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (longTermTasks.isNotEmpty) ...[
            Text('Long-Term Projects', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...List.generate(longTermTasks.length, (i) {
              final task = longTermTasks[i];
              return Padding(
                padding: EdgeInsets.only(bottom: i == longTermTasks.length - 1 ? 16 : 10),
                child: _buildLongTermTaskCard(context, ref, task),
              );
            }),
          ],
          if (shortTermTasks.isNotEmpty) ...[
            Text('Short-Term Tasks', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ...List.generate(shortTermTasks.length, (i) {
              final task = shortTermTasks[i];
              return Padding(
                padding: EdgeInsets.only(bottom: i == shortTermTasks.length - 1 ? 0 : 10),
                child: _buildTaskCard(context, task, ref),
              );
            }),
          ],
          if (shortTermTasks.isEmpty && longTermTasks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'No tasks yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.55),
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLongTermTaskCard(BuildContext context, WidgetRef ref, Task task) {
    final tt = Theme.of(context).textTheme;
    final dueStr = _fmtDue(task.due);
    final subCount = task.subTasks.length;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LongTermTaskDetailPage(taskId: task.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.withOpacity(0.28), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_open, color: Colors.lightBlueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      if (dueStr.isNotEmpty)
                        Text(
                          dueStr,
                          style: tt.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      if (subCount > 0) ...[
                        if (dueStr.isNotEmpty) const SizedBox(width: 12),
                        Text(
                          '$subCount sub-tasks',
                          style: tt.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task, WidgetRef ref) {
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
      onDismissed: (_) => ref.read(tasksProvider.notifier).remove(task.id),
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
        fmtDue: _fmtDue,
        onToggleDone: () => ref.read(tasksProvider.notifier).toggleDone(task.id),
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

          ref.read(tasksProvider.notifier).update(
                task.id,
                task.copyWith(
                  title: draft.title.trim().isEmpty ? '(No title)' : draft.title.trim(),
                  description: draft.description.trim().isEmpty ? null : draft.description.trim(),
                  due: draft.due ?? const TaskDue.none(),
                  updatedAt: DateTime.now(),
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
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.fmtDue,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final String Function(TaskDue due) fmtDue;

  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDone = task.status == TaskStatus.done;
    final dueStr = fmtDue(task.due);
    final scaleStr = task.scale == TaskScale.long ? 'Long' : 'Short';

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone
                                ? Colors.white.withOpacity(0.55)
                                : Colors.white.withOpacity(0.92),
                          ),
                        ),
                      ),
                      Text(
                        scaleStr,
                        style: tt.labelMedium?.copyWith(
                          color: Colors.white.withOpacity(0.55),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if ((task.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description!,
                      style: tt.bodySmall?.copyWith(color: Colors.white.withOpacity(0.65)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (dueStr.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Due $dueStr',
                      style: tt.bodySmall?.copyWith(color: Colors.white.withOpacity(0.65)),
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

class LongTermTaskDetailPage extends ConsumerWidget {
  const LongTermTaskDetailPage({super.key, required this.taskId});
  final String taskId;

  String _fmtLongTaskDue(TaskDue due) {
    String two(int n) => n.toString().padLeft(2, '0');
    switch (due.type) {
      case TaskDueType.none:
        return '';
      case TaskDueType.at:
        final d = due.at!;
        return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
      case TaskDueType.on:
        final d = due.on!;
        return '${d.year}-${two(d.month)}-${two(d.day)}';
      case TaskDueType.month:
        return '${due.year}-${two(due.month!)}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(tasksProvider).firstWhere((t) => t.id == taskId);
    final tt = Theme.of(context).textTheme;
    final dueStr =
        task.due.type == TaskDueType.none ? '' : _fmtLongTaskDue(task.due);

    return Scaffold(
      appBar: AppBar(title: Text(task.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if ((task.description ?? '').isNotEmpty)
            Text(task.description!, style: tt.bodyLarge),
          if (dueStr.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Due: $dueStr', style: tt.bodyMedium),
          ],
          const SizedBox(height: 16),
          Text('Sub-tasks', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (task.subTasks.isEmpty)
            Text('No sub-tasks', style: tt.bodySmall?.copyWith(color: Colors.white60))
          else
            ...task.subTasks.map(
              (st) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  st.status == TaskStatus.done ? Icons.check_box : Icons.check_box_outline_blank,
                ),
                title: Text(st.title),
                subtitle: ((st.description ?? '').isNotEmpty)
                    ? Text(st.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (st.linkedNoteIds.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.note_alt_outlined, size: 18),
                      ),
                    if (st.linkedEventIds.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.event_available_outlined, size: 18),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}