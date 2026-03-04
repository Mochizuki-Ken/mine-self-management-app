import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mine/pages/long_term_task_page.dart';
// import 'package:flutter_riverpod/legacy.dart';

import '../models/app_models.dart';
import '../providers/tasks_provider.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({
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

  Future<void> _editText({
    required BuildContext context,
    required String title,
    required String initial,
    required String label,
    required void Function(String v) onSave,
    int maxLines = 1,
  }) async {
    final c = TextEditingController(text: initial);
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (res == null) return;
    onSave(res);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final t = _find(tasks);

    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task')),
        body: const Center(child: Text('Task not found')),
      );
    }

    final notifier = ref.read(tasksProvider.notifier);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: [
          if (t.scale == TaskScale.long)
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LongTermTaskPage(taskId: t.id),
                  ),
                );
              },
              child: const Text('Long-term'),
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

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(label: 'Status', value: t.status.name),
              _InfoChip(label: 'Priority', value: t.priority.name),
              _InfoChip(label: 'Scale', value: t.scale.name),
              if (t.estimatedMinutes != null)
                _InfoChip(label: 'Est', value: '${t.estimatedMinutes}m'),
            ],
          ),

          const SizedBox(height: 16),

          _SectionTitle('Actions'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => notifier.toggleDone(t.id),
                  child: Text(t.status == TaskStatus.done ? 'Mark todo' : 'Mark done'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _SectionTitle('Edit'),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Title'),
            subtitle: Text(t.title.trim().isEmpty ? '(No title)' : t.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editText(
              context: context,
              title: 'Edit title',
              initial: t.title,
              label: 'Title',
              onSave: (v) => notifier.update(
                t.id,
                t.copyWith(title: v, updatedAt: DateTime.now()),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Description'),
            subtitle: Text(
              (t.description ?? '').trim().isEmpty ? '(none)' : t.description!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editText(
              context: context,
              title: 'Edit description',
              initial: t.description ?? '',
              label: 'Description',
              maxLines: 5,
              onSave: (v) => notifier.update(
                t.id,
                t.copyWith(description: v.trim().isEmpty ? null : v.trim(), updatedAt: DateTime.now()),
              ),
            ),
          ),

          const SizedBox(height: 6),
          DropdownButtonFormField<TaskStatus>(
            value: t.status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final s in TaskStatus.values)
                DropdownMenuItem(value: s, child: Text(s.name)),
            ],
            onChanged: (v) {
              if (v == null) return;
              notifier.update(t.id, t.copyWith(status: v, updatedAt: DateTime.now()));
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<TaskPriority>(
            value: t.priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: [
              for (final p in TaskPriority.values)
                DropdownMenuItem(value: p, child: Text(p.name)),
            ],
            onChanged: (v) {
              if (v == null) return;
              notifier.update(t.id, t.copyWith(priority: v, updatedAt: DateTime.now()));
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<TaskScale>(
            value: t.scale,
            decoration: const InputDecoration(labelText: 'Scale'),
            items: [
              for (final s in TaskScale.values)
                DropdownMenuItem(value: s, child: Text(s.name)),
            ],
            onChanged: (v) {
              if (v == null) return;
              notifier.update(t.id, t.copyWith(scale: v, updatedAt: DateTime.now()));
            },
          ),

          const SizedBox(height: 18),

          _SectionTitle('Sub-tasks'),
          const SizedBox(height: 6),
          if (t.subTasks.isEmpty)
            Text(
              'No sub-tasks',
              style: tt.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
            )
          else
            for (final st in t.subTasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  st.status == TaskStatus.done ? Icons.check_circle : Icons.radio_button_unchecked,
                ),
                title: Text(st.title.trim().isEmpty ? '(No title)' : st.title),
                subtitle: Text(st.status.name),
              ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    );
  }
}