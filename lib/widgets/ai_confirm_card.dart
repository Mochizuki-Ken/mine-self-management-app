import 'package:flutter/material.dart';

class AiConfirmResult {
  const AiConfirmResult({required this.confirmed, required this.input});
  final bool confirmed;
  final String input;
}

/// Shows a confirmation pop-up card with a text input and confirm/cancel buttons.
Future<AiConfirmResult?> showAiConfirmCard(
  BuildContext context, {
  required String title,
  required String message,
  String inputHint = 'Optional input…',
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool destructive = false,

  // NEW: allow custom colors
  Color? confirmButtonColor,
  Color? cancelButtonColor,
}) {
  final controller = TextEditingController();

  return showDialog<AiConfirmResult>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: inputHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            minLines: 1,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          style: cancelButtonColor == null
              ? null
              : TextButton.styleFrom(foregroundColor: cancelButtonColor),
          onPressed: () => Navigator.pop(
            context,
            AiConfirmResult(confirmed: false, input: controller.text.trim()),
          ),
          child: Text(cancelText),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive
                ? Colors.redAccent
                : (confirmButtonColor ?? Theme.of(context).colorScheme.primary),
          ),
          onPressed: () => Navigator.pop(
            context,
            AiConfirmResult(confirmed: true, input: controller.text.trim()),
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}