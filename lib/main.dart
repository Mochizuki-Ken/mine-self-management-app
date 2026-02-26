import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'swipe_host_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive init (for local storage)
  await Hive.initFlutter();

  runApp(const ProviderScope(child: MineApp()));
}

class MineApp extends StatelessWidget {
  const MineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SwipeHostPage(),
    );
  }
}