import 'package:flutter_riverpod/legacy.dart';
import '../models/app_models.dart';

final tasksProvider = StateNotifierProvider<TasksController, List<Task>>((ref) {
  return TasksController(seed: _seedTasks());
});

class TasksController extends StateNotifier<List<Task>> {
  TasksController({required List<Task> seed}) : super(seed);

  void add(Task t) => state = [...state, t];

  void toggleDone(String id) {
    final now = DateTime.now();
    state = [
      for (final x in state)
        if (x.id == id)
          x.copyWith(
            status: x.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done,
            updatedAt: now,
          )
        else
          x
    ];
  }

  void remove(String id) {
    state = [
      for (final task in state)
        if (task.id != id) task,
    ];
  }

  void update(String id, Task updatedTask) {
    state = [
      for (final t in state)
        if (t.id == id) updatedTask else t
    ];
  }

  // ----- Sub-task helpers for long-term/project tasks -----

  void addSubTask(String parentId, Task subTask) {
    final now = DateTime.now();
    state = [
      for (final t in state)
        if (t.id == parentId)
          t.copyWith(
            subTasks: [...t.subTasks, subTask],
            updatedAt: now,
          )
        else
          t
    ];
  }

  void updateSubTask(String parentId, String subId, Task updatedSubTask) {
    final now = DateTime.now();
    state = [
      for (final t in state)
        if (t.id == parentId)
          t.copyWith(
            subTasks: [
              for (final st in t.subTasks)
                if (st.id == subId) updatedSubTask else st
            ],
            updatedAt: now,
          )
        else
          t
    ];
  }

  void toggleSubTaskDone(String parentId, String subId) {
    final now = DateTime.now();
    state = [
      for (final t in state)
        if (t.id == parentId)
          t.copyWith(
            subTasks: [
              for (final st in t.subTasks)
                if (st.id == subId)
                  st.copyWith(
                    status: st.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done,
                    updatedAt: now,
                  )
                else
                  st
            ],
            updatedAt: now,
          )
        else
          t
    ];
  }

  void removeSubTask(String parentId, String subId) {
    final now = DateTime.now();
    state = [
      for (final t in state)
        if (t.id == parentId)
          t.copyWith(
            subTasks: [for (final st in t.subTasks) if (st.id != subId) st],
            updatedAt: now,
          )
        else
          t
    ];
  }
}

List<Task> _seedTasks() {
  final now = DateTime.now();
  return [
    Task(
      id: 't1',
      title: 'Buy milk',
      scale: TaskScale.short,
      due: TaskDue.on(DateTime(now.year, now.month, now.day)),
      priority: TaskPriority.normal,
      createdAt: now,
      updatedAt: now,
    ),
    Task(
      id: 't2',
      title: 'Finish tax filing',
      scale: TaskScale.long,
      due: TaskDue.month(year: now.year, month: now.month + 1),
      priority: TaskPriority.high,
      createdAt: now,
      updatedAt: now,
      subTasks: const [],
    ),
  ];
}