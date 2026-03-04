import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/all_tasks_page.dart';
import 'pages/today_tasks_page.dart';

import 'pages/home_page.dart';
import 'pages/detailed_schedule_page.dart';
import 'pages/simple_today_schedule_page.dart';
import 'pages/notes_page.dart';
// import 'demo_empty_page.dart';
import 'tools/app_lang.dart';

class SwipeHostPage extends StatefulWidget {
  const SwipeHostPage({super.key});

  @override
  State<SwipeHostPage> createState() => _SwipeHostPageState();
}

class _SwipeHostPageState extends State<SwipeHostPage> {
  final PageController _hController = PageController(initialPage: 1);
  final PageController _leftVController = PageController(initialPage: 0);
  final PageController _rightVController = PageController(initialPage: 1);

  int _hIndex = 1;
  int _leftVIndex = 0;
  int _rightVIndex = 1;

  Future<void> goToHorizontalPage(int index, {bool animate = true}) async {
    if (animate) {
      await _hController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _hController.jumpToPage(index);
    }
  }

  Future<void> goToLeftVerticalPage(int index, {bool animate = true}) async {
    await goToHorizontalPage(0, animate: animate);
    if (animate) {
      await _leftVController.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _leftVController.jumpToPage(index);
    }
  }

  Future<void> goToRightVerticalPage(int index, {bool animate = true}) async {
    await goToHorizontalPage(2, animate: animate);
    if (animate) {
      await _rightVController.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _rightVController.jumpToPage(index);
    }
  }

  @override
  void dispose() {
    _hController.dispose();
    _leftVController.dispose();
    _rightVController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final t = ref.watch(appLangProvider);

        return Scaffold(
          body: SafeArea(
            child: PageView(
              controller: _hController,
              reverse: true,
              onPageChanged: (i) => setState(() => _hIndex = i),
              children: [
                PageView(
                  controller: _leftVController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (i) => setState(() => _leftVIndex = i),
                  children: const [
                    SimpleTodaySchedulePage(),
                    DetailedSchedulePage(),
                    
                    
                  ],
                ),
                HomePage(
                  onTapGoLeftTop: () => goToLeftVerticalPage(0),
                  onTapGoLeftBottom: () => goToLeftVerticalPage(1),
                  onTapGoRightTop: () => goToRightVerticalPage(0),
                  onTapGoRightMiddle: () => goToRightVerticalPage(1),
                  onTapGoRightBottom: () => goToRightVerticalPage(2),
                ),
                PageView(
                  controller: _rightVController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (i) => setState(() => _rightVIndex = i),
                  children: const [
                    AllTasksPage(),
                    TodayTasksPage(),
                    NotesPage(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}