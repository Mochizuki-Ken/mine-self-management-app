import 'package:flutter/material.dart';

class DemoEmptyPage extends StatelessWidget {
  const DemoEmptyPage({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: Text(
                'Empty page (placeholder)',
                style: t.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}