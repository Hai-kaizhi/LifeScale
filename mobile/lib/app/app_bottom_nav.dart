import 'package:flutter/material.dart';

import '../core/theme/tone_tokens.dart';

/// App 主底部导航。4 个 tab：今日 / 回看 / 笔记 / 我的，居中统一「+」创建按钮。
///
/// 由 [AppShell] 作为 `bottomNavigationBar` 渲染，随 IndexedStack 切换高亮当前 tab，
/// 永不消失。高度紧凑（约 64），适合单手操作。
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.tokens,
    required this.current,
    this.onCreate,
  });

  final ToneTokens tokens;
  final AppTab current;
  final VoidCallback? onCreate; // 中央「+」按钮回调

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      decoration: BoxDecoration(
        color: tokens.bottomNav,
        border: Border(top: BorderSide(color: tokens.bottomNavBorder)),
      ),
      child: Row(
        children: [
          Expanded(child: _tab(context, AppTab.today)),
          Expanded(child: _tab(context, AppTab.calendar)),
          _createButton,
          Expanded(child: _tab(context, AppTab.notes)),
          Expanded(child: _tab(context, AppTab.mine)),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, AppTab tab) {
    final active = tab == current;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTapTab(context, tab),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tab.icon,
            size: 22,
            color: active ? tokens.primary : tokens.muted,
          ),
          const SizedBox(height: 2),
          Text(
            tab.label,
            style: TextStyle(
              color: active ? tokens.primary : tokens.muted,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget get _createButton {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onCreate,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.primary,
            boxShadow: [
              BoxShadow(
                color: tokens.primary.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  void _onTapTab(BuildContext context, AppTab tab) {
    // 由顶层 AppNavScope 拦截切换；若未注册 scope 则忽略。
    AppNavScope.maybeOfContext(context)?.switchTo(tab);
  }
}

/// App 主 tab。
enum AppTab {
  today('今日', Icons.check_box_outlined),
  calendar('回看', Icons.calendar_month_outlined),
  notes('笔记', Icons.menu_book_outlined),
  mine('我的', Icons.person_outline);

  const AppTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 供 AppBottomNav 向上通知 tab 切换的作用域（由 AppShell 注入）。
class AppNavScope extends InheritedWidget {
  const AppNavScope({
    super.key,
    required this.switchTo,
    required super.child,
  });

  final void Function(AppTab tab) switchTo;

  static AppNavScope? maybeOfContext(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppNavScope>();
  }

  @override
  bool updateShouldNotify(AppNavScope oldWidget) =>
      switchTo != oldWidget.switchTo;
}
