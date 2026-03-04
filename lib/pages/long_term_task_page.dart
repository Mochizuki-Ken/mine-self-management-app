import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../providers/tasks_provider.dart';
import '../widgets/project_progress_bar.dart';

class LongTermTaskPage extends ConsumerWidget {
  const LongTermTaskPage({
    super.key,
    required this.taskId,
  });

  final String taskId;

  Task? _find(List<Task> tasks) {
    for (final t in tasks) {
      if (t.id == taskId) return t;
    }
    return null;
  }

  int _doneSubCount(Task task) =>
      task.subTasks.where((st) => st.status == TaskStatus.done).length;

  Future<String?> _askText(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final t = _find(tasks);
    final notifier = ref.read(tasksProvider.notifier);
    final tt = Theme.of(context).textTheme;

    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Long-term task')),
        body: const Center(child: Text('Task not found')),
      );
    }

    final totalSubs = t.subTasks.length;
    final doneSubs = _doneSubCount(t);

    final progressLabel = totalSubs == 0
        ? 'No sub-tasks'
        : '$doneSubs / $totalSubs done';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Long-term task'),
        actions: [
          TextButton(
            onPressed: () => notifier.toggleDone(t.id),
            child: Text(t.status == TaskStatus.done ? 'Todo' : 'Done'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Text(
            t.title.trim().isEmpty ? '(No title)' : t.title,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            (t.description ?? '').trim().isEmpty ? 'No description' : t.description!.trim(),
            style: tt.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 14),

          // NEW: progress bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Progress',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text(
                      progressLabel,
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ProjectProgressBar(
                  totalSubTasks: totalSubs,
                  doneSubTasks: doneSubs,
                  showLabel: false, // we show our own label above
                  progressColor: Colors.lightBlueAccent,
                  trackColor: Colors.white.withValues(alpha: 0.10),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final title = await _askText(context, title: 'Add sub-task');
                    final v = (title ?? '').trim();
                    if (v.isEmpty) return;

                    final now = DateTime.now();
                    notifier.addSubTask(
                      t.id,
                      Task(
                        id: now.microsecondsSinceEpoch.toString(),
                        title: v,
                        status: TaskStatus.todo,
                        priority: TaskPriority.normal,
                        scale: TaskScale.short,
                        due: const TaskDue.none(),
                        subTasks: const [],
                        linkedNoteIds: const [],
                        linkedEventIds: const [],
                        estimatedMinutes: null,
                        tags: const [],
                        createdAt: now,
                        updatedAt: now,
                      ),
                    );
                  },
                  child: const Text('Add sub-task'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            'Sub-tasks ($totalSubs)',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),

          if (t.subTasks.isEmpty)
            Text(
              'No sub-tasks yet',
              style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
            )
          else
            for (final st in t.subTasks)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: ListTile(
                  leading: Icon(
                    st.status == TaskStatus.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(st.title.trim().isEmpty ? '(No title)' : st.title),
                  subtitle: Text(st.status.name),
                  onTap: () => notifier.toggleSubTaskDone(t.id, st.id),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => notifier.removeSubTask(t.id, st.id),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}