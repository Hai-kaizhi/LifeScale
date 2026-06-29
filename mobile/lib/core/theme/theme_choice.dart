import 'app_tone.dart';

/// 用户层面的主题选择（4 选项）。
///
/// 复用现有 3 套 [AppTone] 色调作为固定主题，无需新建 ToneTokens：
/// - [auto]：跟随时间（按当前小时推导 morning/afternoon/night），默认。
/// - [fresh]：清新（固定 afternoon 冷蓝）。
/// - [sunshine]：阳光（固定 morning 暖橙）。
/// - [dark]：暗调（固定 night 暗紫）。
enum ThemeChoice {
  auto('跟随时间', null),
  fresh('清新', AppTone.afternoon),
  sunshine('阳光', AppTone.morning),
  dark('暗调', AppTone.night);

  const ThemeChoice(this.label, this.fixedTone);

  /// 展示名。
  final String label;

  /// 固定主题对应的 [AppTone]；[auto] 为 null（由时钟推导）。
  final AppTone? fixedTone;

  /// 是否跟随时间自动变化。
  bool get isAuto => this == ThemeChoice.auto;

  /// 持久化用字符串 key（与 [AppTone.name] 风格一致）。
  String get persistKey => name;

  /// 从持久化字符串还原（非法/空值降级为 [auto]）。
  static ThemeChoice fromPersistKey(String? raw) {
    if (raw == null || raw.isEmpty) return ThemeChoice.auto;
    for (final c in ThemeChoice.values) {
      if (c.name == raw) return c;
    }
    return ThemeChoice.auto;
  }
}
