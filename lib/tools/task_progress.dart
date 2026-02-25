import '../models/app_models.dart';

class TaskProgress {
  const TaskProgress({required this.total, required this.done});

  final int total;
  final int done;

  double get ratio => total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
}

TaskProgress computeTaskProgress(Task projectTask) {
  final subs = projectTask.subTasks;
  final total = subs.length;
  final done = subs.where((t) => t.status == TaskStatus.done).length;
  return TaskProgress(total: total, done: done);
}