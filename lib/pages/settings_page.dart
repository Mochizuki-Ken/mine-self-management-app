import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/events_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/recurring_event_exceptions_provider.dart';
import '../providers/recurring_events_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../storages/local_store.dart';
import '../tools/app_lang.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget _colorSwatchButton({
    required String label,
    required int colorValue,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final c = Color(colorValue);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.10),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appLangProvider);
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    const presets = <String, int>{
      'Blue': 0xFF2A8CFF,
      'Green': 0xFF00C853,
      'Purple': 0xFF7C4DFF,
      'Orange': 0xFFFF6D00,
      'Pink': 0xFFD81B60,
      'Gray': 0xFF9E9E9E,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(t.common.settings),
      ),
      body: ListView(
        children: [
          _sectionTitle(context, 'Language'),
          ListTile(
            title: const Text('Display language'),
            subtitle: Text(appLanguageLabel(s.displayLanguage)),
            trailing: DropdownButton<AppLanguage>(
              value: s.displayLanguage,
              onChanged: (v) {
                if (v == null) return;
                n.setDisplayLanguage(v);
              },
              items: AppLanguage.values
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(appLanguageLabel(lang)),
                      ))
                  .toList(),
            ),
          ),
          ListTile(
            title: const Text('Voice language'),
            subtitle: Text(appLanguageLabel(s.voiceLanguage)),
            trailing: DropdownButton<AppLanguage>(
              value: s.voiceLanguage,
              onChanged: (v) {
                if (v == null) return;
                n.setVoiceLanguage(v);
              },
              items: AppLanguage.values
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(appLanguageLabel(lang)),
                      ))
                  .toList(),
            ),
          ),

          _sectionTitle(context, 'Chat colors'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Action button color (Mic / Send / Recording)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presets.entries.map((e) {
                return _colorSwatchButton(
                  label: e.key,
                  colorValue: e.value,
                  selected: s.chatActionButtonColorValue == e.value,
                  onTap: () => n.setChatActionButtonColorValue(e.value),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Self message bubble color',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presets.entries.map((e) {
                return _colorSwatchButton(
                  label: e.key,
                  colorValue: e.value,
                  selected: s.chatUserBubbleColorValue == e.value,
                  onTap: () => n.setChatUserBubbleColorValue(e.value),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 18),
          _sectionTitle(context, 'AI confirmation colors (future)'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'These are used only when AI needs confirmation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presets.entries.map((e) {
                return _colorSwatchButton(
                  label: 'Confirm ${e.key}',
                  colorValue: e.value,
                  selected: s.aiConfirmButtonColorValue == e.value,
                  onTap: () => n.setAiConfirmButtonColorValue(e.value),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presets.entries.map((e) {
                return _colorSwatchButton(
                  label: 'Cancel ${e.key}',
                  colorValue: e.value,
                  selected: s.aiCancelButtonColorValue == e.value,
                  onTap: () => n.setAiCancelButtonColorValue(e.value),
                );
              }).toList(),
            ),
          ),

          // -------------------- CLEAR STORAGE --------------------
          _sectionTitle(context, 'Storage'),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Clear tasks'),
            subtitle: const Text('Delete all tasks stored on this device'),
            onTap: () async {
              final ok = await _confirm(
                context,
                title: 'Clear all tasks?',
                message: 'This cannot be undone.',
                confirmText: 'Clear tasks',
              );
              if (!ok) return;

              ref.read(tasksProvider.notifier).clearAll();
              await LocalStore.clearTasks();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Clear notes'),
            subtitle: const Text('Delete all notes stored on this device'),
            onTap: () async {
              final ok = await _confirm(
                context,
                title: 'Clear all notes?',
                message: 'This cannot be undone.',
                confirmText: 'Clear notes',
              );
              if (!ok) return;

              ref.read(notesProvider.notifier).clearAll();
              await LocalStore.clearNotes();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Clear events'),
            subtitle: const Text('Delete all one-off events stored on this device'),
            onTap: () async {
              final ok = await _confirm(
                context,
                title: 'Clear all events?',
                message: 'This cannot be undone.',
                confirmText: 'Clear events',
              );
              if (!ok) return;

              ref.read(eventsProvider.notifier).clearAll();
              await LocalStore.clearEvents();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Clear recurring events'),
            subtitle: const Text('Delete all recurring series + occurrences overrides'),
            onTap: () async {
              final ok = await _confirm(
                context,
                title: 'Clear recurring events?',
                message: 'This will delete all recurring series and exceptions.',
                confirmText: 'Clear recurring',
              );
              if (!ok) return;

              ref.read(recurringEventsProvider.notifier).clearAll();
              ref.read(recurringEventExceptionsProvider.notifier).clearAll();
              await LocalStore.clearRecurringEvents();
              await LocalStore.clearRecurringEventExceptions();
            },
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.warning_amber, color: Colors.redAccent),
            title: const Text('Clear ALL data'),
            subtitle: const Text('Tasks, notes, events, recurring events, settings'),
            onTap: () async {
              final ok = await _confirm(
                context,
                title: 'Clear ALL data?',
                message:
                    'This will delete everything stored on this device. This cannot be undone.',
                confirmText: 'Clear all',
              );
              if (!ok) return;

              ref.read(tasksProvider.notifier).clearAll();
              ref.read(notesProvider.notifier).clearAll();
              ref.read(eventsProvider.notifier).clearAll();
              ref.read(recurringEventsProvider.notifier).clearAll();
              ref.read(recurringEventExceptionsProvider.notifier).clearAll();

              await LocalStore.clearAll();
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}