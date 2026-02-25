import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/ai_chat_provider.dart';
import '../providers/settings_provider.dart';

class AiChatView extends ConsumerWidget {
  const AiChatView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(aiChatProvider);
    final settings = ref.watch(settingsProvider);
    final tt = Theme.of(context).textTheme;

    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Start chatting with AI…',
          style: tt.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        final isUser = m.role == AiMessageRole.user;

        final userBubbleColor = Color(settings.chatUserBubbleColorValue);
        final aiBubbleColor = Colors.white.withValues(alpha: 0.08);

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _Bubble(
              isUser: isUser,
              background: isUser ? userBubbleColor : aiBubbleColor,
              child: _MessageBody(m: m),
            ),
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.isUser,
    required this.background,
    required this.child,
  });

  final bool isUser;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final border = isUser
        ? Colors.transparent
        : Colors.white.withValues(alpha: 0.12);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.25,
              ),
          child: child,
        ),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  const _MessageBody({required this.m});
  final AiChatMessage m;

  @override
  Widget build(BuildContext context) {
    switch (m.type) {
      case AiMessageType.text:
        return Text(m.text ?? '');

      case AiMessageType.imageBytes:
        return _ImageBytes(bytes: m.imageBytes);

      case AiMessageType.voiceBytes:
        return _VoiceBytes(bytes: m.voiceBytes);

      case AiMessageType.confirmRequest:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((m.title ?? '').isNotEmpty)
              Text(
                m.title!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
              ),
            if ((m.text ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(m.text!),
            ],
            const SizedBox(height: 8),
            Text(
              'Waiting for confirmation…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
            ),
          ],
        );

      case AiMessageType.confirmResult:
        final c = m.confirmed == true ? 'Confirmed' : 'Cancelled';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if ((m.text ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Input: ${m.text}'),
            ],
          ],
        );
    }
  }
}

class _ImageBytes extends StatelessWidget {
  const _ImageBytes({required this.bytes});
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return Text(
        '[Image]',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(bytes!, fit: BoxFit.cover),
    );
  }
}

class _VoiceBytes extends StatelessWidget {
  const _VoiceBytes({required this.bytes});
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_arrow, size: 20),
        const SizedBox(width: 8),
        Text(
          bytes == null ? '[Voice]' : 'Voice (${bytes!.length} bytes)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
        ),
      ],
    );
  }
}