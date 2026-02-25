import 'package:flutter/material.dart';

class ProjectProgressBar extends StatelessWidget {
  const ProjectProgressBar({
    super.key,
    required this.totalSubTasks,
    required this.doneSubTasks,
    this.height = 10,
    this.showLabel = true,
    this.trackColor,
    this.progressColor,
  });

  final int totalSubTasks;
  final int doneSubTasks;

  final double height;
  final bool showLabel;
  final Color? trackColor;
  final Color? progressColor;

  double get _progress {
    if (totalSubTasks <= 0) return 0.0;
    return (doneSubTasks / totalSubTasks).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final track = trackColor ?? Colors.white.withValues(alpha: 0.12);
    final fill = progressColor ?? Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: height,
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: track,
              valueColor: AlwaysStoppedAnimation<Color>(fill),
              minHeight: height,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            totalSubTasks <= 0
                ? 'No sub tasks'
                : '${(_progress * 100).round()}%  ($doneSubTasks / $totalSubTasks)',
            style: tt.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.70),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}