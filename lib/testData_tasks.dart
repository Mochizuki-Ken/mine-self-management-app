import '../models/app_models.dart';

DateTime _todayAt(int h, int m) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, h, m);
}

final List<Task> seedTasks = [
  Task(
    id: 't1',
    title: 'Pay credit card bill',
    description: 'Before 6pm',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    scale: TaskScale.short,
    due: TaskDue.at(_todayAt(18, 0)),
    priority: TaskPriority.high,
    status: TaskStatus.todo,
  ),
  Task(
    id: 't2',
    title: 'Reply to client email',
    description: '',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    scale: TaskScale.short,
    due: TaskDue.at(_todayAt(12, 0)),
    priority: TaskPriority.normal,
    status: TaskStatus.todo,
  ),
  Task(
    id: 't3',
    title: 'Buy milk',
    description: '2 bottles',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    scale: TaskScale.short,
    due: TaskDue.at(DateTime.now().add(const Duration(days: 2))),
    priority: TaskPriority.normal,
    status: TaskStatus.todo,
  ),
  Task(
    id: 't4',
    title: 'Workout',
    description: '30 min',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    scale: TaskScale.short,
    due: TaskDue.at(_todayAt(20, 0)),
    priority: TaskPriority.normal,
    status: TaskStatus.done,
  ),

  // Example long-term task (project) with sub-tasks
  Task(
    id: 't5',
    title: 'Plan summer trip',
    description: 'Book flights + hotels',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    scale: TaskScale.long,
    due: TaskDue.month(
      year: DateTime.now().year,
      month: DateTime.now().month + 2,
    ),
    priority: TaskPriority.normal,
    status: TaskStatus.todo,
    subTasks: [
      Task(
        id: 't5-1',
        title: 'Research flights',
        description: 'Compare prices, decide dates',
        status: TaskStatus.todo,
        priority: TaskPriority.normal,
        scale: TaskScale.short,
        due: const TaskDue.none(),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        linkedNoteIds: const ['note-flight-ideas'],
        linkedEventIds: const [],
      ),
      Task(
        id: 't5-2',
        title: 'Book hotels',
        description: 'Lock refundable options',
        status: TaskStatus.todo,
        priority: TaskPriority.normal,
        scale: TaskScale.short,
        due: const TaskDue.none(),
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        linkedNoteIds: const [],
        linkedEventIds: const ['event-hotel-hold'],
      ),
    ],
  ),
];