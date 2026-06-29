import 'package:flutter/material.dart';

import 'app_tone.dart';

/// 单套时段主题的全部配色 token。
///
/// 设计目标：把全 App 用到的颜色收敛为「语义命名」而非具体色值，
/// 这样新增一套主题时只需填一组 [ToneTokens]，无需改动任何 UI 代码。
///
/// - 基础色：primary / secondary / text / muted / card / background / bottomNav / scrim
/// - 语义色：success / error / warning / info / taskDone / taskPart
///   （取代此前散落在各页面的 `Color(0xFF22C55E)` 等硬编码字面量）
class ToneTokens {
  const ToneTokens({
    required this.tone,
    required this.name,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.text,
    required this.muted,
    required this.card,
    required this.cardBorder,
    required this.background,
    required this.backgroundAsset,
    required this.bottomNav,
    required this.bottomNavBorder,
    required this.scrim,
    required this.success,
    required this.error,
    required this.warning,
    required this.info,
    required this.taskDone,
    required this.taskPart,
  });

  /// 该 tokens 对应的时段枚举（便于反查、控件回传）。
  final AppTone tone;

  final String name;
  final String label;

  // —— 基础色 ——
  final Color primary;
  final Color secondary;
  final Color text;
  final Color muted;
  final Color card;
  final Color cardBorder;

  /// 背景渐变色（自上而下）。
  final List<Color> background;

  /// 背景插画资源路径。
  final String backgroundAsset;

  final Color bottomNav;
  final Color bottomNavBorder;

  /// 背景图之上的 scrim 渐变（提升前景对比度）。
  final List<Color> scrim;

  // —— 语义色 ——（取代散落的 Color(0x...) 字面量）
  /// 成功 / 完成 / 快速记录点：替代原 0xFF22C55E。
  final Color success;

  /// 错误 / 删除：替代原 0xFFDC2626 / 0xFFB3261E。
  final Color error;

  /// 警告 / 待办：替代原 0xFFF59E0B。
  final Color warning;

  /// 信息 / 同步中：替代原 0xFF3B82F6。
  final Color info;

  /// 日程全完成蓝：替代原 0xFF3B82F6（calendar 标记点）。
  final Color taskDone;

  /// 日程部分完成浅蓝：替代原 0xFF60A5FA。
  final Color taskPart;

  /// 便捷别名：暗色基调判定。
  bool get isDark => tone.isDark;
}
