import 'package:flutter/material.dart';

import 'tone_tokens.dart';
import 'tone_theme.dart';
import 'app_tone.dart';

/// 把 [ToneTokens] 桥接到 Flutter 原生主题机制（[ThemeExtension]）。
///
/// 挂载到 [ThemeData.extensions] 后，任意深层 widget 都能通过
/// `Theme.of(context).extension<ToneThemeExtension>()` 取到当前色调 tokens，
/// 无需逐级透传参数（官方推荐做法）。
///
/// 注意：[lerp] 提供线性插值以支持平滑过渡动画。
@immutable
class ToneThemeExtension extends ThemeExtension<ToneThemeExtension> {
  const ToneThemeExtension(this.tokens);

  final ToneTokens tokens;

  /// 便捷构造：按 [AppTone] 取对应 tokens 包装。
  static ToneThemeExtension forTone(AppTone tone) =>
      ToneThemeExtension(ToneTheme.of(tone));

  @override
  ToneThemeExtension copyWith({ToneTokens? tokens}) =>
      ToneThemeExtension(tokens ?? this.tokens);

  @override
  ToneThemeExtension lerp(ToneThemeExtension? other, double t) {
    if (other == null) return this;
    final a = tokens;
    final b = other.tokens;
    return ToneThemeExtension(ToneTokens(
      tone: t < 0.5 ? a.tone : b.tone,
      name: t < 0.5 ? a.name : b.name,
      label: t < 0.5 ? a.label : b.label,
      primary: Color.lerp(a.primary, b.primary, t)!,
      secondary: Color.lerp(a.secondary, b.secondary, t)!,
      text: Color.lerp(a.text, b.text, t)!,
      muted: Color.lerp(a.muted, b.muted, t)!,
      card: Color.lerp(a.card, b.card, t)!,
      cardBorder: Color.lerp(a.cardBorder, b.cardBorder, t)!,
      background: [
        Color.lerp(a.background[0], b.background[0], t)!,
        Color.lerp(a.background[1], b.background[1], t)!,
        Color.lerp(a.background[2], b.background[2], t)!,
      ],
      backgroundAsset: t < 0.5 ? a.backgroundAsset : b.backgroundAsset,
      bottomNav: Color.lerp(a.bottomNav, b.bottomNav, t)!,
      bottomNavBorder: Color.lerp(a.bottomNavBorder, b.bottomNavBorder, t)!,
      scrim: [
        Color.lerp(a.scrim[0], b.scrim[0], t)!,
        Color.lerp(a.scrim[1], b.scrim[1], t)!,
        Color.lerp(a.scrim[2], b.scrim[2], t)!,
      ],
      success: Color.lerp(a.success, b.success, t)!,
      error: Color.lerp(a.error, b.error, t)!,
      warning: Color.lerp(a.warning, b.warning, t)!,
      info: Color.lerp(a.info, b.info, t)!,
      taskDone: Color.lerp(a.taskDone, b.taskDone, t)!,
      taskPart: Color.lerp(a.taskPart, b.taskPart, t)!,
    ));
  }

  /// 从 context 便捷取 tokens（自动处理 null 兜底为夜晚色调）。
  static ToneTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<ToneThemeExtension>();
    return ext?.tokens ?? ToneTheme.night;
  }
}
