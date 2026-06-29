// 兼容 shim：主题系统已迁移到 lib/core/theme/。
//
// 保留此文件仅为兼容历史 import 路径，新代码请直接 import
// 'package:lifescale_mobile/core/theme/theme_providers.dart'。
//
// 旧类型名 [Phase1ToneTokens] / [Phase1Theme] / [TodayTone] 以别名形式指向
// 新的 [ToneTokens] / [ToneTheme] / [AppTone]，避免一次性改动过多文件。
library;

export '../../../core/theme/tone_tokens.dart';
export '../../../core/theme/tone_theme.dart';
export '../../../core/theme/app_tone.dart';

import '../../../core/theme/tone_tokens.dart';
import '../../../core/theme/tone_theme.dart';
import '../../../core/theme/app_tone.dart';

/// 旧类型别名（兼容历史引用，新代码请用 [ToneTokens]）。
typedef Phase1ToneTokens = ToneTokens;

/// 旧类型别名（兼容历史引用，新代码请用 [ToneTheme]）。
// ignore: camel_case_types
class Phase1Theme {
  Phase1Theme._();
  static ToneTokens of(AppTone tone) => ToneTheme.of(tone);
}
