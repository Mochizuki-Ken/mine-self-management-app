import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:mine/providers/ai_chat_provider.dart';
import 'package:mine/providers/app_actions_provider.dart';
import 'package:mine/providers/events_provider.dart';
import 'package:mine/providers/notes_provider.dart';
import 'package:mine/providers/tasks_provider.dart';
import 'package:mine/providers/voice_assistant_provider.dart';

import '../models/ai_chat_message.dart' hide AiMessageRole, AiChatMessage;
import '../providers/ai_providers.dart';
import '../services/app_actions.dart';
import '../services/ai_frontend_orchestrator.dart';
import '../widgets/select_match_dialog.dart';
import '../widgets/confirm_action_dialog.dart';
import '../widgets/chat_composer_bar.dart';

/// AI chat view styled like WhatsApp:
/// - user messages aligned to the right in a colored bubble
/// - AI messages aligned to the left in a neutral bubble
/// - confirmation request/result handling preserved
/// - integrates with voice assistant provider (transcription auto-insert & optional auto-send)
class AiChatView extends ConsumerStatefulWidget {
  const AiChatView({super.key});

  @override
  ConsumerState<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends ConsumerState<AiChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isThinking = false;

  // Map confirmId -> pending instruction
  final Map<String, Map<String, dynamic>> _pendingConfirmations = {};

  // Guard so we register the provider listener only once
  bool _listenRegistered = false;

  // Auto-send transcription after listening stops
  final bool _autoSendOnTranscription = true;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    // store user message
    ref.read(aiChatProvider.notifier).addUserText(text);
    _scrollToEnd();

    setState(() => _isThinking = true);
    try {
      final orchestratorRaw = ref.read(aiOrchestratorProvider);

      late AiFrontendOrchestrator orchestratorInstance;
      if (orchestratorRaw is AsyncValue<AiFrontendOrchestrator>) {
        // await the future provider
        orchestratorInstance = await orchestratorRaw.when(
          data: (instance) async => instance,
          loading: () async {
            throw Exception('Orchestrator loading');
          },
          error: (err, st) => throw Exception('Failed to load orchestrator: $err'),
        );
      } else {
        orchestratorInstance = orchestratorRaw as AiFrontendOrchestrator;
      }

      final resp = await orchestratorInstance.handle(userInput: text);

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
        _scrollToEnd();
      } else if (type == 'instruction') {
        final content = parsed['content'] as Map<String, dynamic>? ?? {};
        await _enqueueInstructionConfirmation(content, text);
      } else if (type == 'call') {
        // unexpected if orchestrator handled calls, show raw
        ref.read(aiChatProvider.notifier).addAiText(jsonEncode(parsed));
        _scrollToEnd();
      } else {
        ref.read(aiChatProvider.notifier).addAiText(jsonEncode(parsed));
        _scrollToEnd();
      }
    } catch (e) {
      ref.read(aiChatProvider.notifier).addAiText('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isThinking = false);
    }
  }

  Future<void> _toggleRecording() async {
    final voice = ref.read(voiceAssistantProvider);
    final notifier = ref.read(voiceAssistantProvider.notifier);
    if (!voice.isListening) {
      await notifier.startListening();
      // optional UI cue in chat
      ref.read(aiChatProvider.notifier).addAiText('Listening...');
      _scrollToEnd();
    } else {
      await notifier.stopListening();
      // on stop, ref.listen callback (registered below) will handle transcription
    }
  }

  Future<void> _enqueueInstructionConfirmation(Map<String, dynamic> instructionContent, String originalUserInput) async {
    final instructionType = instructionContent['instructionType'] as String? ?? '';
    final resource = instructionContent['resource'] as String? ?? '';
    final payload = (instructionContent['payload'] as Map?)?.cast<String, dynamic>() ?? {};

    // Resolve missing id for edit/delete if necessary
    if ((instructionType == 'edit' || instructionType == 'delete') &&
        !(payload.containsKey('id') && (payload['id'] as String).isNotEmpty)) {
      final resolved = await _resolveEntityForPayload(resource, payload);
      if (resolved == null) {
        ref.read(aiChatProvider.notifier).addAiText('Operation cancelled — no matching item selected.');
        _scrollToEnd();
        return;
      }
      payload['id'] = resolved;
    }

    final title = '${instructionType.toUpperCase()} ${resource}';
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
      builder: (_) => ConfirmActionDialog(title: title, payloadPreview: payload, destructive: instructionType == 'delete'),
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
  }

  Future<String?> _resolveEntityForPayload(String resource, Map<String, dynamic> payload) async {
    final appActions = ref.read(appActionsProvider);
    final events = ref.read(eventsProvider);
    final tasks = ref.read(tasksProvider);
    final notes = ref.read(notesProvider);

    final query = (payload['query'] as String?) ?? (payload['title'] as String?) ?? '';

    if (resource == 'event') {
      List<Map<String, dynamic>> candidates = [];
      if (query.isNotEmpty) {
        final matches = appActions.searchEventsByText(events, query, limit: 6);
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
          final evs = appActions.eventsInRange(events, DateTime(date.year, date.month, date.day), DateTime(date.year, date.month, date.day, 23, 59));
          candidates = evs.map((e) {
            return {
              'id': e.id,
              'title': e.title,
              'subtitle': '${_fmt(e.startAt)} — ${_fmt(e.endAt)}'
            };
          }).toList();
        } catch (_) {}
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
      } else {
        ref.read(aiChatProvider.notifier).addAiText('Action executed (please implement specific handler).');
      }
    } catch (e) {
      ref.read(aiChatProvider.notifier).addAiText('Execution failed: ${e.toString()}');
    } finally {
      _pendingConfirmations.remove(confirmId);
      _scrollToEnd();
    }
  }

  String _fmt(dynamic dt) {
    try {
      if (dt is DateTime) return dt.toIso8601String();
      return dt?.toString() ?? '';
    } catch (_) {
      return '';
    }
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

  // Single message bubble widget (WhatsApp-like)
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

  String _timeString(DateTime dt) {
    try {
      final two = (int n) => n.toString().padLeft(2, '0');
      return '${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiChatProvider);
    final voiceState = ref.watch(voiceAssistantProvider);

    // Register a single ref.listen here (allowed inside build). Guard with _listenRegistered.
    if (!_listenRegistered) {
      _listenRegistered = true;
      ref.listen<VoiceAssistantState>(voiceAssistantProvider, (previous, next) {
        final prevListening = previous?.isListening ?? false;
        final nowListening = next.isListening;
        // when listening stops (true -> false), handle result
        if (prevListening && !nowListening) {
          final error = next.error;
          if (error != null && error.isNotEmpty) {
            if (!mounted) return;
            ref.read(aiChatProvider.notifier).addAiText('Voice error: $error');
            _scrollToEnd();
            return;
          }
          final text = (next.finalText.isNotEmpty ? next.finalText : next.partialText).trim();
          if (text.isEmpty) return;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _controller.text = text;
            _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
            if (_autoSendOnTranscription) _sendText();
          });
        }
      });
    }

    // scroll to end when messages change
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
                // thinking indicator centered
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final m = messages[idx];
              // Render bubble alignment like WhatsApp: user -> right, ai -> left
              return _messageBubble(m);
            },
          ),
        ),
        ChatComposerBar(
          controller: _controller,
          isRecording: voiceState.isListening,
          onTapMic: _toggleRecording,
          onSend: _sendText,
          hintText: 'Ask AI or type a command...',
          sendButtonColor: Theme.of(context).colorScheme.primary,
          micButtonColor: Colors.green,
          recordingButtonColor: Colors.redAccent,
        ),
      ],
    );
  }

  // helper that routes a message to the bubble builder (keeps older naming compatibility)

  Widget _messageBubbleWrapper(AiChatMessage m) => _messageBubble(m);
}