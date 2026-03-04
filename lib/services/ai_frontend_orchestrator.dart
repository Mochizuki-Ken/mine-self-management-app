// AiFrontendOrchestrator — updated typedef for Reader to avoid referencing ProviderListenable.
// This avoids the "Undefined class 'ProviderListenable'" analyzer error in projects using
// different Riverpod import styles (legacy vs newer).
//
// Construct the orchestrator from a provider callback like:
//   final orchestrator = AiFrontendOrchestrator(aiService: service, ref: ref.read);
//
// where `ref.read` is passed as the `ref` parameter.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'app_actions.dart';
import '../providers/events_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/notes_provider.dart';

/// Reader function type used to read providers from inside the orchestrator.
///
/// We avoid depending on ProviderListenable so the typedef works regardless of whether
/// you import Riverpod via `flutter_riverpod` or the `legacy` entrypoint.
///
/// The caller should pass `ref.read` (or equivalent) when constructing the orchestrator.
typedef Reader = T Function<T>(dynamic provider);

class AiFrontendOrchestrator {
  AiFrontendOrchestrator({required this.aiService, required this.ref});

  final AiService aiService;
  final Reader ref;

  static const List<String> _whitelist = [
    'findFreeSlots',
    'getClosestEvent',
    'eventsInRange',
    'searchEventsByText',
    'searchTasksByText',
    'searchNotesByText',
    'suggestLinkedItems',
    'getConflictsForRange',
    'getEventById',
    'getTaskById',
    'getNoteById',
    'nextFreeSlotToday',
  ];

  /// Main flow:
  /// 1) call server with userInput
  /// 2) if server returns type: "call" and awaitResult==true -> run local helper (whitelisted)
  /// 3) post function_result back to server and return full response
  Future<Map<String, dynamic>> handle({
    required String userInput,
    List<Map<String, dynamic>>? conversation,
  }) async {
    // 1) initial call
    final initialResp = await aiService.chat(userInput: userInput, conversation: conversation);
    final initial = initialResp['initial'] as Map<String, dynamic>?;

    if (initial == null) return initialResp;

    final parsed = initial['parsed'] as Map<String, dynamic>?;
    if (parsed == null) return initialResp;

    if (parsed['type'] == 'call') {
      final name = parsed['name'] as String?;
      final args = (parsed['args'] as Map?)?.cast<String, dynamic>() ?? {};
      final awaitResult = parsed['awaitResult'] == null ? true : parsed['awaitResult'] as bool;

      if (awaitResult) {
        if (name == null || !_whitelist.contains(name)) {
          // Return the initial response; frontend may show a warning
          return initialResp;
        }

        // Run helper locally
        dynamic funcResult;
        try {
          funcResult = await _runLocalHelper(name, args);
        } catch (e) {
          final errMsg = {'type': 'msg', 'content': 'Local helper $name failed: ${e.toString()}'};
          return {
            'initial': initial,
            'followup_result': null,
            'final': {'raw': jsonEncode(errMsg), 'parsed': errMsg}
          };
        }

        final trimmed = _trimFunctionResult(funcResult);

        // 2) Send function_result back to server to let the model decide final output
        final followResp = await aiService.chat(userInput: userInput, conversation: conversation, functionResult: trimmed);
        return followResp;
      } else {
        // awaitResult == false: frontend can run helper locally and show result without round-trip
        return initialResp;
      }
    }

    // not a call: return initial response (msg or instruction)
    return initialResp;
  }

  Future<dynamic> _runLocalHelper(String name, Map<String, dynamic> args) async {
    // Read lists from providers using the Reader (ref)
    final events = ref<List<dynamic>>(eventsProvider);
    final tasks = ref<List<dynamic>>(tasksProvider);
    final notes = ref<List<dynamic>>(notesProvider);

    switch (name) {
      case 'findFreeSlots':
        {
          final start = DateTime.parse(args['start'] as String);
          final end = DateTime.parse(args['end'] as String);
          final minDur = (args['minDurationMinutes'] as int?) ?? 15;
          final appActions = AppActions();
          final free = appActions.findFreeSlots(events, start, end, minDuration: Duration(minutes: minDur));
          return appActions.freeSlotsToJson(free);
        }
      case 'getClosestEvent':
        {
          final now = args.containsKey('now') ? DateTime.parse(args['now'] as String) : DateTime.now();
          final query = args['query'] as String?;
          final ev = AppActions().getClosestEvent(events, now, query: query);
          if (ev == null) return null;
          return {
            'id': ev.id,
            'title': ev.title,
            'start': ev.startAt.toIso8601String(),
            'end': ev.endAt.toIso8601String(),
            'location': ev.location
          };
        }
      case 'eventsInRange':
        {
          final start = DateTime.parse(args['start'] as String);
          final end = DateTime.parse(args['end'] as String);
          final list = AppActions().eventsInRange(events, start, end);
          return list
              .map((e) => {
                    'id': e.id,
                    'title': e.title,
                    'start': e.startAt.toIso8601String(),
                    'end': e.endAt.toIso8601String(),
                    'location': e.location,
                  })
              .toList();
        }
      case 'searchEventsByText':
        {
          final query = args['query'] as String? ?? '';
          final limit = (args['limit'] as int?) ?? 6;
          final matches = AppActions().searchEventsByText(events, query, limit: limit);
          return matches
              .map((m) {
                final e = m['item'] as dynamic;
                return {
                  'id': e.id,
                  'title': e.title,
                  'start': e.startAt.toIso8601String(),
                  'end': e.endAt.toIso8601String(),
                  'score': m['score']
                };
              })
              .toList();
        }
      case 'searchTasksByText':
        {
          final query = args['query'] as String? ?? '';
          final limit = (args['limit'] as int?) ?? 6;
          final matches = AppActions().searchTasksByText(tasks, query, limit: limit);
          return matches
              .map((m) {
                final t = m['item'] as dynamic;
                return {
                  'id': t.id,
                  'title': t.title,
                  'due': t.due?.toString(),
                  'score': m['score']
                };
              })
              .toList();
        }
      case 'searchNotesByText':
        {
          final query = args['query'] as String? ?? '';
          final limit = (args['limit'] as int?) ?? 6;
          final matches = AppActions().searchNotesByText(notes, query, limit: limit);
          return matches
              .map((m) {
                final n = m['item'] as dynamic;
                final content = (n.content ?? '').toString();
                final snippet = content.length > 120 ? content.substring(0, 120) : content;
                return {
                  'id': n.id,
                  'title': n.title,
                  'snippet': snippet,
                  'score': m['score']
                };
              })
              .toList();
        }
      case 'suggestLinkedItems':
        {
          final title = args['title'] as String? ?? '';
          final description = args['description'] as String?;
          final start = args['start'] != null ? DateTime.parse(args['start'] as String) : null;
          final end = args['end'] != null ? DateTime.parse(args['end'] as String) : null;
          final maxSuggestions = (args['maxSuggestions'] as int?) ?? 3;
          final appActions = AppActions();
          final suggestions = appActions.suggestLinkedItems(
            title: title,
            description: description,
            start: start,
            end: end,
            tasks: tasks,
            notes: notes,
            events: events,
            maxSuggestions: maxSuggestions,
          );
          return appActions.suggestionsToJson(suggestions);
        }
      case 'getConflictsForRange':
        {
          final start = DateTime.parse(args['start'] as String);
          final end = DateTime.parse(args['end'] as String);
          final appActions = AppActions();
          final conflicts = appActions.eventsInRange(events, start, end);
          return conflicts
              .map((e) => {
                    'id': e.id,
                    'title': e.title,
                    'start': e.startAt.toIso8601String(),
                    'end': e.endAt.toIso8601String(),
                    'location': e.location
                  })
              .toList();
        }
      case 'getEventById':
        {
          final id = args['id'] as String;
          final e = events.firstWhere((ev) => ev.id == id, orElse: () => null);
          if (e == null) return null;
          return {
            'id': e.id,
            'title': e.title,
            'description': e.description,
            'start': e.startAt.toIso8601String(),
            'end': e.endAt.toIso8601String(),
            'location': e.location
          };
        }
      case 'nextFreeSlotToday':
        {
          final now = args.containsKey('now') ? DateTime.parse(args['now'] as String) : DateTime.now();
          final appActions = AppActions();
          final slot = appActions.nextFreeSlotTodayLocal(now: now, events: events);
          if (slot == null) return null;
          return {'start': slot.start.toIso8601String(), 'end': slot.end.toIso8601String()};
        }
      default:
        throw Exception('Unknown helper: $name');
    }
  }

  dynamic _trimFunctionResult(dynamic result) {
    try {
      if (result is List) {
        if (result.length > 10) return result.sublist(0, 10);
      }
      return result;
    } catch (_) {
      return result;
    }
  }
}