import 'package:flutter/material.dart';

import '../../../shared/constants/assets.dart';
import 'app_tone.dart';
import 'tone_tokens.dart';

/// 时段主题注册中心。
///
/// 采用 Strategy + Token 设计模式：每套 [AppTone] 对应一组 const [ToneTokens]，
/// 通过 [of] 按枚举取用。新增主题只需加一个 `static const` 并在 [of] 补一个 case，
/// 不影响任何 UI 代码（符合开闭原则）。
abstract final class ToneTheme {
  static ToneTokens of(AppTone tone) {
    switch (tone) {
      case AppTone.morning:
        return morning;
      case AppTone.afternoon:
        return afternoon;
      case AppTone.night:
        return night;
    }
  }

  /// 早晨：暖橙色调（浅色基调）。
  static const morning = ToneTokens(
    tone: AppTone.morning,
    name: 'morning',
    label: '早晨',
    primary: Color(0xFFFF7A1A),
    secondary: Color(0xFFFFB65A),
    text: Color(0xFF2E2A24),
    muted: Color(0xFF8A6C4B),
    card: Color(0xF4FFF9EE),
    cardBorder: Color(0x70FFD5A4),
    background: [Color(0xFFFFF6DD), Color(0xFFFFE1A9), Color(0xFFFFFDF7)],
    backgroundAsset: AppAssets.todayMorningBackground,
    bottomNav: Color(0xF7FFF8EA),
    bottomNavBorder: Color(0x66FFD5A4),
    scrim: [Color(0x22FFFFFF), Color(0x10FFE8BE), Color(0x26FFFFFF)],
    success: Color(0xFF16A34A),
    error: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    info: Color(0xFFEA580C),
    taskDone: Color(0xFFEA580C),
    taskPart: Color(0xFFFB923C),
  );

  /// 下午：蓝色调（浅色基调）。
  static const afternoon = ToneTokens(
    tone: AppTone.afternoon,
    name: 'afternoon',
    label: '下午',
    primary: Color(0xFF1F6BFF),
    secondary: Color(0xFF78C5FF),
    text: Color(0xFF102A5F),
    muted: Color(0xFF64789B),
    card: Color(0xF0F7FBFF),
    cardBorder: Color(0x668FC4FF),
    background: [Color(0xFFEAF7FF), Color(0xFFCFE9FF), Color(0xFFF9FCFF)],
    backgroundAsset: AppAssets.todayAfternoonBackground,
    bottomNav: Color(0xF5F8FBFF),
    bottomNavBorder: Color(0x668FC4FF),
    scrim: [Color(0x26FFFFFF), Color(0x00FFFFFF), Color(0x28F5FBFF)],
    success: Color(0xFF16A34A),
    error: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    info: Color(0xFF3B82F6),
    taskDone: Color(0xFF3B82F6),
    taskPart: Color(0xFF60A5FA),
  );

  /// 夜晚：紫色暗色调（暗色基调）。
  static const night = ToneTokens(
    tone: AppTone.night,
    name: 'night',
    label: '夜晚',
    primary: Color(0xFF9B6CFF),
    secondary: Color(0xFF67D7FF),
    text: Color(0xFFF7F8FF),
    muted: Color(0xFFB8B9E6),
    card: Color(0x55262978),
    cardBorder: Color(0x669B6CFF),
    background: [Color(0xFF071447), Color(0xFF11106A), Color(0xFF251660)],
    backgroundAsset: AppAssets.todayNightBackground,
    bottomNav: Color(0xE6071447),
    bottomNavBorder: Color(0x449B6CFF),
    scrim: [Color(0x22071447), Color(0x00071447), Color(0xAA071447)],
    success: Color(0xFF22C55E),
    error: Color(0xFFFF6B6B),
    warning: Color(0xFFF59E0B),
    info: Color(0xFF67D7FF),
    taskDone: Color(0xFF3B82F6),
    taskPart: Color(0xFF60A5FA),
  );

  /// 根据小时数判定时段（阈值：<12 早晨 / <18 下午 / 否则夜晚）。
  ///
  /// 全 App 的时段判定唯一入口，消灭此前在 phase1/today 两个 controller
  /// 内重复的 `_toneForNow()`。
  static AppTone periodOfHour(int hour) {
    if (hour < 12) return AppTone.morning;
    if (hour < 18) return AppTone.afternoon;
    return AppTone.night;
  }

  /// 取当前时刻对应的时段。
  static AppTone toneForNow() => periodOfHour(DateTime.now().hour);
}
