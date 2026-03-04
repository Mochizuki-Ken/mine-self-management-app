import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_page.dart';

import '../models/app_models.dart';

import '../providers/ai_chat_provider.dart';
import '../providers/events_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/voice_assistant_provider.dart';
import '../tools/app_lang.dart';

// Use the self-contained chat view that includes the composer
import '../widgets/ai_chat_view.dart';
import '../widgets/ai_confirm_card.dart';

/// HomePage = Home Voice page UI (1 upcoming event).
/// SwipeHostPage owns the PageViews and navigation.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    required this.onTapGoLeftTop,
    required this.onTapGoLeftBottom,
    required this.onTapGoRightTop,
    required this.onTapGoRightMiddle,
    required this.onTapGoRightBottom,
  });

  // Kept for future voice-driven navigation
  final VoidCallback onTapGoLeftTop;
  final VoidCallback onTapGoLeftBottom;
  final VoidCallback onTapGoRightTop;
  final VoidCallback onTapGoRightMiddle;
  final VoidCallback onTapGoRightBottom;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  Offset? _pressPoint;

  late final TextEditingController _chatCtrl = TextEditingController();

  bool _isThinking = false;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulse.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  String get _timeStr => '${_two(_now.hour)}:${_two(_now.minute)}';

  String get _dateStr {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wd = weekdays[_now.weekday - 1];
    return '${_now.year}-${_two(_now.month)}-${_two(_now.day)} $wd';
  }

  String _formatDurationShort(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _sortDue(TaskDue due) {
    switch (due.type) {
      case TaskDueType.none:
        return DateTime.fromMillisecondsSinceEpoch(0);
      case TaskDueType.at:
        return due.at!;
      case TaskDueType.on:
        return _dateOnly(due.on!).add(const Duration(hours: 23, minutes: 59));
      case TaskDueType.month:
        final y = due.year!;
        final m = due.month!;
        final firstNextMonth =
            (m == 12) ? DateTime(y + 1, 1, 1) : DateTime(y, m + 1, 1);
        return firstNextMonth.subtract(const Duration(minutes: 1));
    }
  }

  String _fmtDue(TaskDue due) {
    String two(int n) => n.toString().padLeft(2, '0');
    switch (due.type) {
      case TaskDueType.none:
        return '';
      case TaskDueType.at:
        final d = due.at!;
        return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
      case TaskDueType.on:
        final d = due.on!;
        return '${d.year}-${two(d.month)}-${two(d.day)}';
      case TaskDueType.month:
        return '${due.year}-${two(due.month!)}';
    }
  }

  ({DateTime start, DateTime end}) _computeNextFreeSlotToday({
    required DateTime now,
    required List<Event> events,
  }) {
    final todayStart = _dateOnly(now);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final todayEvents = events
        .where((e) => e.startAt.isBefore(todayEnd) && e.endAt.isAfter(todayStart))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    if (todayEvents.isEmpty) {
      return (start: now, end: todayEnd);
    }

    if (now.isBefore(todayEvents.first.startAt)) {
      return (start: now, end: todayEvents.first.startAt);
    }

    DateTime cursor = now;
    for (var i = 0; i < todayEvents.length; i++) {
      final e = todayEvents[i];

      if (cursor.isBefore(e.endAt)) cursor = e.endAt;

      final nextStart =
          (i + 1 < todayEvents.length) ? todayEvents[i + 1].startAt : todayEnd;

      if (cursor.isBefore(nextStart)) {
        return (start: cursor, end: nextStart);
      }
    }

    return (start: now, end: todayEnd);
  }

  bool _isWorkingNow({
    required DateTime now,
    required List<Event> events,
  }) {
    return events.any((e) => e.startAt.isBefore(now) && e.endAt.isAfter(now));
  }

  // NEW: "closest" event = current ongoing (ending soonest) OR next upcoming (starting soonest)
  bool _isOngoing(Event e) => !_now.isBefore(e.startAt) && _now.isBefore(e.endAt);

  Event? _closestEvent(List<Event> events) {
    final ongoing = events.where(_isOngoing).toList()
      ..sort((a, b) => a.endAt.compareTo(b.endAt));
    if (ongoing.isNotEmpty) return ongoing.first;

    final upcoming = events.where((e) => _now.isBefore(e.startAt)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (upcoming.isNotEmpty) return upcoming.first;

    return null;
  }

  ({String text, Color color}) _eventCounter(Event e) {
    // Upcoming => starts in ...
    if (_now.isBefore(e.startAt)) {
      final mins = e.startAt.difference(_now).inMinutes;
      final txt = mins <= 0 ? 'Starts now' : 'Starts in ${mins}m';
      return (text: txt, color: const Color(0xFF4DD0E1)); // light cyan
    }

    // Ongoing => ends in ...
    if (_now.isBefore(e.endAt)) {
      final mins = e.endAt.difference(_now).inMinutes;
      final txt = mins <= 0 ? 'Ends now' : 'Ends in ${mins}m';
      return (text: txt, color: const Color(0xFFFFB74D)); // light orange
    }

    // Ended
    final minsAgo = _now.difference(e.endAt).inMinutes;
    return (text: '${minsAgo}m ago', color: Colors.white.withValues(alpha: 0.45));
  }

  Future<void> _onLongPressStart(LongPressStartDetails d) async {
    setState(() => _pressPoint = d.localPosition);

    final settings = ref.read(settingsProvider);
    final localeId = appLanguageLocaleId(settings.voiceLanguage);

    await ref.read(voiceAssistantProvider.notifier).startListening(
          localeId: localeId,
        );
  }

  Future<void> _onLongPressEnd(LongPressEndDetails d) async {
    await ref.read(voiceAssistantProvider.notifier).stopListening();
  }

  Future<void> _toggleRecordingToInput() async {
    final voice = ref.read(voiceAssistantProvider);
    if (!voice.isListening) {
      final settings = ref.read(settingsProvider);
      final localeId = appLanguageLocaleId(settings.voiceLanguage);
      await ref
          .read(voiceAssistantProvider.notifier)
          .startListening(localeId: localeId);
      return;
    }

    await ref.read(voiceAssistantProvider.notifier).stopListening();
    final v = ref.read(voiceAssistantProvider);
    final text = (v.finalText.isNotEmpty ? v.finalText : v.partialText).trim();
    if (text.isEmpty) return;

    _chatCtrl.text = text;
    _chatCtrl.selection = TextSelection.collapsed(offset: _chatCtrl.text.length);
  }

  /// FUTURE: call this ONLY when AI decides it needs confirmation.
  Future<AiConfirmResult?> requestAiConfirmation(
    BuildContext context, {
    required String title,
    required String prompt,
    String inputHint = 'Optional input…',
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool destructive = false,
  }) async {
    final settings = ref.read(settingsProvider);

    final confirmId = ref.read(aiChatProvider.notifier).addConfirmRequest(
          title: title,
          prompt: prompt,
        );

    final result = await showAiConfirmCard(
      context,
      title: title,
      message: prompt,
      inputHint: inputHint,
      confirmText: confirmText,
      cancelText: cancelText,
      destructive: destructive,
      confirmButtonColor: Color(settings.aiConfirmButtonColorValue),
      cancelButtonColor: Color(settings.aiCancelButtonColorValue),
    );

    if (!mounted) return null;

    if (result != null) {
      ref.read(aiChatProvider.notifier).addConfirmResult(
            confirmationId: confirmId,
            confirmed: result.confirmed,
            userInput: result.input,
          );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLangProvider);
    final cs = Theme.of(context).colorScheme;
    final voice = ref.watch(voiceAssistantProvider);
    final settings = ref.watch(settingsProvider);

    final events = ref.watch(eventsProvider);
    final tasks = ref.watch(tasksProvider);

    final now = _now;

    final isWorking = _isWorkingNow(now: now, events: events);

    final closest = _closestEvent(events);

    final nextEventTime = closest == null ? '--:--' : _hm(closest.startAt);
    final nextEventTitle = closest == null ? t.home.none : closest.title;

    final nextEventCounter = closest == null
        ? (text: '', color: const Color(0xFFFFC857))
        : _eventCounter(closest);

    final nextEventBorderColor = closest == null
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFF69F0AE).withValues(alpha: 0.55);
    final nextEventBackgroundColor = closest == null
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFF69F0AE).withValues(alpha: 0.10);

    final nextFreeSlot = _computeNextFreeSlotToday(now: now, events: events);
    final nextFreeStartText = _hm(nextFreeSlot.start);
    final nextFreeDurationText =
        _formatDurationShort(nextFreeSlot.end.difference(nextFreeSlot.start));

    final transcriptText = voice.isListening
        ? (voice.partialText.isEmpty ? t.home.listening : voice.partialText)
        : (voice.finalText.isEmpty ? '' : voice.finalText);

    final upcomingTasks = tasks.where((t) => t.status != TaskStatus.done).toList()
      ..sort((a, b) => _sortDue(a.due).compareTo(_sortDue(b.due)));
    final nextTask = upcomingTasks.isEmpty ? null : upcomingTasks.first;

    final nextTaskTitle = nextTask == null ? t.home.none : nextTask.title;
    final nextTaskDue = (nextTask == null) ? '' : _fmtDue(nextTask.due);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              children: [
                _TopStatusArea(
                  timeText: _timeStr,
                  dateText: _dateStr,
                  isWorking: isWorking,
                  nextEventTime: nextEventTime,
                  nextEventTitle: nextEventTitle,
                  nextEventCountdown: nextEventCounter.text,
                  countdownColor: nextEventCounter.color,
                  nextEventBorderColor: nextEventBorderColor,
                  nextEventBackgroundColor: nextEventBackgroundColor,
                  nextFreeStartText: nextFreeStartText,
                  nextFreeDurationText: nextFreeDurationText,
                  t: t,
                  onTapNextEvent: widget.onTapGoLeftBottom,
                  nextTaskTitle: nextTaskTitle,
                  nextTaskDue: nextTaskDue,
                  onTapNextTask: widget.onTapGoRightMiddle,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.02),
                                  Colors.black.withValues(alpha: 0.10),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Use the self-contained chat view (it includes the composer)
                        Positioned.fill(
                          child: Consumer(
                            builder: (context, ref, _) {
                              ref.watch(aiChatProvider);
                              return const AiChatView();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Composer removed from HomePage — AiChatViewWithComposer provides it.
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              tooltip: t.common.settings,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
              icon: const Icon(Icons.settings),
            ),
          ),
          if (voice.isListening) ...[
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.18)),
            ),
            if (_pressPoint != null)
              Positioned(
                left: _pressPoint!.dx - 28,
                top: _pressPoint!.dy - 28,
                child: _RippleDot(color: cs.primary),
              ),
          ],
          if (transcriptText.isNotEmpty || voice.isListening || voice.error != null)
            Positioned(
              left: 18,
              right: 18,
              bottom: 86,
              child: _TranscriptCard(
                text: voice.error ?? transcriptText,
                isActive: voice.isListening,
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Helper widgets (same functionality as your original file) ----

class _TopStatusArea extends StatelessWidget {
  const _TopStatusArea({
    required this.timeText,
    required this.dateText,
    required this.isWorking,
    required this.nextEventTime,
    required this.nextEventTitle,
    required this.nextEventCountdown,
    required this.countdownColor,
    required this.nextEventBorderColor,
    required this.nextEventBackgroundColor,
    required this.nextFreeStartText,
    required this.nextFreeDurationText,
    required this.t,
    required this.onTapNextEvent,
    required this.nextTaskTitle,
    required this.nextTaskDue,
    required this.onTapNextTask,
  });

  final String timeText;
  final String dateText;

  final bool isWorking;

  final String nextEventTime;
  final String nextEventTitle;
  final String nextEventCountdown;
  final Color countdownColor;

  // NEW
  final Color nextEventBorderColor;
  final Color nextEventBackgroundColor;

  final String nextFreeStartText;
  final String nextFreeDurationText;

  final AppLang t;

  final VoidCallback onTapNextEvent;

  final String nextTaskTitle;
  final String nextTaskDue;
  final VoidCallback onTapNextTask;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final stateText = isWorking ? 'Working' : 'Free';
    final stateColor = isWorking ? Colors.redAccent : const Color(0xFF00D18F);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                timeText,
                style: tt.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: _StatePill(
                text: stateText,
                color: stateColor,
                subText: isWorking ? null : nextFreeDurationText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          dateText,
          style: tt.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTapNextEvent,
          child: _NextEventRow(
            time: nextEventTime,
            title: nextEventTitle,
            countdown: nextEventCountdown,
            countdownColor: countdownColor,
            label: t.home.next,
            borderColor: nextEventBorderColor,
            backgroundColor: nextEventBackgroundColor,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTapNextTask,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                const Icon(Icons.task, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$nextTaskTitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ),
                if (nextTaskDue.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(
                    nextTaskDue,
                    style: tt.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (isWorking) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF69F0AE).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF69F0AE).withValues(alpha: 0.42),
                width: 1.6,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 20, color: Color(0xFF69F0AE)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${t.home.nextFree}  $nextFreeStartText · $nextFreeDurationText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.text, required this.color, this.subText});

  final String text;
  final Color color;
  final String? subText;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          if (subText != null) ...[
            const SizedBox(width: 8),
            Text(
              '· $subText',
              style: tt.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.84),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextEventRow extends StatelessWidget {
  const _NextEventRow({
    required this.time,
    required this.title,
    required this.countdown,
    required this.countdownColor,
    required this.label,
    required this.borderColor,
    required this.backgroundColor,
  });

  final String time;
  final String title;
  final String countdown;
  final Color countdownColor;
  final String label;

  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.4),
      ),
      child: Row(
        children: [
          Text(
            time,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (countdown.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: countdownColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: countdownColor.withValues(alpha: 0.40)),
              ),
              child: Text(
                countdown,
                style: t.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: countdownColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  const _TranscriptCard({required this.text, required this.isActive});

  final String text;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isActive ? cs.primary : Colors.white)
              .withValues(alpha: isActive ? 0.35 : 0.12),
        ),
      ),
      child: Text(
        text,
        style: t.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.85),
          height: 1.25,
        ),
      ),
    );
  }
}

class _RippleDot extends StatefulWidget {
  const _RippleDot({required this.color});
  final Color color;

  @override
  State<_RippleDot> createState() => _RippleDotState();
}

class _RippleDotState extends State<_RippleDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = _c.value;
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.16 * (1 - v)),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.55 * (1 - v)),
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.9),
              ),
            ),
          ),
        );
      },
    );
  }
}