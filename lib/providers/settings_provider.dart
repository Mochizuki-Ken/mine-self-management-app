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

  // NEW: one unified color for mic / send / recording (ARGB int)
  final int chatActionButtonColorValue;

  // Chat bubble colors
  final int chatUserBubbleColorValue;

  // AI confirm card button colors (ARGB ints) - for future AI confirmation flows
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

  factory SettingsState.initial() => const SettingsState(
        displayLanguage: AppLanguage.english,
        voiceLanguage: AppLanguage.english,

        // Defaults
        chatActionButtonColorValue: 0xFF2A8CFF, // blue
        chatUserBubbleColorValue: 0xFF2A8CFF, // blue (self message bubble)

        aiConfirmButtonColorValue: 0xFF2A8CFF, // blue
        aiCancelButtonColorValue: 0xFF9E9E9E, // grey
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
  SettingsNotifier() : super(SettingsState.initial());

  void setDisplayLanguage(AppLanguage lang) {
    state = state.copyWith(displayLanguage: lang);
  }

  void setVoiceLanguage(AppLanguage lang) {
    state = state.copyWith(voiceLanguage: lang);
  }

  // NEW: one unified color for mic/send/rec
  void setChatActionButtonColorValue(int argb) {
    state = state.copyWith(chatActionButtonColorValue: argb);
  }

  // Chat bubble colors
  void setChatUserBubbleColorValue(int argb) {
    state = state.copyWith(chatUserBubbleColorValue: argb);
  }

  // AI confirm card button colors
  void setAiConfirmButtonColorValue(int argb) {
    state = state.copyWith(aiConfirmButtonColorValue: argb);
  }

  void setAiCancelButtonColorValue(int argb) {
    state = state.copyWith(aiCancelButtonColorValue: argb);
  }
}