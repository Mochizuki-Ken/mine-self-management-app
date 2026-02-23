import 'package:flutter_riverpod/legacy.dart';

import '../models/app_models.dart';
import '../testData_tasks.dart';

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>(
  (ref) => TasksNotifier(),
);

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super(List.of(seedTasks));

  void add(Task t) => state = [t, ...state];

  void update(String id, Task updated) {
    state = [for (final x in state) if (x.id == id) updated else x];
  }

  void remove(String id) {
    state = [for (final x in state) if (x.id != id) x];
  }

  void toggleDone(String id) {
    state = [
      for (final x in state)
        if (x.id == id)
          x.copyWith(
            status: x.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done,
            updatedAt: DateTime.now(),
          )
        else
          x,
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