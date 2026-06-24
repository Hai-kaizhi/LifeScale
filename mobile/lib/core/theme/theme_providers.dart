import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_controller.dart';
import 'app_tone.dart';
import 'tone_theme.dart';
import 'tone_tokens.dart';

export 'theme_controller.dart' show ThemeState;
export 'app_tone.dart';
export 'tone_tokens.dart';
export 'tone_theme.dart';

/// 当前生效的时段（自动或手动锁定后的结果）。
final currentToneProvider = Provider<AppTone>(
  (ref) => ref.watch(themeControllerProvider).tone,
);

/// 当前生效的 tokens（页面取色的最常用入口）。
final currentTokensProvider = Provider<ToneTokens>(
  (ref) => ToneTheme.of(ref.watch(currentToneProvider)),
);

/// 是否处于手动锁定状态（供设置页展示「自动」开关）。
final themeManualLockedProvider = Provider<bool>(
  (ref) => ref.watch(themeControllerProvider).manualLocked,
);
