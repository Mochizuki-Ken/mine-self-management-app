import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_page.dart';
import 'providers/schedule_store.dart';
import 'providers/settings_provider.dart';
import 'providers/voice_assistant_provider.dart';
import 'providers/task_store.dart';
import 'models/app_models.dart';
import 'tools/app_lang.dart';

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
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);

  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  Offset? _pressPoint;

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulse.dispose();
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

  // NEW: format a time range as HH:MM–HH:MM (same day) or HH:MM–MM/DD HH:MM if spanning days.
  String _formatRange(DateTime start, DateTime end) {
    String two(int n) => n.toString().padLeft(2, '0');
    String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
    final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
    if (sameDay) return '${hm(start)}–${hm(end)}';
    return '${hm(start)}–${two(end.month)}/${two(end.day)} ${hm(end)}';
  }

  String _computeNextFreeSlotToday({
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
      return _formatRange(now, todayEnd);
    }

    if (now.isBefore(todayEvents.first.startAt)) {
      return _formatRange(now, todayEvents.first.startAt);
    }

    DateTime cursor = now;
    for (var i = 0; i < todayEvents.length; i++) {
      final e = todayEvents[i];

      if (cursor.isBefore(e.endAt)) cursor = e.endAt;

      final nextStart =
          (i + 1 < todayEvents.length) ? todayEvents[i + 1].startAt : todayEnd;

      if (cursor.isBefore(nextStart)) {
        return _formatRange(cursor, nextStart);
      }
    }

    return _formatRange(now, todayEnd);
  }

  bool _isWorkingNow({
    required DateTime now,
    required List<Event> events,
  }) {
    return events.any((e) => e.startAt.isBefore(now) && e.endAt.isAfter(now));
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

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(appLangProvider);
    final cs = Theme.of(context).colorScheme;
    final voice = ref.watch(voiceAssistantProvider);

    final events = ref.watch(scheduleProvider);
    final tasks = ref.watch(tasksProvider);
    final now = DateTime.now();

    // working/free state
    final isWorking = _isWorkingNow(now: now, events: events);

    final upcoming = events.where((e) => e.endAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final nextEvent = upcoming.isEmpty ? null : upcoming.first;

    // next task (short-term, not done)
    final upcomingTasks = tasks
        .where((t) => t.status != TaskStatus.done)
        .toList()
      ..sort((a, b) => _sortDue(a.due).compareTo(_sortDue(b.due)));
    final nextTask = upcomingTasks.isEmpty ? null : upcomingTasks.first;

    final nextEventTime = nextEvent == null ? '--:--' : _hm(nextEvent.startAt);
    final nextEventTitle = nextEvent == null ? t.home.none : nextEvent.title;
    final nextEventCountdown = nextEvent == null
        ? ''
        : (nextEvent.startAt.isBefore(now)
            ? t.home.now
            : 'in ${_formatDurationShort(nextEvent.startAt.difference(now))}');
    final countdownColor =
        nextEvent == null ? const Color(0xFFFFC857) : Color(nextEvent.colorValue);

    final nextFreeSlot = _computeNextFreeSlotToday(now: now, events: events);

    final transcriptText = voice.isListening
        ? (voice.partialText.isEmpty ? t.home.listening : voice.partialText)
        : (voice.finalText.isEmpty ? '' : voice.finalText);

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
                  nextEventCountdown: nextEventCountdown,
                  countdownColor: countdownColor,

                  nextFreeSlot: nextFreeSlot,
                  t: t,

                  onTapNextEvent: widget.onTapGoLeftBottom,

                  // new: task preview
                  nextTaskTitle: nextTaskTitle,
                  nextTaskDue: nextTaskDue,
                  onTapNextTask: widget.onTapGoRightMiddle,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Center(
                    child: _MicCore(
                      pulse: _pulse,
                      isRecording: voice.isListening,
                      t: t,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _BottomHintArea(t: t),
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

class _TopStatusArea extends StatelessWidget {
  const _TopStatusArea({
    required this.timeText,
    required this.dateText,
    required this.isWorking,
    required this.nextEventTime,
    required this.nextEventTitle,
    required this.nextEventCountdown,
    required this.countdownColor,
    required this.nextFreeSlot,
    required this.t,
    required this.onTapNextEvent,

    // new:
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

  final String nextFreeSlot;

  final AppLang t;

  final VoidCallback onTapNextEvent;

  // new:
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

            // CHANGED: shift pill to the left so it doesn't overlap Settings button
            Padding(
              padding: const EdgeInsets.only(right: 44),
              child: _StatePill(text: stateText, color: stateColor),
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
          ),
        ),
        const SizedBox(height: 10),

        // new: next task preview
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
                    '${t.home.next} $nextTaskTitle',
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
        Text(
          '${t.home.nextFree} $nextFreeSlot',
          style: tt.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.text, required this.color});

  final String text;
  final Color color;

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
  });

  final String time;
  final String title;
  final String countdown;
  final Color countdownColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
              '$label $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (countdown.isNotEmpty)
            Text(
              countdown,
              style: t.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: countdownColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _MicCore extends StatelessWidget {
  const _MicCore({
    required this.pulse,
    required this.isRecording,
    required this.t,
  });

  final AnimationController pulse;
  final bool isRecording;
  final AppLang t;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final baseSize = MediaQuery.sizeOf(context).width * 0.44;
    final size = baseSize.clamp(180.0, 260.0);

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = 0.25 + (pulse.value * 0.20);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.94),
                boxShadow: [
                  BoxShadow(
                    color: (isRecording ? Colors.redAccent : cs.primary)
                        .withValues(alpha: glow),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: isRecording
                      ? const _SpeakingDots(key: ValueKey('dots'))
                      : Icon(
                          Icons.mic_none_rounded,
                          key: const ValueKey('mic'),
                          size: size * 0.42,
                          color: Colors.black.withValues(alpha: 0.78),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isRecording ? t.home.listening : t.home.holdToSpeak,
              style: tt.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpeakingDots extends StatefulWidget {
  const _SpeakingDots({required ValueKey<String> key});

  @override
  State<_SpeakingDots> createState() => _SpeakingDotsState();
}

class _SpeakingDotsState extends State<_SpeakingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

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
        final t = _c.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            final phase = (t * 2 * math.pi) + i * 0.8;
            final dy = math.sin(phase) * 5.0;
            final a = (0.55 + 0.45 * (0.5 + 0.5 * math.sin(phase)))
                .clamp(0.0, 1.0);

            return Padding(
              padding: EdgeInsets.only(right: i == 3 ? 0 : 10),
              child: Transform.translate(
                offset: Offset(0, -dy),
                child: Opacity(
                  opacity: a,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // dots are white
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// The rest (TranscriptCard, RippleDot, BottomHintArea) unchanged:
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

class _BottomHintArea extends StatelessWidget {
  const _BottomHintArea({required this.t});
  final AppLang t;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          t.home.longPressToSpeak,
          style: tt.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t.home.scheduleLeft,
              style: tt.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 18),
            Text(
              t.home.tasksRight,
              style: tt.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}