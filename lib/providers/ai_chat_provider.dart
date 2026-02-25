import 'dart:typed_data';
import 'package:flutter_riverpod/legacy.dart';

enum AiMessageRole { user, ai, system }

enum AiMessageType {
  text,
  imageBytes, // for images captured/downloaded later
  voiceBytes, // for recorded audio later
  confirmRequest,
  confirmResult,
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.type,
    required this.createdAt,
    this.text,
    this.imageBytes,
    this.voiceBytes,
    this.mimeType,
    this.title,
    this.confirmationId,
    this.confirmed,
  });

  final String id;
  final AiMessageRole role;
  final AiMessageType type;
  final DateTime createdAt;

  // payload
  final String? text;

  // media payload (kept simple for now; later you can store file paths)
  final Uint8List? imageBytes;
  final Uint8List? voiceBytes;
  final String? mimeType;

  // confirmation card meta
  final String? title;
  final String? confirmationId; // ties request <-> result
  final bool? confirmed;

  AiChatMessage copyWith({
    String? id,
    AiMessageRole? role,
    AiMessageType? type,
    DateTime? createdAt,
    String? text,
    Uint8List? imageBytes,
    Uint8List? voiceBytes,
    String? mimeType,
    String? title,
    String? confirmationId,
    bool? confirmed,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      text: text ?? this.text,
      imageBytes: imageBytes ?? this.imageBytes,
      voiceBytes: voiceBytes ?? this.voiceBytes,
      mimeType: mimeType ?? this.mimeType,
      title: title ?? this.title,
      confirmationId: confirmationId ?? this.confirmationId,
      confirmed: confirmed ?? this.confirmed,
    );
  }
}

final aiChatProvider =
    StateNotifierProvider<AiChatNotifier, List<AiChatMessage>>((ref) {
  return AiChatNotifier();
});

class AiChatNotifier extends StateNotifier<List<AiChatMessage>> {
  AiChatNotifier() : super(const []);

  void add(AiChatMessage m) => state = [...state, m];

  void addUserText(String text) {
    final now = DateTime.now();
    add(
      AiChatMessage(
        id: now.microsecondsSinceEpoch.toString(),
        role: AiMessageRole.user,
        type: AiMessageType.text,
        createdAt: now,
        text: text,
      ),
    );
  }

  void addAiText(String text) {
    final now = DateTime.now();
    add(
      AiChatMessage(
        id: now.microsecondsSinceEpoch.toString(),
        role: AiMessageRole.ai,
        type: AiMessageType.text,
        createdAt: now,
        text: text,
      ),
    );
  }

  /// Store that the AI asked for a confirmation (with optional input).
  String addConfirmRequest({
    required String title,
    required String prompt,
  }) {
    final now = DateTime.now();
    final confirmId = 'c_${now.microsecondsSinceEpoch}';

    add(
      AiChatMessage(
        id: now.microsecondsSinceEpoch.toString(),
        role: AiMessageRole.ai,
        type: AiMessageType.confirmRequest,
        createdAt: now,
        title: title,
        text: prompt,
        confirmationId: confirmId,
      ),
    );

    return confirmId;
  }

  void addConfirmResult({
    required String confirmationId,
    required bool confirmed,
    required String userInput,
  }) {
    final now = DateTime.now();
    add(
      AiChatMessage(
        id: now.microsecondsSinceEpoch.toString(),
        role: AiMessageRole.user,
        type: AiMessageType.confirmResult,
        createdAt: now,
        confirmationId: confirmationId,
        confirmed: confirmed,
        text: userInput,
      ),
    );
  }

  void clear() => state = const [];
}