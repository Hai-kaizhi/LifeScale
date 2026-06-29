import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/providers.dart';
import 'core/storage/prefs_store.dart';

/// 应用入口。
///
/// 启动链：`ensureInitialized` → 取偏好 → `Bootstrap.run()`（沙盒目录 + SQLite）→ `runApp`。
///
/// 关键：**全程错误兜底**。此前若 bootstrap 在 `runApp` 之前抛异常（如原生插件初始化失败），
/// 由于没有 try/catch，`main()` 直接挂掉，活动只显示纯白启动背景 —— 即"真机白屏"。
/// 现在所有未捕获错误都打到控制台 / `adb logcat`，且 bootstrap 失败时改为渲染**可见的红色错误页**，
/// 把真正的异常 + 堆栈显示在屏幕上，让白屏变成可诊断。
Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 框架渲染期错误（widget build 抛错）→ 既走默认红屏，也打到控制台。
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('🟥 FlutterError: ${details.exception}\n${details.stack}');
      };
      // 平台层 / Dart isolate 的异步未捕获错误 → 吞掉并打日志（返回 true = 已处理，不崩）。
      // 用 WidgetsBinding.instance.platformDispatcher，避免直接 import dart:ui。
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        debugPrint('🟥 PlatformError: $error\n$stack');
        return true;
      };

      SharedPreferences? prefs;
      Object? bootErr;
      StackTrace? bootStack;
      try {
        // 偏好几乎不会失败；Bootstrap（sqflite / path_provider）才是白屏风险点。
        prefs = await SharedPreferences.getInstance();
        await Bootstrap.run();
      } catch (e, s) {
        bootErr = e;
        bootStack = s;
        debugPrint('🟥 启动初始化失败: $e\n$s');
      }

      runApp(
        ProviderScope(
          // 偏好可用才挂 override；错误页不读 prefs，缺 override 也无妨。
          overrides: [
            if (prefs != null)
              prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),
          ],
          child: (bootErr == null && prefs != null)
              ? const LifeScaleApp()
              : _BootstrapErrorApp(
                  bootErr == null
                      ? 'SharedPreferences 初始化失败'
                      : '$bootErr\n\n$bootStack',
                ),
        ),
      );
    },
    (error, stack) {
      debugPrint('🟥 Zone 未捕获异常: $error\n$stack');
    },
  );
}

/// bootstrap 失败时的兜底错误页：红底白字、可长按选择复制异常与堆栈。
/// 仅当启动初始化抛错时出现；正常启动不会渲染它。
class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFB00020),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              'LifeScale 启动失败\n\n$message',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
