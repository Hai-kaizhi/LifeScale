import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync/connectivity_controller.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_status_controller.dart';
import '../core/theme/theme_providers.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/calendar/presentation/calendar_page.dart';
import '../features/calendar/presentation/calendar_controller.dart';
import '../features/mine/presentation/mine_page.dart';
import '../features/notes/presentation/notes_page.dart';
import '../features/today/presentation/today_page.dart';
import '../features/today/presentation/today_controller.dart';
import 'app_bottom_nav.dart';

/// App 主容器：IndexedStack 承载四个 tab 页（常驻不销毁），
/// 底部栏由本组件统一渲染、永不消失。
///
/// 切换 tab 仅改变 IndexedStack 索引，不重建页面、不重复调接口；
/// 每个 tab 页各自管理自己的加载态（首次进入显示「加载中」）。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.initialTab = AppTab.today});

  final AppTab initialTab;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  late int _index = widget.initialTab.index;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // 阶段九：回前台时自动补推断网期间累积的 dirty 记录。
    if (lifecycle == AppLifecycleState.resumed) {
      _flushPendingSafe();
    }
  }

  /// 安全补推：触发 connectivity controller 的补推调度，并刷新同步状态计数。
  Future<void> _flushPendingSafe() async {
    if (!ref.read(cloudSyncEnabledProvider)) return;
    try {
      await ref.read(connectivityControllerProvider.notifier).triggerFlush();
      await ref.read(syncEngineProvider).flushPending();
      await ref.read(syncStatusControllerProvider.notifier).refresh();
    } catch (_) {
      // 补推失败静默，下次触发重试。
    }
  }

  void _switchTo(AppTab tab) {
    if (tab.index == _index) return;
    setState(() => _index = tab.index);
  }

  void _onCreate() {
    // 中央「+」创建按钮：按当前 tab 分发到对应创建入口。
    switch (AppTab.values[_index]) {
      case AppTab.today:
        // 今日：触发创建菜单信号（TodayPage 监听此 provider）。
        final n = ref.read(todayCreateSignalProvider);
        n.value = n.value + 1;
      case AppTab.notes:
        final n = ref.read(notesCreateSignalProvider);
        n.value = n.value + 1;
      case AppTab.calendar:
        // 回看：不跳转，停留在当前页。
        // 必须先选中某天，否则提示；选中则在当前页针对该日弹出日程编辑。
        final selected = ref.read(calendarControllerProvider).selectedDate;
        if (selected == null) {
          _showTip('请先选择某一天');
          return;
        }
        // 把今日页日期切到选中日（编辑写入该日 Daily），但保持当前 tab 不变，
        // 由 CalendarPage 监听 calendarCreateSignalProvider 在本页弹出日程编辑。
        ref.read(todayControllerProvider.notifier).changeDate(selected);
        final n = ref.read(calendarCreateSignalProvider);
        n.value = n.value + 1;
      case AppTab.mine:
        // 我的：直接跳今日页并弹出创建选项。
        setState(() => _index = AppTab.today.index);
        final n = ref.read(todayCreateSignalProvider);
        n.value = n.value + 1;
    }
  }

  /// 轻量提示（按当前色调着色，不依赖 BuildContext 取色以避免 tab 切换竞争）。
  void _showTip(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // 底部栏与容器背景跟随当前时段 tone（全局统一，不再写死 night）。
    final tokens = ref.watch(currentTokensProvider);
    return AppNavScope(
      switchTo: _switchTo,
      child: Scaffold(
        backgroundColor: tokens.background.isNotEmpty
            ? tokens.background[0]
            : tokens.card,
        body: IndexedStack(
          index: _index,
          children: const [
            TodayPage(),
            CalendarPage(),
            NotesPage(),
            MinePage(),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          tokens: tokens,
          current: AppTab.values[_index],
          onCreate: _onCreate,
        ),
      ),
    );
  }
}

/// 全局创建信号：今日页监听变化以打开创建菜单（IndexedStack 子页无法直接
/// 拿到 AppShell 回调，用 riverpod provider 传递）。
final todayCreateSignalProvider = ChangeNotifierProvider<ValueNotifier<int>>(
  (ref) => ValueNotifier<int>(0),
);

/// 全局创建信号（笔记页用）。
final notesCreateSignalProvider = ChangeNotifierProvider<ValueNotifier<int>>(
  (ref) => ValueNotifier<int>(0),
);

/// 全局创建信号（回看页用）：在当前页针对选中日弹出日程编辑。
final calendarCreateSignalProvider = ChangeNotifierProvider<ValueNotifier<int>>(
  (ref) => ValueNotifier<int>(0),
);
