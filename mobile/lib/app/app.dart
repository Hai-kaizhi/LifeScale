import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_providers.dart';
import '../core/theme/tone_theme_extension.dart';
import 'router.dart';

class LifeScaleApp extends ConsumerWidget {
  const LifeScaleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final tokens = ref.watch(currentTokensProvider);

    return MaterialApp.router(
      title: 'LifeScale',
      debugShowCheckedModeBanner: false,
      // 动态主题：按当前时段 tone 生成 ColorScheme，让所有未显式着色的 Material
      // 组件（AlertDialog / TextFormField / Switch / ListTile / showDatePicker）
      // 自动跟随当前色调，根治此前「全局写死暗色」导致的色调割裂。
      theme: _buildTheme(tokens),
      themeMode: tokens.isDark ? ThemeMode.dark : ThemeMode.light,
      // 中文本地化：DatePicker / 文案中文化。
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }

  /// 按当前 tone 构建 ThemeData：ColorScheme + ThemeExtension + 各组件主题。
  ThemeData _buildTheme(ToneTokens tokens) {
    final brightness =
        tokens.isDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.primary,
      onPrimary: _onColorOf(tokens.primary, brightness),
      secondary: tokens.secondary,
      onSecondary: _onColorOf(tokens.secondary, brightness),
      error: tokens.error,
      onError: _onColorOf(tokens.error, brightness),
      surface: tokens.background.isNotEmpty
          ? tokens.background[0]
          : tokens.card,
      onSurface: tokens.text,
      surfaceContainerHighest: tokens.card,
      onSurfaceVariant: tokens.muted,
      outline: tokens.cardBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // 自定义语义 tokens 挂到 ThemeExtension：深层 widget 可用
      // Theme.of(context).extension<ToneThemeExtension>() 取色。
      extensions: [ToneThemeExtension(tokens)],
      scaffoldBackgroundColor:
          tokens.background.isNotEmpty ? tokens.background[0] : tokens.card,
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: tokens.muted),
        labelStyle: TextStyle(color: tokens.muted),
        floatingLabelStyle: TextStyle(color: tokens.primary),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: tokens.primary),
      ),
      listTileTheme: ListTileThemeData(
        textColor: tokens.text,
        iconColor: tokens.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? _onColorOf(tokens.primary, brightness)
                : tokens.muted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? tokens.primary
                : tokens.muted.withValues(alpha: 0.2)),
      ),
    );
  }

  /// 计算某底色上的前景色（黑或白），保证对比度。
  Color _onColorOf(Color bg, Brightness brightness) {
    // 简单亮度判定：相对亮度 > 0.5 用黑字，否则白字。
    return bg.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
  }
}
