import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../models/app_models.dart';
import '../storages/local_store.dart';

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>(
  (ref) => TasksNotifier(),
);

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super(const []) {
    _init();
  }

  Future<void> _init() async {
    // No seed/test data anymore
    state = await LocalStore.loadTasks();
  }

  void _persist() => unawaited(LocalStore.saveTasks(state));

  void add(Task t) {
    state = [t, ...state];
    _persist();
  }

  void update(String id, Task updated) {
    state = [for (final x in state) if (x.id == id) updated else x];
    _persist();
  }

  void remove(String id) {
    state = [for (final x in state) if (x.id != id) x];
    _persist();
  }

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
          x,
    ];
    _persist();
  }

  // ----- Sub-task helpers for long-term/project tasks -----

  void addSubTask(String parentTaskId, Task subTask) {
    state = [
      for (final t in state)
        if (t.id == parentTaskId)
          t.copyWith(
            subTasks: [...t.subTasks, subTask],
            updatedAt: DateTime.now(),
          )
        else
          t
    ];
    _persist();
  }

  void updateSubTask(String parentTaskId, String subTaskId, Task updatedSubTask) {
    state = [
      for (final t in state)
        if (t.id == parentTaskId)
          t.copyWith(
            subTasks: [
              for (final st in t.subTasks) if (st.id == subTaskId) updatedSubTask else st
            ],
            updatedAt: DateTime.now(),
          )
        else
          t
    ];
    _persist();
  }

  void removeSubTask(String parentTaskId, String subTaskId) {
    state = [
      for (final t in state)
        if (t.id == parentTaskId)
          t.copyWith(
            subTasks: [for (final st in t.subTasks) if (st.id != subTaskId) st],
            updatedAt: DateTime.now(),
          )
        else
          t
    ];
    _persist();
  }

  void toggleSubTaskDone(String parentTaskId, String subTaskId) {
    final now = DateTime.now();
    state = [
      for (final t in state)
        if (t.id == parentTaskId)
          t.copyWith(
            subTasks: [
              for (final st in t.subTasks)
                if (st.id == subTaskId)
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
    _persist();
  }
}