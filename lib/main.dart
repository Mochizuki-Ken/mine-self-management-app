import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'swipe_host_page.dart';

void main() {
  runApp(const ProviderScope(child: VoiceLifeDemoApp()));
}

class VoiceLifeDemoApp extends StatelessWidget {
  const VoiceLifeDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceLife Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070A12),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A5CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const AppRouterShell(),
    );
  }
}

class AppRouterShell extends StatelessWidget {
  const AppRouterShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const SwipeHostPage();
  }
}