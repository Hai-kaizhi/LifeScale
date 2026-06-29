import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'app_tone.dart';
import 'theme_choice.dart';
import 'tone_theme.dart';

/// 主题状态：当前生效 tone + 用户主题选择（[ThemeChoice]）。
@immutable
class ThemeState {
  const ThemeState({
    required this.tone,
    this.choice = ThemeChoice.auto,
  });

  /// 当前生效的色调（由 [choice] 推导：auto→时钟，固定→对应 AppTone）。
  final AppTone tone;

  /// 用户选择的主题模式。
  final ThemeChoice choice;

  /// 是否被用户锁定为固定主题（非 auto）。
  /// 保留以兼容定时器逻辑：固定主题时不再自动切换。
  bool get manualLocked => !choice.isAuto;

  ThemeState copyWith({AppTone? tone, ThemeChoice? choice}) => ThemeState(
        tone: tone ?? this.tone,
        choice: choice ?? this.choice,
      );
}

/// 全局主题控制器（单一数据源 Single Source of Truth）。
///
/// 行为：
/// - 启动时读取持久化的 [ThemeChoice]，按 choice 推导初始 tone。
/// - 每分钟定时器：仅在 [ThemeChoice.auto] 时检查是否跨越时段阈值（12/18 点）自动切换。
/// - app 从后台回到前台时立即检查一次（[WidgetsBindingObserver]）。
/// - [setChoice] 切换主题模式：auto→按时间；固定→锁定到对应 tone；同时持久化。
class ThemeController extends Notifier<ThemeState>
    with WidgetsBindingObserver {
  Timer? _ticker;
  int? _lastHour;

  @override
  ThemeState build() {
    final choice = _readPersistedChoice();
    final tone = _toneFor(choice);
    _lastHour = DateTime.now().hour;

    // 定时器：每分钟检查一次是否跨时段（仅 auto 生效）。
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) => _tick());

    // 监听前后台切换：回到前台立即校准。
    WidgetsBinding.instance.addObserver(this);

    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
      WidgetsBinding.instance.removeObserver(this);
    });

    return ThemeState(tone: tone, choice: choice);
  }

  /// 从 PrefsStore 同步读取持久化的主题选择（默认 auto）。
  ThemeChoice _readPersistedChoice() {
    try {
      return ref.read(prefsStoreProvider).getThemeChoice();
    } catch (_) {
      return ThemeChoice.auto;
    }
  }

  /// 按 choice 推导生效 tone：auto→当前时钟，固定→对应 AppTone。
  AppTone _toneFor(ThemeChoice choice) =>
      choice.fixedTone ?? ToneTheme.toneForNow();

  void _tick() {
    // 仅「跟随时间」模式自动切换；固定主题不变。
    if (!state.choice.isAuto) return;
    final hour = DateTime.now().hour;
    if (hour == _lastHour) return;
    _lastHour = hour;
    final target = ToneTheme.periodOfHour(hour);
    if (target != state.tone) {
      state = state.copyWith(tone: target);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
    }
  }

  /// 切换主题模式并持久化。
  /// - auto：回到「按时间自动」，tone 立即按当前时钟校准。
  /// - 固定：锁定到对应 AppTone。
  void setChoice(ThemeChoice choice) {
    _lastHour = DateTime.now().hour;
    state = ThemeState(tone: _toneFor(choice), choice: choice);
    // 持久化（忽略失败，下次启动按默认推导）。
    try {
      ref.read(prefsStoreProvider).setThemeChoice(choice);
    } catch (_) {
      // ignore
    }
  }

  /// 手动切换某个具体 tone（保留兼容旧调用：等价于切到对应固定主题）。
  void setTone(AppTone tone) {
    final choice = ThemeChoice.values.firstWhere(
      (c) => c.fixedTone == tone,
      orElse: () => ThemeChoice.dark,
    );
    setChoice(choice);
  }

  /// 解除手动锁定，回到「跟随时间」模式。
  void resetToAuto() => setChoice(ThemeChoice.auto);
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeState>(ThemeController.new);
