import 'package:flutter/foundation.dart';

import 'app_models.dart';

enum RecurrenceType { daily, weekly }

/// Weekday values match Dart DateTime.weekday:
/// 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
@immutable
class RecurrenceRule {
  const RecurrenceRule.daily({this.intervalDays = 1})
      : type = RecurrenceType.daily,
        intervalWeeks = 1,
        weekdays = const {};

  const RecurrenceRule.weekly({
    this.intervalWeeks = 1,
    required this.weekdays,
  })  : type = RecurrenceType.weekly,
        intervalDays = 1;

  final RecurrenceType type;

  final int intervalDays;
  final int intervalWeeks;
  final Set<int> weekdays;
}

@immutable
class RecurringEventTemplate {
  const RecurringEventTemplate({
    required this.id,
    required this.title,
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
    this.colorValue = 0xFF2A8CFF,
    this.busyStatus = BusyStatus.busy,
    this.location,
    this.description,

    // NEW: links (persisted on the series)
    this.linkedTaskIds = const [],
    this.linkedNoteIds = const [],

    required this.rule,
    required this.startsOn,
    this.endsOn,
    this.source = ItemSource.manual,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;

  final int startMinuteOfDay;
  final int endMinuteOfDay;

  final int colorValue;
  final BusyStatus busyStatus;

  final String? location;
  final String? description;

  // NEW
  final List<String> linkedTaskIds;
  final List<String> linkedNoteIds;

  final RecurrenceRule rule;

  final DateTime startsOn; // date-only
  final DateTime? endsOn; // date-only

  final ItemSource source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RecurringEventTemplate copyWith({
    String? title,
    int? startMinuteOfDay,
    int? endMinuteOfDay,
    int? colorValue,
    BusyStatus? busyStatus,
    String? location,
    String? description,

    // NEW
    List<String>? linkedTaskIds,
    List<String>? linkedNoteIds,

    RecurrenceRule? rule,
    DateTime? startsOn,
    DateTime? endsOn,
    ItemSource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringEventTemplate(
      id: id,
      title: title ?? this.title,
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      endMinuteOfDay: endMinuteOfDay ?? this.endMinuteOfDay,
      colorValue: colorValue ?? this.colorValue,
      busyStatus: busyStatus ?? this.busyStatus,
      location: location ?? this.location,
      description: description ?? this.description,
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
      linkedNoteIds: linkedNoteIds ?? this.linkedNoteIds,
      rule: rule ?? this.rule,
      startsOn: startsOn ?? this.startsOn,
      endsOn: endsOn ?? this.endsOn,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum RecurringExceptionType { skip, override }

/// Exception for ONE specific day:
/// - skip => delete only that occurrence
/// - override => change time/details for that day only
@immutable
class RecurringEventException {
  const RecurringEventException({
    required this.id,
    required this.templateId,
    required this.date, // date-only
    required this.type,

    // override fields (only meaningful when type == override)
    this.title,
    this.startMinuteOfDay,
    this.endMinuteOfDay,
    this.location,
    this.description,
    this.colorValue,
    this.busyStatus,

    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String templateId;
  final DateTime date;
  final RecurringExceptionType type;

  final String? title;
  final int? startMinuteOfDay;
  final int? endMinuteOfDay;
  final String? location;
  final String? description;
  final int? colorValue;
  final BusyStatus? busyStatus;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  RecurringEventException copyWith({
    RecurringExceptionType? type,
    String? title,
    int? startMinuteOfDay,
    int? endMinuteOfDay,
    String? location,
    String? description,
    int? colorValue,
    BusyStatus? busyStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringEventException(
      id: id,
      templateId: templateId,
      date: date,
      type: type ?? this.type,
      title: title ?? this.title,
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      endMinuteOfDay: endMinuteOfDay ?? this.endMinuteOfDay,
      location: location ?? this.location,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      busyStatus: busyStatus ?? this.busyStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}