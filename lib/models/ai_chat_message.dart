// Simple message model used in chat view.
enum AiMessageRole { user, assistant, system }

class AiChatMessage {
  final AiMessageRole role;
  final String text;
  final DateTime at;

  AiChatMessage({
    required this.role,
    required this.text,
    DateTime? at,
  }) : at = at ?? DateTime.now();
}