import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import '../features/conflict/presentation/conflict_center_page.dart';
import '../features/notes/presentation/note_editor_page.dart';
import '../features/phase1/presentation/login_page.dart';
import '../features/phase1/presentation/phase1_controller.dart';
import '../features/phase1/presentation/phase1_state.dart';
import '../features/phase1/presentation/splash_page.dart';
import '../features/phase1/presentation/syncing_page.dart';
import '../features/review/presentation/review_page.dart';
import '../features/vault/presentation/foundation_page.dart';
import '../app/app_bottom_nav.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen<Phase1State>(
    phase1ControllerProvider,
    (_, __) => refresh.refresh(),
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, routerState) {
      final phase = ref.read(phase1ControllerProvider);
      final path = routerState.uri.path;

      if (!phase.bootComplete) {
        return path == '/splash' ? null : '/splash';
      }
      if (phase.stage == Phase1Stage.ready &&
          (path == '/splash' ||
              path == '/login' ||
              path == '/syncing' ||
              path == '/')) {
        return '/today';
      }
      // 旧深链兼容：calendar/notes/mine 重定向到 AppShell 主入口
      // （tab 切换由 AppShell 内部 IndexedStack 处理，不走路由）。
      if (phase.stage == Phase1Stage.ready &&
          (path == '/calendar' || path == '/notes' || path == '/mine')) {
        return '/today';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/syncing',
        builder: (context, state) => const SyncingPage(),
      ),
      // 主入口：IndexedStack 四 tab 容器（今日/回看/笔记/我的），底部栏统一常驻。
      GoRoute(
        path: '/today',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final initial = switch (tab) {
            'calendar' => AppTab.calendar,
            'notes' => AppTab.notes,
            'mine' => AppTab.mine,
            _ => AppTab.today,
          };
          return AppShell(initialTab: initial);
        },
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) =>
            ReviewPage(date: state.uri.queryParameters['date']),
      ),
      GoRoute(
        path: '/notes/editor',
        builder: (context, state) =>
            NoteEditorPage(path: state.uri.queryParameters['path'] ?? ''),
      ),
      GoRoute(
        path: '/sync/conflicts',
        builder: (context, state) => const ConflictCenterPage(),
      ),
      GoRoute(
        path: '/debug/foundation',
        builder: (context, state) => const FoundationPage(),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
