import 'package:flutter/material.dart';

class ChatComposerBar extends StatefulWidget {
  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.isRecording,
    required this.onTapMic,
    required this.onSend,
    this.hintText = 'Message…',

    // Colors
    this.sendButtonColor,
    this.micButtonColor,
    this.recordingButtonColor,
  });

  final TextEditingController controller;
  final bool isRecording;
  final VoidCallback onTapMic;
  final VoidCallback onSend;
  final String hintText;

  final Color? sendButtonColor;
  final Color? micButtonColor;
  final Color? recordingButtonColor;

  @override
  State<ChatComposerBar> createState() => _ChatComposerBarState();
}

class _ChatComposerBarState extends State<ChatComposerBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasText = widget.controller.text.trim().isNotEmpty;

    // While recording: always show STOP (never Send), so user can stop recording even if text exists.
    final bool showStop = widget.isRecording;
    final bool showSend = !showStop && hasText;

    final icon = showStop
        ? Icons.stop
        : (showSend ? Icons.send : Icons.mic);

    final Color bg = showStop
        ? (widget.recordingButtonColor ?? Colors.redAccent)
        : (showSend
            ? (widget.sendButtonColor ?? cs.primary)
            : (widget.micButtonColor ?? cs.primary));

    final String tooltip = showStop
        ? 'Stop recording'
        : (showSend ? 'Send' : 'Record voice');

    final VoidCallback onTap = showStop
        ? widget.onTapMic
        : (showSend ? widget.onSend : widget.onTapMic);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (widget.controller.text.trim().isNotEmpty && !widget.isRecording) {
                      widget.onSend();
                    }
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.25,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CircleActionButton(
              tooltip: tooltip,
              background: bg,
              icon: icon,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.tooltip,
    required this.background,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final Color background;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}