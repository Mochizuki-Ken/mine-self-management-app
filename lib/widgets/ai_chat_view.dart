import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:mine/providers/ai_chat_provider.dart';
import 'package:mine/providers/app_actions_provider.dart';
import 'package:mine/providers/events_provider.dart';
import 'package:mine/providers/notes_provider.dart';
import 'package:mine/providers/tasks_provider.dart';
import 'package:mine/providers/recurring_events_provider.dart';
import 'package:mine/providers/voice_assistant_provider.dart';

// import '../models/ai_chat_message.dart' hide AiMessageRole, AiChatMessage;
import '../models/recurrence_models.dart';
import '../providers/ai_providers.dart';
// import '../services/app_actions.dart';
// import '../services/ai_frontend_orchestrator.dart';
import '../widgets/select_match_dialog.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/chat_composer_bar.dart';

class AiChatView extends ConsumerStatefulWidget {
  const AiChatView({super.key});

  @override
  ConsumerState<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends ConsumerState<AiChatView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _chatCtrl = TextEditingController();

  bool _isThinking = false;
  bool _autoSendVoice = false; // show transcript first; user taps send
  bool _wasRecording = false;

  final Map<String, Map<String, dynamic>> _pendingConfirmations = {};
  Map<String, dynamic>? _pendingClarification;
  int _clarifyRetry = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Chat send
  // ---------------------------------------------------------------------------
  Future<void> _sendText({String? injectedText, bool showUserBubble = true}) async {
    final text = (injectedText ?? _chatCtrl.text).trim();
    if (text.isEmpty) return;
    if (injectedText == null) _chatCtrl.clear();

    if (_pendingClarification != null) {
      final lower = text.toLowerCase();
      const cancels = ['cancel', 'stop', 'never mind', 'nevermind', 'quit', 'another topic', 'different topic'];
      if (cancels.any((c) => lower.contains(c))) {
        _pendingClarification = null;
        _clarifyRetry = 0;
        ref.read(aiChatProvider.notifier).addAiText('Okay, cancelled that request.');
        _scrollToEnd();
        return;
      }

      final pending = _pendingClarification!;
      final updatedPayload = Map<String, dynamic>.from(pending['payload'] as Map<String, dynamic>);
      updatedPayload['query'] = text;
      updatedPayload.putIfAbsent('title', () => text);
      updatedPayload.putIfAbsent('description', () => text);
      _pendingClarification = null;

      await _enqueueInstructionConfirmation(
        {
          'instructionType': pending['instructionType'],
          'resource': pending['resource'],
          'payload': updatedPayload,
        },
        pending['originalUserInput'] as String? ?? text,
      );
      return;
    }

    if (showUserBubble) {
      ref.read(aiChatProvider.notifier).addUserText(text);
    }
    _scrollToEnd();

    setState(() => _isThinking = true);
    try {
      final orchestratorInstance = await ref.read(aiOrchestratorProvider.future);
      final conversationCtx =
          showUserBubble ? _conversationHistory() : [..._conversationHistory(), {'role': 'user', 'content': text}];

      final resp = await orchestratorInstance.handle(
        userInput: text,
        conversation: conversationCtx,
      );

      Map<String, dynamic>? parsed;
      if (resp.containsKey('final') && resp['final'] != null) {
        parsed = (resp['final'] as Map<String, dynamic>)['parsed'] as Map<String, dynamic>?;
      } else {
        parsed = (resp['initial'] as Map<String, dynamic>)['parsed'] as Map<String, dynamic>?;
      }

      if (parsed == null) {
        ref.read(aiChatProvider.notifier).addAiText('Sorry, could not parse assistant response.');
        _scrollToEnd();
        return;
      }

      final type = parsed['type'] as String? ?? 'msg';
      if (type == 'msg') {
        final content = parsed['content']?.toString() ?? '';
        ref.read(aiChatProvider.notifier).addAiText(content);
      } else if (type == 'instruction') {
        final content = parsed['content'] as Map<String, dynamic>? ?? {};
        await _enqueueInstructionConfirmation(content, text);
      } else if (type == 'call') {
        // ignore tool-call display
      } else {
        // ignore other types
      }
    } catch (e) {
      ref.read(aiChatProvider.notifier).addAiText('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isThinking = false);
      _scrollToEnd();
    }
  }

  // ---------------------------------------------------------------------------
  // Instruction helpers
  // ---------------------------------------------------------------------------
  Future<String?> _chooseEventKind(String initial) async {
    String selection = initial;
    return showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Choose what to create'),
          content: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'event',
                    groupValue: selection,
                    title: const Text('Single event'),
                    onChanged: (v) => setState(() => selection = v!),
                  ),
                  RadioListTile<String>(
                    value: 'recurring_event',
                    groupValue: selection,
                    title: const Text('Recurring event series'),
                    onChanged: (v) => setState(() => selection = v!),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(selection),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  bool _looksRecurring(Map<String, dynamic> payload) {
    if (payload.containsKey('recurrence')) return true;
    if (payload.containsKey('startsOn')) return true;
    if (payload.containsKey('startDate')) return true;
    if (payload.containsKey('rule')) return true;
    if (payload.containsKey('weekdays')) return true;
    return false;
  }

  bool _userHintRecurring(String text) {
    final lower = text.toLowerCase();
    const hints = [
      'every day',
      'everyday',
      'daily',
      'each day',
      'every week',
      'each week',
      'weekly',
      'biweekly',
      'fortnight',
      'weekdays',
      'weekday',
      'workdays',
      'workday',
      'repeat',
      'repeats',
      'repeating',
      'recurring',
      'standing',
      'regularly'
    ];
    for (final h in hints) {
      if (lower.contains(h)) return true;
    }
    const days = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday','mon','tue','wed','thu','fri','sat','sun'];
    for (final d in days) {
      if (lower.contains('every $d') || lower.contains('each $d')) return true;
    }
    return false;
  }

  void _normalizeEventTimes(Map<String, dynamic> payload) {
    DateTime toLocalDT(String s) => DateTime.parse(s).toLocal();
    for (final key in ['start', 'end', 'startAt', 'endAt']) {
      if (payload[key] is String) {
        final dt = toLocalDT(payload[key] as String);
        payload[key] = DateTime(
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        ).toIso8601String();
      }
    }
  }

  Future<void> _enqueueInstructionConfirmation(Map<String, dynamic> instructionContent, String originalUserInput) async {
    final instructionType = instructionContent['instructionType'] as String? ?? '';
    String resource = instructionContent['resource'] as String? ?? '';
    final payload = (instructionContent['payload'] as Map?)?.cast<String, dynamic>() ?? {};

    final userHintRecurring = _userHintRecurring(originalUserInput);

    // Ask user to choose event vs recurring_event for adds
    if (instructionType == 'add' && (resource == 'event' || resource == 'recurring_event')) {
      final initial = (_looksRecurring(payload) || userHintRecurring) ? 'recurring_event' : resource;
      final chosen = await _chooseEventKind(initial);
      if (chosen == null) {
        ref.read(aiChatProvider.notifier).addAiText('Action cancelled.');
        _scrollToEnd();
        return;
      }
      resource = chosen;
    } else if (resource == 'event' && (_looksRecurring(payload) || userHintRecurring)) {
      // existing heuristic for non-add flows
      resource = 'recurring_event';
    }

    // Normalize times to local before validation/execution
    if (resource == 'event' || resource == 'recurring_event') {
      _normalizeEventTimes(payload);
    }

    if ((instructionType == 'edit' || instructionType == 'delete') &&
        !(payload.containsKey('id') && (payload['id'] as String).isNotEmpty)) {
      final resolved = await _resolveEntityForPayload(resource, payload);
      if (resolved == null) {
        if (_clarifyRetry >= 1) {
          _pendingClarification = null;
          _clarifyRetry = 0;
          ref.read(aiChatProvider.notifier).addAiText(
            'I still can’t find it. Please rephrase with the title and exact date/time, or type "cancel".',
          );
          _scrollToEnd();
          return;
        }
        final hints = resource == 'event' ? _upcomingEventHints() : const <String>[];
        _pendingClarification = {
          'instructionType': instructionType,
          'resource': resource,
          'payload': payload,
          'originalUserInput': originalUserInput,
        };
        _clarifyRetry += 1;
        ref.read(aiChatProvider.notifier).addAiText(
          'I need more details to continue with that action. Please specify the exact title and date/time, or type "cancel".'
          '${hints.isNotEmpty ? ' Examples: ${hints.join(' · ')}' : ''}',
        );
        _scrollToEnd();
        return;
      }
      payload['id'] = resolved;
      _clarifyRetry = 0;
    }

    if (instructionType == 'add') {
      final missing = <String>[];
      if ((payload['title'] as String? ?? '').isEmpty) missing.add('title');
      if (resource == 'event' || resource == 'recurring_event') {
        final hasStart = payload['start'] != null ||
            payload['startTime'] != null ||
            payload['startAt'] != null;
        final hasEnd = payload['end'] != null ||
            payload['endTime'] != null ||
            payload['endAt'] != null ||
            payload['durationMinutes'] != null;
        if (!hasStart || !hasEnd) missing.add('start/end or durationMinutes');
        if (resource == 'recurring_event' &&
            payload['startsOn'] == null &&
            payload['startDate'] == null) {
          missing.add('startsOn date');
        }
      }
      if (missing.isNotEmpty) {
        _pendingClarification = {
          'instructionType': instructionType,
          'resource': resource,
          'payload': payload,
          'originalUserInput': originalUserInput,
        };
        _clarifyRetry = 0;
        ref.read(aiChatProvider.notifier).addAiText(
          'I need more details: ${missing.join(", ")}.',
        );
        _scrollToEnd();
        return;
      }
    }

    final title = '${instructionType.toUpperCase()} ${_resourceLabel(resource)}';
    final prompt = const JsonEncoder.withIndent('  ').convert(payload);

    final confirmId = ref.read(aiChatProvider.notifier).addConfirmRequest(title: title, prompt: prompt);
    _pendingConfirmations[confirmId] = {
      'instructionType': instructionType,
      'resource': resource,
      'payload': payload,
      'originalUserInput': originalUserInput,
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmActionDialog(
        title: title,
        payloadPreview: payload,
        destructive: instructionType == 'delete',
      ),
    );

    ref.read(aiChatProvider.notifier).addConfirmResult(
      confirmationId: confirmId,
      confirmed: confirmed == true,
      userInput: confirmed == true ? 'Confirmed' : 'Cancelled',
    );
    _scrollToEnd();

    if (confirmed == true) {
      await _executePendingConfirmation(confirmId);
    } else {
      _pendingConfirmations.remove(confirmId);
      ref.read(aiChatProvider.notifier).addAiText('Action cancelled.');
      _scrollToEnd();
    }
    _clarifyRetry = 0;
  }

  Future<String?> _resolveEntityForPayload(String resource, Map<String, dynamic> payload) async {
    final appActions = ref.read(appActionsProvider);
    final events = ref.read(eventsProvider);
    final tasks = ref.read(tasksProvider);
    final notes = ref.read(notesProvider);
    final recurring = ref.read(recurringEventsProvider);

    final query = (payload['query'] as String?) ?? (payload['title'] as String?) ?? '';

    if (resource == 'event') {
      List<Map<String, dynamic>> candidates = [];
      if (query.isNotEmpty) {
        final matches = appActions.searchEventsByText(events, query, limit: 6);
        if (matches.length == 1) {
          return matches.first['item'].id as String;
        }
        candidates = matches.map((m) {
          final e = m['item'];
          return {
            'id': e.id,
            'title': e.title,
            'subtitle': '${_fmt(e.startAt)} — ${_fmt(e.endAt)}'
          };
        }).toList();
      } else if (payload.containsKey('date')) {
        try {
          final date = DateTime.parse(payload['date'] as String);
          final evs = appActions.eventsInRange(
            events,
            DateTime(date.year, date.month, date.day),
            DateTime(date.year, date.month, date.day, 23, 59),
          );
          if (evs.length == 1) return evs.first.id;
          candidates = evs.map((e) {
            return {
              'id': e.id,
              'title': e.title,
              'subtitle': '${_fmt(e.startAt)} — ${_fmt(e.endAt)}'
            };
          }).toList();
        } catch (_) {}
      } else {
        final now = DateTime.now();
        final upcoming = events.where((e) => e.endAt.isAfter(now)).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final limited = upcoming.take(5);
        candidates = limited
            .map((e) => {
                  'id': e.id,
                  'title': e.title,
                  'subtitle': '${_fmt(e.startAt)} — ${_fmt(e.endAt)}'
                })
            .toList();
      }

      if (candidates.isEmpty) return null;
      final sel = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (_) => SelectMatchDialog(items: candidates),
      );
      if (sel == null) return null;
      return sel['id'] as String?;
    }

    if (resource == 'task') {
      final matches = appActions.searchTasksByText(tasks, query, limit: 6);
      if (matches.length == 1) return (matches.first['item'] as dynamic).id as String;
      final candidates = matches.map((m) {
        final t = m['item'];
        return {'id': t.id, 'title': t.title, 'subtitle': t.due?.toString() ?? ''};
      }).toList();
      if (candidates.isEmpty) return null;
      final sel = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (_) => SelectMatchDialog(items: candidates),
      );
      return sel == null ? null : sel['id'] as String?;
    }

    if (resource == 'note') {
      final matches = appActions.searchNotesByText(notes, query, limit: 6);
      if (matches.length == 1) return (matches.first['item'] as dynamic).id as String;
      final candidates = matches.map((m) {
        final n = m['item'];
        final snippet = (n.content ?? '').toString();
        return {'id': n.id, 'title': n.title, 'subtitle': snippet.length > 100 ? '${snippet.substring(0, 100)}...' : snippet};
      }).toList();
      if (candidates.isEmpty) return null;
      final sel = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (_) => SelectMatchDialog(items: candidates),
      );
      return sel == null ? null : sel['id'] as String?;
    }

    if (resource == 'recurring_event') {
      if (recurring.length == 1) return recurring.first.id;

      List<Map<String, dynamic>> candidates = [];
      if (query.isNotEmpty) {
        final matches = appActions.searchRecurringEventsByText(recurring, query, limit: 12);
        if (matches.length == 1) return (matches.first['item'] as dynamic).id as String;
        candidates = matches.map((m) {
          final t = m['item'] as RecurringEventTemplate;
          return {
            'id': t.id,
            'title': t.title,
            'subtitle': 'starts ${_fmt(t.startsOn)} • rule ${t.rule.type == RecurrenceType.daily ? 'daily' : 'weekly'}'
          };
        }).toList();
      }

      if (candidates.isEmpty) {
        final sorted = List.of(recurring)..sort((a, b) => a.startsOn.compareTo(b.startsOn));
        final limited = sorted.take(10);
        candidates = limited
            .map((t) => {
                  'id': t.id,
                  'title': t.title,
                  'subtitle': 'starts ${_fmt(t.startsOn)} • rule ${t.rule.type == RecurrenceType.daily ? 'daily' : 'weekly'}'
                })
            .toList();
      }

      if (candidates.isEmpty) return null;
      final sel = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (_) => SelectMatchDialog(items: candidates),
      );
      return sel == null ? null : sel['id'] as String?;
    }

    return null;
  }

  Future<void> _executePendingConfirmation(String confirmId) async {
    final pending = _pendingConfirmations[confirmId];
    if (pending == null) return;

    final instructionType = pending['instructionType'] as String;
    final resource = pending['resource'] as String;
    final payload = (pending['payload'] as Map).cast<String, dynamic>();

    final appActions = ref.read(appActionsProvider);

    try {
      if (instructionType == 'add' && resource == 'event') {
        await appActions.createEventFromPayload(payload, ref);
        ref.read(aiChatProvider.notifier).addAiText('Event created.');
      } else if (instructionType == 'edit' && resource == 'event') {
        await appActions.editEventFromPayload(payload, ref);
        ref.read(aiChatProvider.notifier).addAiText('Event updated.');
      } else if (instructionType == 'delete' && resource == 'event') {
        final id = payload['id'] as String;
        await appActions.deleteEventById(id, ref);
        ref.read(aiChatProvider.notifier).addAiText('Event deleted.');
      } else if (instructionType == 'add' && resource == 'task') {
        await appActions.createTaskFromPayload(payload, ref);
        ref.read(aiChatProvider.notifier).addAiText('Task created.');
      } else if (instructionType == 'edit' && resource == 'task') {
        await appActions.editTaskFromPayload(payload, ref);
        ref.read(aiChatProvider.notifier).addAiText('Task updated.');
      } else if (instructionType == 'delete' && resource == 'task') {
        final id = payload['id'] as String;
        await appActions.deleteTaskById(id, ref);
        ref.read(aiChatProvider.notifier).addAiText('Task deleted.');
      } else if (instructionType == 'add' && resource == 'note') {
        await appActions.createNoteFromPayload(payload, ref);
        ref.read(aiChatProvider.notifier).addAiText('Note created.');
      } else if (instructionType == 'edit' && resource == 'note') {
        await appActions.editNoteFromPayload(payload, ref);
        ref.read(aiChatProvider.notifier).addAiText('Note updated.');
      } else if (instructionType == 'delete' && resource == 'note') {
        final id = payload['id'] as String;
        await appActions.deleteNoteById(id, ref);
        ref.read(aiChatProvider.notifier).addAiText('Note deleted.');
      } else if (instructionType == 'add' && resource == 'recurring_event') {
        await appActions.createRecurringEventFromPayload(payload, ref);
        ref.read(aiChatProvider.notifier).addAiText('Recurring event created.');
      } else if (instructionType == 'edit' && resource == 'recurring_event') {
        await appActions.editRecurringEventFromPayload(payload, ref);
        ref.read(aiChatProvider.notifier).addAiText('Recurring event updated.');
      } else if (instructionType == 'delete' && resource == 'recurring_event') {
        final id = payload['id'] as String;
        await appActions.deleteRecurringEventById(id, ref);
        ref.read(aiChatProvider.notifier).addAiText('Recurring event deleted.');
      } else {
        ref.read(aiChatProvider.notifier).addAiText('Action executed (please implement specific handler).');
      }
    } catch (e) {
      ref.read(aiChatProvider.notifier).addAiText('Execution failed: ${e.toString()}');
    } finally {
      _pendingConfirmations.remove(confirmId);
      _clarifyRetry = 0;
      _scrollToEnd();
    }
  }

  // ---------------------------------------------------------------------------
  // Conversation helpers
  // ---------------------------------------------------------------------------
  List<Map<String, String>> _conversationHistory({int limit = 14}) {
    final msgs = ref.read(aiChatProvider);
    final selected = msgs.length > limit ? msgs.sublist(msgs.length - limit) : msgs;
    return selected
        .where((m) => (m.text ?? '').isNotEmpty)
        .map((m) {
          final role = m.role == AiMessageRole.user ? 'user' : 'assistant';
          return {'role': role, 'content': m.text!};
        })
        .toList();
  }

  String _fmt(dynamic dt) {
    try {
      if (dt is DateTime) return dt.toIso8601String();
      return dt?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _resourceLabel(String resource) {
    switch (resource) {
      case 'recurring_event':
        return 'Recurring event series';
      case 'event':
        return 'Event';
      case 'task':
        return 'Task';
      case 'note':
        return 'Note';
      default:
        return resource;
    }
  }

  String _timeString(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  List<String> _upcomingEventHints() {
    final events = List.of(ref.read(eventsProvider));
    events.sort((a, b) => a.startAt.compareTo(b.startAt));
    final now = DateTime.now();
    final hints = <String>[];
    for (final e in events) {
      if (e.endAt.isBefore(now)) continue;
      final d = e.startAt.toLocal();
      hints.add('${e.title} on ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          'at ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}');
      if (hints.length >= 3) break;
    }
    return hints;
  }

  // ---------------------------------------------------------------------------
  // Voice handling (kept inside AiChatView)
  // ---------------------------------------------------------------------------
  void _updateInput(String text) {
    _chatCtrl.text = text;
    _chatCtrl.selection = TextSelection.collapsed(offset: _chatCtrl.text.length);
  }

  Future<void> _toggleMicTap() async {
    final voice = ref.read(voiceAssistantProvider);
    final notifier = ref.read(voiceAssistantProvider.notifier);
    if (!voice.isListening) {
      notifier.clearTranscript();
      _updateInput('');       // clear input when starting recording
      _wasRecording = true;
      await notifier.startListening();
    } else {
      await notifier.stopListening();
    }
  }

  void _syncVoiceToInput(VoiceAssistantState voice) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (voice.isListening && voice.partialText.isNotEmpty) {
        _wasRecording = true;
        if (_chatCtrl.text != voice.partialText) {
          _updateInput(voice.partialText);
        }
        return;
      }
      if (!voice.isListening && _wasRecording) {
        _wasRecording = false;
        final text = (voice.finalText.isNotEmpty ? voice.finalText : voice.partialText).trim();
        if (text.isNotEmpty) {
          _updateInput(text);
          if (_autoSendVoice) {
            await _sendText();
          }
        }
        ref.read(voiceAssistantProvider.notifier).clearTranscript();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiChatProvider);
    final voice = ref.watch(voiceAssistantProvider);
    _syncVoiceToInput(voice);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: messages.length + (_isThinking ? 1 : 0),
            itemBuilder: (context, idx) {
              if (idx >= messages.length) {
                return const _TypingBubble();
              }
              final m = messages[idx];
              return _messageBubble(m);
            },
          ),
        ),
        ChatComposerBar(
          controller: _chatCtrl,
          isRecording: voice.isListening,
          onTapMic: _toggleMicTap,
          onSend: () => _sendText(),
          hintText: voice.isListening ? 'Recording…' : 'Ask AI or type a command...',
          micButtonColor: voice.isListening ? Colors.redAccent : Colors.green,
          recordingButtonColor: Colors.redAccent,
          sendButtonColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _messageBubble(AiChatMessage m) {
    final isUser = m.role == AiMessageRole.user;
    final bubbleColor = isUser ? Colors.green[600] : Colors.grey[850];
    final textColor = isUser ? Colors.white : Colors.white;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isUser ? 12 : 4),
      topRight: Radius.circular(isUser ? 4 : 12),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
    );

    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            margin: EdgeInsets.only(
              left: isUser ? 48 : 6,
              right: isUser ? 6 : 48,
              top: 6,
              bottom: 6,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
            ),
            child: Column(
              crossAxisAlignment: align,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.title != null && m.title!.isNotEmpty && !isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      m.title!,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white70),
                    ),
                  ),
                if ((m.text ?? '').isNotEmpty)
                  Text(
                    m.text!,
                    style: TextStyle(color: textColor),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeString(m.createdAt),
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    if (m.type == AiMessageType.confirmRequest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotOpacity(int index, double t) {
    final phase = (t + index / 3) % 1.0;
    if (phase < 0.4) return phase / 0.4;
    if (phase < 0.7) return 1.0;
    return (1 - phase) / 0.3;
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = Colors.grey[850];
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(left: 6, right: 48, top: 6, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final t = _controller.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Opacity(
                        opacity: _dotOpacity(i, t).clamp(0.0, 1.0),
                        child: const _Dot(),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.white70,
        shape: BoxShape.circle,
      ),
    );
  }
}