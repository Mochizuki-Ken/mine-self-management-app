import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../storages/local_store.dart';

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

  // one unified color for mic / send / recording (ARGB int)
  final int chatActionButtonColorValue;

  // self message bubble color
  final int chatUserBubbleColorValue;

  // AI confirm card colors (future)
  final int aiConfirmButtonColorValue;
  final int aiCancelButtonColorValue;

  const SettingsState({
    required this.displayLanguage,
    required this.voiceLanguage,
    required this.chatActionButtonColorValue,
    required this.chatUserBubbleColorValue,
    required this.aiConfirmButtonColorValue,
    required this.aiCancelButtonColorValue,
  });

  factory SettingsState.defaults() => const SettingsState(
        displayLanguage: AppLanguage.english,
        voiceLanguage: AppLanguage.english,
        chatActionButtonColorValue: 0xFF2A8CFF,
        chatUserBubbleColorValue: 0xFF2A8CFF,
        aiConfirmButtonColorValue: 0xFF2A8CFF,
        aiCancelButtonColorValue: 0xFF9E9E9E,
      );

  SettingsState copyWith({
    AppLanguage? displayLanguage,
    AppLanguage? voiceLanguage,
    int? chatActionButtonColorValue,
    int? chatUserBubbleColorValue,
    int? aiConfirmButtonColorValue,
    int? aiCancelButtonColorValue,
  }) {
    return SettingsState(
      displayLanguage: displayLanguage ?? this.displayLanguage,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
      chatActionButtonColorValue:
          chatActionButtonColorValue ?? this.chatActionButtonColorValue,
      chatUserBubbleColorValue:
          chatUserBubbleColorValue ?? this.chatUserBubbleColorValue,
      aiConfirmButtonColorValue:
          aiConfirmButtonColorValue ?? this.aiConfirmButtonColorValue,
      aiCancelButtonColorValue:
          aiCancelButtonColorValue ?? this.aiCancelButtonColorValue,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState.defaults()) {
    _init();
  }

  Future<void> _init() async {
    // If no saved settings, keep defaults.
    final loaded = await LocalStore.loadSettings();
    if (loaded != null) state = loaded;
  }

  void _persist() => unawaited(LocalStore.saveSettings(state));

  void setDisplayLanguage(AppLanguage lang) {
    state = state.copyWith(displayLanguage: lang);
    _persist();
  }

  void setVoiceLanguage(AppLanguage lang) {
    state = state.copyWith(voiceLanguage: lang);
    _persist();
  }

  void setChatActionButtonColorValue(int argb) {
    state = state.copyWith(chatActionButtonColorValue: argb);
    _persist();
  }

  void setChatUserBubbleColorValue(int argb) {
    state = state.copyWith(chatUserBubbleColorValue: argb);
    _persist();
  }

  void setAiConfirmButtonColorValue(int argb) {
    state = state.copyWith(aiConfirmButtonColorValue: argb);
    _persist();
  }

  void setAiCancelButtonColorValue(int argb) {
    state = state.copyWith(aiCancelButtonColorValue: argb);
    _persist();
  }
}