import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_tone.dart';
import 'tone_theme.dart';

/// 主题状态：当前生效 tone + 是否被用户手动锁定。
@immutable
class ThemeState {
  const ThemeState({
    required this.tone,
    this.manualLocked = false,
  });

  final AppTone tone;

  /// 一旦用户手动切换，即锁定为 true，自动定时器不再改写 tone，
  /// 直至调用 [ThemeController.resetToAuto]。
  final bool manualLocked;

  ThemeState copyWith({AppTone? tone, bool? manualLocked}) => ThemeState(
        tone: tone ?? this.tone,
        manualLocked: manualLocked ?? this.manualLocked,
      );
}

/// 全局主题控制器（单一数据源 Single Source of Truth）。
///
/// 取代此前在 Phase1Controller / TodayController 中重复持有的 tone 状态。
/// 行为：
/// - 启动时按当前小时推导初始 tone（[ToneTheme.toneForNow]）。
/// - 每分钟定时器检查：若跨越时段阈值（12 / 18 点）且未被手动锁定，自动切换。
/// - app 从后台回到前台时立即检查一次（[WidgetsBindingObserver]）。
/// - 用户手动 [setTone] 后 [ThemeState.manualLocked] 置 true，定时器让位。
class ThemeController extends Notifier<ThemeState>
    with WidgetsBindingObserver {
  Timer? _ticker;
  int? _lastHour;

  @override
  ThemeState build() {
    final now = ToneTheme.toneForNow();
    _lastHour = DateTime.now().hour;

    // 定时器：每分钟检查一次是否跨时段。
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) => _tick());

    // 监听前后台切换：回到前台立即校准。
    WidgetsBinding.instance.addObserver(this);

    // Riverpod 会在 provider 销毁时调 ref.onDispose，统一清理。
    ref.onDispose(() {
      _ticker?.cancel();
      _ticker = null;
      WidgetsBinding.instance.removeObserver(this);
    });

    return ThemeState(tone: now);
  }

  void _tick() {
    if (state.manualLocked) return;
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
    // 回到前台时立即校准色调（可能已跨越时段）。
    if (state == AppLifecycleState.resumed) {
      _tick();
    }
  }

  /// 用户手动切换 tone：锁定，定时器不再自动改写。
  void setTone(AppTone tone) {
    _lastHour = DateTime.now().hour;
    state = ThemeState(tone: tone, manualLocked: true);
  }

  /// 解除手动锁定，回到「按时间自动」模式（供「我的」页设置入口）。
  void resetToAuto() {
    _lastHour = DateTime.now().hour;
    state = ThemeState(
      tone: ToneTheme.toneForNow(),
      manualLocked: false,
    );
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeState>(ThemeController.new);
