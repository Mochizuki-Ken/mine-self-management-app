import '../models/app_models.dart';
import '../providers/settings_provider.dart';

// ---------- Event ----------
Map<String, dynamic> eventToJson(Event e) => {
      'id': e.id,
      'title': e.title,
      'startAt': e.startAt.toIso8601String(),
      'endAt': e.endAt.toIso8601String(),
      'colorValue': e.colorValue,
      'busyStatus': e.busyStatus.name,
      'location': e.location,
      'description': e.description,
      'createdAt': e.createdAt?.toIso8601String(),
      'updatedAt': e.updatedAt?.toIso8601String(),
      'source': e.source.name,
    };

Event eventFromJson(Map<String, dynamic> j) => Event(
      id: j['id'] as String,
      title: j['title'] as String,
      startAt: DateTime.parse(j['startAt'] as String),
      endAt: DateTime.parse(j['endAt'] as String),
      colorValue: j['colorValue'] as int? ?? 0xFF2A8CFF,
      busyStatus: BusyStatus.values.firstWhere((x) => x.name == j['busyStatus']),
      location: j['location'] as String?,
      description: j['description'] as String?,
      createdAt:
          (j['createdAt'] == null) ? null : DateTime.parse(j['createdAt'] as String),
      updatedAt:
          (j['updatedAt'] == null) ? null : DateTime.parse(j['updatedAt'] as String),
      source: ItemSource.values.firstWhere((x) => x.name == j['source']),
    );

// ---------- TaskDue ----------
Map<String, dynamic> taskDueToJson(TaskDue due) => {
      'type': due.type.name,
      'at': due.at?.toIso8601String(),
      'on': due.on?.toIso8601String(),
      'year': due.year,
      'month': due.month,
    };

TaskDue taskDueFromJson(Map<String, dynamic> j) {
  final type = TaskDueType.values.firstWhere((x) => x.name == j['type']);
  switch (type) {
    case TaskDueType.none:
      return const TaskDue.none();
    case TaskDueType.at:
      return TaskDue.at(DateTime.parse(j['at'] as String));
    case TaskDueType.on:
      return TaskDue.on(DateTime.parse(j['on'] as String));
    case TaskDueType.month:
      return TaskDue.month(year: j['year'] as int, month: j['month'] as int);
  }
}

// ---------- Task ----------
Map<String, dynamic> taskToJson(Task t) => {
      'id': t.id,
      'title': t.title,
      'description': t.description,
      'status': t.status.name,
      'priority': t.priority.name,
      'scale': t.scale.name,
      'due': taskDueToJson(t.due),
      'subTasks': t.subTasks.map(taskToJson).toList(),
      'linkedNoteIds': t.linkedNoteIds,
      'linkedEventIds': t.linkedEventIds,
      'estimatedMinutes': t.estimatedMinutes,
      'tags': t.tags,
      'createdAt': t.createdAt.toIso8601String(),
      'updatedAt': t.updatedAt.toIso8601String(),
      'source': t.source.name,
    };

Task taskFromJson(Map<String, dynamic> j) => Task(
      id: j['id'] as String,
      title: j['title'] as String,
      description: j['description'] as String?,
      status: TaskStatus.values.firstWhere((x) => x.name == j['status']),
      priority: TaskPriority.values.firstWhere((x) => x.name == j['priority']),
      scale: TaskScale.values.firstWhere((x) => x.name == j['scale']),
      due: taskDueFromJson(Map<String, dynamic>.from(j['due'] as Map)),
      subTasks: ((j['subTasks'] as List?) ?? const [])
          .map((e) => taskFromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      linkedNoteIds: ((j['linkedNoteIds'] as List?) ?? const []).cast<String>(),
      linkedEventIds: ((j['linkedEventIds'] as List?) ?? const []).cast<String>(),
      estimatedMinutes: j['estimatedMinutes'] as int?,
      tags: ((j['tags'] as List?) ?? const []).cast<String>(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      source: ItemSource.values.firstWhere((x) => x.name == j['source']),
    );

// ---------- NoteAttachment ----------
Map<String, dynamic> noteAttachmentToJson(NoteAttachment a) => {
      'id': a.id,
      'type': a.type.name,
      'uri': a.uri,
      'name': a.name,
      'mimeType': a.mimeType,
      'sizeBytes': a.sizeBytes,
      'meta': a.meta,
      'createdAt': a.createdAt?.toIso8601String(),
    };

NoteAttachment noteAttachmentFromJson(Map<String, dynamic> j) => NoteAttachment(
      id: j['id'] as String,
      type: AttachmentType.values.firstWhere((x) => x.name == j['type']),
      uri: j['uri'] as String,
      name: j['name'] as String?,
      mimeType: j['mimeType'] as String?,
      sizeBytes: j['sizeBytes'] as int?,
      meta: (j['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt:
          (j['createdAt'] == null) ? null : DateTime.parse(j['createdAt'] as String),
    );

// ---------- Note ----------
Map<String, dynamic> noteToJson(Note n) => {
      'id': n.id,
      'title': n.title,
      'content': n.content,
      'format': n.format.name,
      'tags': n.tags,
      'pinned': n.pinned,
      'archived': n.archived,
      'attachments': n.attachments.map(noteAttachmentToJson).toList(),
      'createdAt': n.createdAt?.toIso8601String(),
      'updatedAt': n.updatedAt?.toIso8601String(),
      'source': n.source.name,
    };

Note noteFromJson(Map<String, dynamic> j) => Note(
      id: j['id'] as String,
      title: j['title'] as String,
      content: j['content'] as String,
      format: NoteFormat.values.firstWhere((x) => x.name == j['format']),
      tags: ((j['tags'] as List?) ?? const []).cast<String>(),
      pinned: j['pinned'] as bool? ?? false,
      archived: j['archived'] as bool? ?? false,
      attachments: ((j['attachments'] as List?) ?? const [])
          .map((e) => noteAttachmentFromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt:
          (j['createdAt'] == null) ? null : DateTime.parse(j['createdAt'] as String),
      updatedAt:
          (j['updatedAt'] == null) ? null : DateTime.parse(j['updatedAt'] as String),
      source: ItemSource.values.firstWhere((x) => x.name == j['source']),
    );

// ---------- Settings ----------
Map<String, dynamic> settingsToJson(SettingsState s) => {
      'displayLanguage': s.displayLanguage.name,
      'voiceLanguage': s.voiceLanguage.name,
      'chatActionButtonColorValue': s.chatActionButtonColorValue,
      'chatUserBubbleColorValue': s.chatUserBubbleColorValue,
      'aiConfirmButtonColorValue': s.aiConfirmButtonColorValue,
      'aiCancelButtonColorValue': s.aiCancelButtonColorValue,
    };

SettingsState settingsFromJson(Map<String, dynamic> j) => SettingsState(
      displayLanguage:
          AppLanguage.values.firstWhere((x) => x.name == j['displayLanguage']),
      voiceLanguage:
          AppLanguage.values.firstWhere((x) => x.name == j['voiceLanguage']),
      chatActionButtonColorValue: j['chatActionButtonColorValue'] as int,
      chatUserBubbleColorValue: j['chatUserBubbleColorValue'] as int,
      aiConfirmButtonColorValue: j['aiConfirmButtonColorValue'] as int,
      aiCancelButtonColorValue: j['aiCancelButtonColorValue'] as int,
    );