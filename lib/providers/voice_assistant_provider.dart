// Voice assistant provider (legacy Riverpod) using speech_to_text.
// This is the file you gave, slightly formatted and ready to use.
import 'package:flutter_riverpod/legacy.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

final voiceAssistantProvider =
    StateNotifierProvider<VoiceAssistantNotifier, VoiceAssistantState>(
  (ref) => VoiceAssistantNotifier(),
);

class VoiceAssistantState {
  final bool isAvailable;
  final bool isListening;
  final String partialText;
  final String finalText;
  final String? error;
  final String status;

  const VoiceAssistantState({
    required this.isAvailable,
    required this.isListening,
    required this.partialText,
    required this.finalText,
    required this.error,
    required this.status,
  });

  factory VoiceAssistantState.initial() => const VoiceAssistantState(
        isAvailable: false,
        isListening: false,
        partialText: '',
        finalText: '',
        error: null,
        status: '',
      );

  VoiceAssistantState copyWith({
    bool? isAvailable,
    bool? isListening,
    String? partialText,
    String? finalText,
    String? error,
    String? status,
  }) {
    return VoiceAssistantState(
      isAvailable: isAvailable ?? this.isAvailable,
      isListening: isListening ?? this.isListening,
      partialText: partialText ?? this.partialText,
      finalText: finalText ?? this.finalText,
      error: error,
      status: status ?? this.status,
    );
  }
}

class VoiceAssistantNotifier extends StateNotifier<VoiceAssistantState> {
  VoiceAssistantNotifier() : super(VoiceAssistantState.initial());

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _busy = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final ok = await _speech.initialize(
        onStatus: (s) => state = state.copyWith(status: s),
        onError: (e) => state = state.copyWith(
          error: e.errorMsg,
          isListening: false,
        ),
      );

      state = state.copyWith(
        isAvailable: ok,
        error: ok ? null : 'Speech recognition not available on this device',
      );
    } catch (e) {
      state = state.copyWith(
        isAvailable: false,
        error: 'Init failed: $e',
      );
    }
  }

  void clearTranscript() {
    state = state.copyWith(
      partialText: '',
      finalText: '',
      error: null,
    );
  }

  Future<void> startListening({
    String? localeId,
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
  }) async {
    if (_busy) return;
    _busy = true;

    try {
      await init();
      if (!state.isAvailable) return;
      if (_speech.isListening) return;

      state = state.copyWith(
        isListening: true,
        partialText: '',
        finalText: '',
        error: null,
      );

      await _speech.listen(
        localeId: localeId,
        listenMode: listenMode,
        partialResults: true,
        onResult: (result) {
          final words = result.recognizedWords;
          if (result.finalResult) {
            state = state.copyWith(partialText: words, finalText: words);
          } else {
            state = state.copyWith(partialText: words);
          }
        },
      );
    } catch (e) {
      state = state.copyWith(
        isListening: false,
        error: 'Start listening failed: $e',
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> stopListening() async {
    if (_busy) return;
    _busy = true;

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
      state = state.copyWith(
        isListening: false,
        finalText: state.finalText.isNotEmpty ? state.finalText : state.partialText,
      );
    } catch (e) {
      state = state.copyWith(isListening: false, error: 'Stop failed: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> cancelListening() async {
    if (_busy) return;
    _busy = true;

    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
      state = state.copyWith(isListening: false, partialText: '', finalText: '');
    } catch (e) {
      state = state.copyWith(isListening: false, error: 'Cancel failed: $e');
    } finally {
      _busy = false;
    }
  }
}