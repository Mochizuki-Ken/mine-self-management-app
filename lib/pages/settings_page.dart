import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
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

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}