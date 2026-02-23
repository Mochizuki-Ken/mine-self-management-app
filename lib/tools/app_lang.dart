import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

final appLangProvider = Provider<AppLang>((ref) {
  final settings = ref.watch(settingsProvider);
  return AppLang.from(settings.displayLanguage);
});

class AppLang {
  const AppLang({
    required this.common,
    required this.home,
    required this.settings,
    required this.schedule,
    required this.tasks,
    required this.notes,
  });

  final CommonLang common;
  final HomeLang home;
  final SettingsLang settings;
  final ScheduleLang schedule;
  final TasksLang tasks;
  final NotesLang notes;

  factory AppLang.from(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.english:
        return AppLang.en;
      case AppLanguage.cantonese:
        return AppLang.yue;
      case AppLanguage.chinese:
        return AppLang.zh;
    }
  }

  static const en = AppLang(
    common: CommonLang(
      ok: 'OK',
      cancel: 'Cancel',
      done: 'Done',
      settings: 'Settings',
    ),
    home: HomeLang(
      holdToSpeak: 'Hold to speak',
      listening: 'Listening…',
      processing: 'Processing…',
      longPressToSpeak: 'Long-press anywhere to speak…',
      scheduleLeft: '◀ Schedule',
      tasksRight: 'Tasks ▶',
      nextFree: 'Next free:',
      next: 'Next:',
      // NEW:
      none: 'No upcoming event',
      now: 'now',
    ),
    settings: SettingsLang(
      title: 'Settings',
      languageSection: 'Language',
      displayLanguage: 'Display language',
      voiceLanguage: 'Voice language',
      debugSection: 'Debug',
    ),
    schedule: ScheduleLang(
      simpleTodayTitle: 'Simple Today Schedule',
      detailedTitle: 'Detailed Schedule',
    ),
    tasks: TasksLang(
      sectionsTitle: 'All Tasks / Sections',
      todayTitle: "Today's Prioritized Tasks",
    ),
    notes: NotesLang(
      title: 'Notes',
    ),
  );

  static const yue = AppLang(
    common: CommonLang(
      ok: '確定',
      cancel: '取消',
      done: '完成',
      settings: '設定',
    ),
    home: HomeLang(
      holdToSpeak: '按住講嘢',
      listening: '聽緊…',
      processing: '處理中…',
      longPressToSpeak: '長按任何位置講嘢…',
      scheduleLeft: '◀ 行程',
      tasksRight: '任務 ▶',
      nextFree: '下一段空檔：',
      next: '事項：',
      // NEW:
      none: '冇即將到來嘅行程',
      now: '而家',
    ),
    settings: SettingsLang(
      title: '設定',
      languageSection: '語言',
      displayLanguage: '顯示語言',
      voiceLanguage: '語音語言',
      debugSection: '除錯',
    ),
    schedule: ScheduleLang(
      simpleTodayTitle: '今日行程（簡潔）',
      detailedTitle: '行程（詳細）',
    ),
    tasks: TasksLang(
      sectionsTitle: '所有任務／分類',
      todayTitle: '今日優先任務',
    ),
    notes: NotesLang(
      title: '筆記',
    ),
  );

  static const zh = AppLang(
    common: CommonLang(
      ok: '确定',
      cancel: '取消',
      done: '完成',
      settings: '设置',
    ),
    home: HomeLang(
      holdToSpeak: '按住说话',
      listening: '正在聆听…',
      processing: '处理中…',
      longPressToSpeak: '长按任意位置说话…',
      scheduleLeft: '◀ 日程',
      tasksRight: '任务 ▶',
      nextFree: '下一段空闲：',
      next: '下一个：',
      // NEW:
      none: '没有即将到来的日程',
      now: '现在',
    ),
    settings: SettingsLang(
      title: '设置',
      languageSection: '语言',
      displayLanguage: '显示语言',
      voiceLanguage: '语音语言',
      debugSection: '调试',
    ),
    schedule: ScheduleLang(
      simpleTodayTitle: '今日行程（简洁）',
      detailedTitle: '行程（详细）',
    ),
    tasks: TasksLang(
      sectionsTitle: '所有任务／分类',
      todayTitle: '今日优先任务',
    ),
    notes: NotesLang(
      title: '笔记',
    ),
  );
}

class CommonLang {
  const CommonLang({
    required this.ok,
    required this.cancel,
    required this.done,
    required this.settings,
  });
  final String ok;
  final String cancel;
  final String done;
  final String settings;
}

class HomeLang {
  const HomeLang({
    required this.holdToSpeak,
    required this.listening,
    required this.processing,
    required this.longPressToSpeak,
    required this.scheduleLeft,
    required this.tasksRight,
    required this.nextFree,
    required this.next,
    // NEW:
    required this.none,
    required this.now,
  });

  final String holdToSpeak;
  final String listening;
  final String processing;
  final String longPressToSpeak;
  final String scheduleLeft;
  final String tasksRight;
  final String nextFree;
  final String next;

  /// Shown when there is no upcoming event.
  final String none;

  /// Shown when the next event is happening "now".
  final String now;
}

class SettingsLang {
  const SettingsLang({
    required this.title,
    required this.languageSection,
    required this.displayLanguage,
    required this.voiceLanguage,
    required this.debugSection,
  });

  final String title;
  final String languageSection;
  final String displayLanguage;
  final String voiceLanguage;
  final String debugSection;
}

class ScheduleLang {
  const ScheduleLang({
    required this.simpleTodayTitle,
    required this.detailedTitle,
  });

  final String simpleTodayTitle;
  final String detailedTitle;
}

class TasksLang {
  const TasksLang({
    required this.sectionsTitle,
    required this.todayTitle,
  });

  final String sectionsTitle;
  final String todayTitle;
}

class NotesLang {
  const NotesLang({required this.title});
  final String title;
}