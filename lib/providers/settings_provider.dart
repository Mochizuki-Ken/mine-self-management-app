// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum AppLanguage {
  english,
  cantonese,
  chinese,
}

String appLanguageLabel(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.english:
      return 'English';
    case AppLanguage.cantonese:
      return 'Cantonese (粵語)';
    case AppLanguage.chinese:
      return 'Chinese (中文)';
  }
}

String appLanguageLocaleId(AppLanguage lang) {
  // This is for speech_to_text localeId mainly (voice language).
  // For display language you might later use Flutter localization instead.
  switch (lang) {
    case AppLanguage.english:
      return 'en_US';
    case AppLanguage.cantonese:
      return 'zh_HK';
    case AppLanguage.chinese:
      return 'zh_CN';
  }
}

class SettingsState {
  final AppLanguage displayLanguage;
  final AppLanguage voiceLanguage;

  const SettingsState({
    required this.displayLanguage,
    required this.voiceLanguage,
  });

  factory SettingsState.initial() => const SettingsState(
        displayLanguage: AppLanguage.english,
        voiceLanguage: AppLanguage.english,
      );

  SettingsState copyWith({
    AppLanguage? displayLanguage,
    AppLanguage? voiceLanguage,
  }) {
    return SettingsState(
      displayLanguage: displayLanguage ?? this.displayLanguage,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState.initial());

  void setDisplayLanguage(AppLanguage lang) {
    state = state.copyWith(displayLanguage: lang);
  }

  void setVoiceLanguage(AppLanguage lang) {
    state = state.copyWith(voiceLanguage: lang);
  }
}