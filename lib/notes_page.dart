import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../providers/voice_assistant_provider.dart';
import '../tools/app_lang.dart';
import 'note_edit_page.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  Future<void> _startVoice(WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final localeId = appLanguageLocaleId(settings.voiceLanguage);
    await ref.read(voiceAssistantProvider.notifier).startListening(localeId: localeId);
  }

  Future<void> _stopVoiceAndOpenEditor(BuildContext context, WidgetRef ref) async {
    await ref.read(voiceAssistantProvider.notifier).stopListening();
    final voice = ref.read(voiceAssistantProvider);

    final text = (voice.finalText.isNotEmpty ? voice.finalText : voice.partialText).trim();
    if (text.isEmpty) return;

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NoteEditPage(
            initialTitle: '',
            initialContent: text,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLangProvider);
    final voice = ref.watch(voiceAssistantProvider);
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      // Long-press anywhere to start/stop voice
      onLongPressStart: (_) async {
        if (!voice.isListening) {
          await _startVoice(ref);
        }
      },
      onLongPressEnd: (_) async {
        if (voice.isListening) {
          await _stopVoiceAndOpenEditor(context, ref);
        }
      },

      child: Scaffold(
        appBar: AppBar(
          title: Text(t.notes.title),
          backgroundColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            // Main content placeholder (replace with notes list later)
            Center(
              child: Text(
                'Notes list will be added later.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
              ),
            ),

            // Small transcript/status overlay while listening
            if (voice.isListening || voice.error != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 130,
                child: _TranscriptCard(
                  text: voice.error ??
                      (voice.partialText.isEmpty ? t.home.listening : voice.partialText),
                  isActive: voice.isListening,
                ),
              ),
          ],
        ),

        // Better-looking dual action buttons (bottom center)
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _BottomActionBar(
          isListening: voice.isListening,
          onTapVoice: () async {
            if (!voice.isListening) {
              await _startVoice(ref);
            } else {
              await _stopVoiceAndOpenEditor(context, ref);
            }
          },
          onTapAdd: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NoteEditPage()),
            );
          },
          primary: cs.primary,
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.isListening,
    required this.onTapVoice,
    required this.onTapAdd,
    required this.primary,
  });

  final bool isListening;
  final VoidCallback onTapVoice;
  final VoidCallback onTapAdd;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PillButton(
              onPressed: onTapVoice,
              background: isListening ? Colors.redAccent.withValues(alpha: 0.95) : primary,
              icon: isListening ? Icons.stop : Icons.mic,
              label: isListening ? 'Stop & Edit' : 'Voice',
            ),
            const SizedBox(width: 10),
            _PillButton(
              onPressed: onTapAdd,
              background: Colors.white.withValues(alpha: 0.10),
              borderColor: Colors.white.withValues(alpha: 0.12),
              icon: Icons.note_add,
              label: 'Add',
              labelStyle: t.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              iconColor: Colors.white.withValues(alpha: 0.92),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.onPressed,
    required this.background,
    required this.icon,
    required this.label,
    this.borderColor,
    this.iconColor,
    this.labelStyle,
  });

  final VoidCallback onPressed;
  final Color background;
  final Color? borderColor;
  final IconData icon;
  final String label;
  final Color? iconColor;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: borderColor == null ? null : Border.all(color: borderColor!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor ?? Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: labelStyle ??
                  t.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({
    required this.text,
    required this.isActive,
  });

  final String text;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isActive ? cs.primary : Colors.white).withValues(alpha: isActive ? 0.35 : 0.12),
        ),
      ),
      child: Text(
        text,
        style: tt.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.85),
          height: 1.25,
        ),
      ),
    );
  }
}