import 'package:flutter/foundation.dart';

/// Shared source marker (optional)
enum ItemSource { manual, ai, imported, synced }

/// -------------------- EVENT --------------------

enum BusyStatus { busy, free }

@immutable
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.colorValue = 0xFF2A8CFF,
    this.busyStatus = BusyStatus.busy,
    this.location,
    this.description,

    /// links to tasks/notes
    this.linkedTaskIds = const [],
    this.linkedNoteIds = const [],

    this.createdAt,
    this.updatedAt,
    this.source = ItemSource.manual,
  });

  final String id;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final int colorValue;
  final BusyStatus busyStatus;
  final String? location;
  final String? description;

  final List<String> linkedTaskIds;
  final List<String> linkedNoteIds;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ItemSource source;

  Event copyWith({
    String? id,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    int? colorValue,
    BusyStatus? busyStatus,
    String? location,
    String? description,
    List<String>? linkedTaskIds,
    List<String>? linkedNoteIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    ItemSource? source,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      colorValue: colorValue ?? this.colorValue,
      busyStatus: busyStatus ?? this.busyStatus,
      location: location ?? this.location,
      description: description ?? this.description,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      linkedNoteIds: linkedNoteIds ?? this.linkedNoteIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }
}

/// -------------------- TASK --------------------

enum TaskStatus { todo, doing, done, blocked, cancelled }
enum TaskPriority { low, normal, high, urgent }
enum TaskScale { short, long }
enum TaskDueType { none, at, on, month }

@immutable
class TaskDue {
  const TaskDue._(this.type, {this.at, this.on, this.year, this.month});

  final TaskDueType type;
  final DateTime? at;
  final DateTime? on;
  final int? year;
  final int? month;

  const TaskDue.none() : this._(TaskDueType.none);
  const TaskDue.at(DateTime dueAt) : this._(TaskDueType.at, at: dueAt);
  const TaskDue.on(DateTime date) : this._(TaskDueType.on, on: date);
  const TaskDue.month({required int year, required int month})
      : this._(TaskDueType.month, year: year, month: month);
}

@immutable
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.normal,
    this.scale = TaskScale.short,
    this.due = const TaskDue.none(),
    this.subTasks = const [],
    this.linkedNoteIds = const [],
    this.linkedEventIds = const [],

    /// NEW: recurring series links (template ids)
    this.linkedRecurringTemplateIds = const [],

    this.estimatedMinutes,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.source = ItemSource.manual,
  });

  final String id;
  final String title;
  final String? description;

  final TaskStatus status;
  final TaskPriority priority;
  final TaskScale scale;
  final TaskDue due;

  final List<Task> subTasks;

  final List<String> linkedNoteIds;
  final List<String> linkedEventIds;

  /// NEW
  final List<String> linkedRecurringTemplateIds;

  final int? estimatedMinutes;
  final List<String> tags;

  final DateTime createdAt;
  final DateTime updatedAt;
  final ItemSource source;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    TaskScale? scale,
    TaskDue? due,
    List<Task>? subTasks,
    List<String>? linkedNoteIds,
    List<String>? linkedEventIds,

    /// NEW
    List<String>? linkedRecurringTemplateIds,

    int? estimatedMinutes,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    ItemSource? source,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      scale: scale ?? this.scale,
      due: due ?? this.due,
      subTasks: subTasks ?? this.subTasks,
      linkedNoteIds: linkedNoteIds ?? this.linkedNoteIds,
      linkedEventIds: linkedEventIds ?? this.linkedEventIds,
      linkedRecurringTemplateIds:
          linkedRecurringTemplateIds ?? this.linkedRecurringTemplateIds,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }
}

/// -------------------- NOTE --------------------

enum NoteFormat { plainText, markdown }
enum AttachmentType { image, audio, file, link }

@immutable
class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.type,
    required this.uri,
    this.name,
    this.mimeType,
    this.sizeBytes,
    this.meta = const {},
    this.createdAt,
  });

  final String id;
  final AttachmentType type;
  final String uri;
  final String? name;
  final String? mimeType;
  final int? sizeBytes;
  final Map<String, dynamic> meta;
  final DateTime? createdAt;

  NoteAttachment copyWith({
    String? id,
    AttachmentType? type,
    String? uri,
    String? name,
    String? mimeType,
    int? sizeBytes,
    Map<String, dynamic>? meta,
    DateTime? createdAt,
  }) {
    return NoteAttachment(
      id: id ?? this.id,
      type: type ?? this.type,
      uri: uri ?? this.uri,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      meta: meta ?? this.meta,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

@immutable
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    this.format = NoteFormat.markdown,
    this.tags = const [],
    this.pinned = false,
    this.archived = false,
    this.attachments = const [],
    this.linkedTaskIds = const [],
    this.linkedEventIds = const [],

    /// NEW: recurring series links (template ids)
    this.linkedRecurringTemplateIds = const [],

    this.createdAt,
    this.updatedAt,
    this.source = ItemSource.manual,
  });

  final String id;
  final String title;
  final String content;

  final NoteFormat format;

  final List<String> tags;
  final bool pinned;
  final bool archived;

  final List<NoteAttachment> attachments;

  final List<String> linkedTaskIds;
  final List<String> linkedEventIds;

  /// NEW
  final List<String> linkedRecurringTemplateIds;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ItemSource source;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    NoteFormat? format,
    List<String>? tags,
    bool? pinned,
    bool? archived,
    List<NoteAttachment>? attachments,
    List<String>? linkedTaskIds,
    List<String>? linkedEventIds,

    /// NEW
    List<String>? linkedRecurringTemplateIds,

    DateTime? createdAt,
    DateTime? updatedAt,
    ItemSource? source,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      format: format ?? this.format,
      tags: tags ?? this.tags,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      attachments: attachments ?? this.attachments,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      linkedEventIds: linkedEventIds ?? this.linkedEventIds,
      linkedRecurringTemplateIds:
          linkedRecurringTemplateIds ?? this.linkedRecurringTemplateIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }
}