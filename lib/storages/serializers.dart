import '../models/app_models.dart';
import '../models/recurrence_models.dart';
import '../providers/settings_provider.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// -------------------- EVENT --------------------

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
      'linkedTaskIds': e.linkedTaskIds,
      'linkedNoteIds': e.linkedNoteIds,
    };

Event eventFromJson(Map<String, dynamic> j) => Event(
      id: j['id'] as String,
      title: j['title'] as String,
      startAt: DateTime.parse(j['startAt'] as String),
      endAt: DateTime.parse(j['endAt'] as String),
      colorValue: j['colorValue'] as int? ?? 0xFF2A8CFF,
      busyStatus: BusyStatus.values.firstWhere(
        (x) => x.name == (j['busyStatus'] as String? ?? BusyStatus.busy.name),
      ),
      location: j['location'] as String?,
      description: j['description'] as String?,
      createdAt:
          j['createdAt'] == null ? null : DateTime.parse(j['createdAt'] as String),
      updatedAt:
          j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
      source: ItemSource.values.firstWhere(
        (x) => x.name == (j['source'] as String? ?? ItemSource.manual.name),
      ),
      linkedTaskIds: ((j['linkedTaskIds'] as List?) ?? const []).cast<String>(),
      linkedNoteIds: ((j['linkedNoteIds'] as List?) ?? const []).cast<String>(),
    );

// -------------------- TASK DUE --------------------

Map<String, dynamic> taskDueToJson(TaskDue due) => {
      'type': due.type.name,
      'at': due.at?.toIso8601String(),
      'on': due.on?.toIso8601String(),
      'year': due.year,
      'month': due.month,
    };

TaskDue taskDueFromJson(Map<String, dynamic> j) {
  final typeName = j['type'] as String? ?? TaskDueType.none.name;
  final type = TaskDueType.values.firstWhere((x) => x.name == typeName);

  switch (type) {
    case TaskDueType.none:
      return const TaskDue.none();
    case TaskDueType.at:
      return TaskDue.at(DateTime.parse(j['at'] as String));
    case TaskDueType.on:
      return TaskDue.on(_dateOnly(DateTime.parse(j['on'] as String)));
    case TaskDueType.month:
      return TaskDue.month(
        year: j['year'] as int,
        month: j['month'] as int,
      );
  }
}

// -------------------- TASK --------------------

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
      'linkedRecurringTemplateIds': t.linkedRecurringTemplateIds,
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
      status: TaskStatus.values.firstWhere(
        (x) => x.name == (j['status'] as String? ?? TaskStatus.todo.name),
      ),
      priority: TaskPriority.values.firstWhere(
        (x) => x.name == (j['priority'] as String? ?? TaskPriority.normal.name),
      ),
      scale: TaskScale.values.firstWhere(
        (x) => x.name == (j['scale'] as String? ?? TaskScale.short.name),
      ),
      due: taskDueFromJson(Map<String, dynamic>.from(j['due'] as Map)),
      subTasks: ((j['subTasks'] as List?) ?? const [])
          .map((e) => taskFromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      linkedNoteIds: ((j['linkedNoteIds'] as List?) ?? const []).cast<String>(),
      linkedEventIds: ((j['linkedEventIds'] as List?) ?? const []).cast<String>(),
      linkedRecurringTemplateIds:
          ((j['linkedRecurringTemplateIds'] as List?) ?? const []).cast<String>(),
      estimatedMinutes: j['estimatedMinutes'] as int?,
      tags: ((j['tags'] as List?) ?? const []).cast<String>(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      source: ItemSource.values.firstWhere(
        (x) => x.name == (j['source'] as String? ?? ItemSource.manual.name),
      ),
    );

// -------------------- NOTE ATTACHMENT --------------------

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
      type: AttachmentType.values.firstWhere(
        (x) => x.name == (j['type'] as String? ?? AttachmentType.file.name),
      ),
      uri: j['uri'] as String,
      name: j['name'] as String?,
      mimeType: j['mimeType'] as String?,
      sizeBytes: j['sizeBytes'] as int?,
      meta: (j['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt:
          j['createdAt'] == null ? null : DateTime.parse(j['createdAt'] as String),
    );

// -------------------- NOTE --------------------

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
      'linkedTaskIds': n.linkedTaskIds,
      'linkedEventIds': n.linkedEventIds,
      'linkedRecurringTemplateIds': n.linkedRecurringTemplateIds,
    };

Note noteFromJson(Map<String, dynamic> j) => Note(
      id: j['id'] as String,
      title: j['title'] as String,
      content: j['content'] as String,
      format: NoteFormat.values.firstWhere(
        (x) => x.name == (j['format'] as String? ?? NoteFormat.markdown.name),
      ),
      tags: ((j['tags'] as List?) ?? const []).cast<String>(),
      pinned: j['pinned'] as bool? ?? false,
      archived: j['archived'] as bool? ?? false,
      attachments: ((j['attachments'] as List?) ?? const [])
          .map((e) => noteAttachmentFromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt:
          j['createdAt'] == null ? null : DateTime.parse(j['createdAt'] as String),
      updatedAt:
          j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
      source: ItemSource.values.firstWhere(
        (x) => x.name == (j['source'] as String? ?? ItemSource.manual.name),
      ),
      linkedTaskIds: ((j['linkedTaskIds'] as List?) ?? const []).cast<String>(),
      linkedEventIds: ((j['linkedEventIds'] as List?) ?? const []).cast<String>(),
      linkedRecurringTemplateIds:
          ((j['linkedRecurringTemplateIds'] as List?) ?? const []).cast<String>(),
    );

// -------------------- SETTINGS --------------------

Map<String, dynamic> settingsToJson(SettingsState s) => {
      'displayLanguage': s.displayLanguage.name,
      'voiceLanguage': s.voiceLanguage.name,
      'chatActionButtonColorValue': s.chatActionButtonColorValue,
      'chatUserBubbleColorValue': s.chatUserBubbleColorValue,
      'aiConfirmButtonColorValue': s.aiConfirmButtonColorValue,
      'aiCancelButtonColorValue': s.aiCancelButtonColorValue,
    };

SettingsState settingsFromJson(Map<String, dynamic> j) => SettingsState(
      displayLanguage: AppLanguage.values.firstWhere(
        (x) =>
            x.name == (j['displayLanguage'] as String? ?? AppLanguage.english.name),
      ),
      voiceLanguage: AppLanguage.values.firstWhere(
        (x) => x.name == (j['voiceLanguage'] as String? ?? AppLanguage.english.name),
      ),
      chatActionButtonColorValue:
          j['chatActionButtonColorValue'] as int? ?? 0xFF2A8CFF,
      chatUserBubbleColorValue:
          j['chatUserBubbleColorValue'] as int? ?? 0xFF2A8CFF,
      aiConfirmButtonColorValue:
          j['aiConfirmButtonColorValue'] as int? ?? 0xFF2A8CFF,
      aiCancelButtonColorValue:
          j['aiCancelButtonColorValue'] as int? ?? 0xFF9E9E9E,
    );

// -------------------- RECURRENCE: RULE --------------------

Map<String, dynamic> recurrenceRuleToJson(RecurrenceRule r) => {
      'type': r.type.name,
      'intervalDays': r.intervalDays,
      'intervalWeeks': r.intervalWeeks,
      'weekdays': r.weekdays.toList(),
    };

RecurrenceRule recurrenceRuleFromJson(Map<String, dynamic> j) {
  final typeName = j['type'] as String? ?? RecurrenceType.daily.name;
  final type = RecurrenceType.values.firstWhere((x) => x.name == typeName);

  switch (type) {
    case RecurrenceType.daily:
      return RecurrenceRule.daily(intervalDays: (j['intervalDays'] as int?) ?? 1);

    case RecurrenceType.weekly:
      return RecurrenceRule.weekly(
        intervalWeeks: (j['intervalWeeks'] as int?) ?? 1,
        weekdays: ((j['weekdays'] as List?) ?? const []).cast<int>().toSet(),
      );
  }
}

// -------------------- RECURRENCE: TEMPLATE --------------------

Map<String, dynamic> recurringEventTemplateToJson(RecurringEventTemplate t) => {
      'id': t.id,
      'title': t.title,
      'startMinuteOfDay': t.startMinuteOfDay,
      'endMinuteOfDay': t.endMinuteOfDay,
      'colorValue': t.colorValue,
      'busyStatus': t.busyStatus.name,
      'location': t.location,
      'description': t.description,

      // NEW: links persisted on the series template
      'linkedTaskIds': t.linkedTaskIds,
      'linkedNoteIds': t.linkedNoteIds,

      'rule': recurrenceRuleToJson(t.rule),
      'startsOn': _dateOnly(t.startsOn).toIso8601String(),
      'endsOn': t.endsOn == null ? null : _dateOnly(t.endsOn!).toIso8601String(),
      'source': t.source.name,
      'createdAt': t.createdAt?.toIso8601String(),
      'updatedAt': t.updatedAt?.toIso8601String(),
    };

RecurringEventTemplate recurringEventTemplateFromJson(Map<String, dynamic> j) =>
    RecurringEventTemplate(
      id: j['id'] as String,
      title: j['title'] as String,
      startMinuteOfDay: j['startMinuteOfDay'] as int,
      endMinuteOfDay: j['endMinuteOfDay'] as int,
      colorValue: j['colorValue'] as int? ?? 0xFF2A8CFF,
      busyStatus: BusyStatus.values.firstWhere(
        (x) => x.name == (j['busyStatus'] as String? ?? BusyStatus.busy.name),
      ),
      location: j['location'] as String?,
      description: j['description'] as String?,
      linkedTaskIds: ((j['linkedTaskIds'] as List?) ?? const []).cast<String>(),
      linkedNoteIds: ((j['linkedNoteIds'] as List?) ?? const []).cast<String>(),
      rule: recurrenceRuleFromJson(Map<String, dynamic>.from(j['rule'] as Map)),
      startsOn: _dateOnly(DateTime.parse(j['startsOn'] as String)),
      endsOn:
          j['endsOn'] == null ? null : _dateOnly(DateTime.parse(j['endsOn'] as String)),
      source: ItemSource.values.firstWhere(
        (x) => x.name == (j['source'] as String? ?? ItemSource.manual.name),
      ),
      createdAt:
          j['createdAt'] == null ? null : DateTime.parse(j['createdAt'] as String),
      updatedAt:
          j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
    );

// -------------------- RECURRENCE: EXCEPTION --------------------

Map<String, dynamic> recurringExceptionToJson(RecurringEventException e) => {
      'id': e.id,
      'templateId': e.templateId,
      'date': _dateOnly(e.date).toIso8601String(),
      'type': e.type.name,
      'title': e.title,
      'startMinuteOfDay': e.startMinuteOfDay,
      'endMinuteOfDay': e.endMinuteOfDay,
      'location': e.location,
      'description': e.description,
      'colorValue': e.colorValue,
      'busyStatus': e.busyStatus?.name,
      'createdAt': e.createdAt?.toIso8601String(),
      'updatedAt': e.updatedAt?.toIso8601String(),
    };

RecurringEventException recurringExceptionFromJson(Map<String, dynamic> j) =>
    RecurringEventException(
      id: j['id'] as String,
      templateId: j['templateId'] as String,
      date: _dateOnly(DateTime.parse(j['date'] as String)),
      type: RecurringExceptionType.values.firstWhere(
        (x) => x.name == (j['type'] as String),
      ),
      title: j['title'] as String?,
      startMinuteOfDay: j['startMinuteOfDay'] as int?,
      endMinuteOfDay: j['endMinuteOfDay'] as int?,
      location: j['location'] as String?,
      description: j['description'] as String?,
      colorValue: j['colorValue'] as int?,
      busyStatus: j['busyStatus'] == null
          ? null
          : BusyStatus.values.firstWhere((x) => x.name == (j['busyStatus'] as String)),
      createdAt:
          j['createdAt'] == null ? null : DateTime.parse(j['createdAt'] as String),
      updatedAt:
          j['updatedAt'] == null ? null : DateTime.parse(j['updatedAt'] as String),
    );