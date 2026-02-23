import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../tools/app_lang.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final t = ref.watch(appLangProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.settings.title),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(t.settings.languageSection),
          const SizedBox(height: 10),

          _SettingTile(
            title: t.settings.displayLanguage,
            subtitle: appLanguageLabel(settings.displayLanguage),
            onTap: () async {
              final selected = await _pickLanguage(
                context,
                title: t.settings.displayLanguage,
                current: settings.displayLanguage,
              );
              if (selected != null) {
                ref.read(settingsProvider.notifier).setDisplayLanguage(selected);
              }
            },
          ),

          const SizedBox(height: 10),

          _SettingTile(
            title: t.settings.voiceLanguage,
            subtitle:
                '${appLanguageLabel(settings.voiceLanguage)}  (${appLanguageLocaleId(settings.voiceLanguage)})',
            onTap: () async {
              final selected = await _pickLanguage(
                context,
                title: t.settings.voiceLanguage,
                current: settings.voiceLanguage,
              );
              if (selected != null) {
                ref.read(settingsProvider.notifier).setVoiceLanguage(selected);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<AppLanguage?> _pickLanguage(
    BuildContext context, {
    required String title,
    required AppLanguage current,
  }) {
    return showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Divider(height: 1),
              for (final lang in AppLanguage.values)
                RadioListTile<AppLanguage>(
                  value: lang,
                  groupValue: current,
                  onChanged: (v) => Navigator.of(context).pop(v),
                  title: Text(appLanguageLabel(lang)),
                  subtitle: Text(
                    'Voice localeId: ${appLanguageLocaleId(lang)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.9),
          ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}