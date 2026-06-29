import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_providers.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';

/// 「主题」页：4 个主题预览卡片，点击放大全屏预览后选择应用。
///
/// 4 个主题（复用现有 3 套 ToneTokens）：
/// - 跟随时间（默认）：按当前小时推导
/// - 清新：afternoon 冷蓝
/// - 阳光：morning 暖橙
/// - 暗调：night 暗紫
class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
    final currentChoice = ref.watch(currentThemeChoiceProvider);
    return ScenicScaffold(
      tone: tone,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _Header(tokens: tokens),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    '选择你喜欢的主题，点击可放大预览',
                    style: TextStyle(color: tokens.muted, fontSize: 13),
                  ),
                ),
                for (final choice in ThemeChoice.values) ...[
                  _ThemeCard(
                    appTokens: tokens,
                    appTone: tone,
                    choice: choice,
                    selected: choice == currentChoice,
                    onTap: () => _showFullPreview(context, ref, choice),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 点击放大：全屏预览该主题，底部「使用此主题」应用。
  void _showFullPreview(
      BuildContext context, WidgetRef ref, ThemeChoice choice) {
    // 预览用该主题固定的 tone（auto 用当前时段）。
    final previewTone = choice.fixedTone ?? ToneTheme.toneForNow();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullPreviewPage(
          tone: previewTone,
          choice: choice,
          onApply: () {
            ref.read(themeControllerProvider.notifier).setChoice(choice);
            Navigator.of(context).pop();
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final t = Curves.easeOut.transform(animation.value);
          return Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tokens});
  final Phase1ToneTokens tokens;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 18, 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: tokens.text),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Text(
              '主题',
              style: TextStyle(
                color: tokens.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表中的主题卡片：左侧迷你预览 + 右侧名称/描述/选中态。
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.appTokens,
    required this.appTone,
    required this.choice,
    required this.selected,
    required this.onTap,
  });
  final Phase1ToneTokens appTokens; // 当前页 tokens（边框/标题用）
  final TodayTone appTone;
  final ThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  /// 预览所用 tone（auto → 当前时段；固定 → 对应 AppTone）。
  AppTone get previewTone =>
      choice.fixedTone ?? ToneTheme.toneForNow();

  String get _desc => switch (choice) {
        ThemeChoice.auto => '根据早晚自动切换色调',
        ThemeChoice.fresh => '清爽的冷蓝色调',
        ThemeChoice.sunshine => '温暖的阳光橙',
        ThemeChoice.dark => '护眼的暗色主题',
      };

  @override
  Widget build(BuildContext context) {
    final previewTone = this.previewTone;
    final previewTokens = ToneTheme.of(previewTone);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: GlassPanel(
          tone: appTone,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? appTokens.primary
                    : appTokens.cardBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // 迷你预览：背景渐变 + 示例文字 + 主色点
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: previewTokens.background,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: previewTokens.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 26,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: previewTokens.primary
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              width: 54,
                              height: 7,
                              decoration: BoxDecoration(
                                color: previewTokens.text.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 38,
                              height: 5,
                              decoration: BoxDecoration(
                                color: previewTokens.muted.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            choice.label,
                            style: TextStyle(
                              color: appTokens.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (choice.isAuto) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: appTokens.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '默认',
                                style: TextStyle(
                                  color: appTokens.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _desc,
                        style:
                            TextStyle(color: appTokens.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: appTokens.primary, size: 22)
                else
                  Icon(Icons.chevron_right, color: appTokens.muted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 全屏预览页：模拟今日页观感，底部「使用此主题」。
class _FullPreviewPage extends StatelessWidget {
  const _FullPreviewPage({
    required this.tone,
    required this.choice,
    required this.onApply,
  });
  final AppTone tone;
  final ThemeChoice choice;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final tokens = ToneTheme.of(tone);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: tokens.background,
                ),
              ),
              child: Column(
                children: [
                  // 顶部标题栏
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(18, 16, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: tokens.muted),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${choice.label} · 预览',
                          style: TextStyle(
                            color: tokens.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 模拟今日页内容：问候 + 卡片 + 列表项
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            choice.isAuto ? '早安' : choice.label,
                            style: TextStyle(
                              color: tokens.text,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '时间在流动，人生在刻度',
                            style: TextStyle(
                                color: tokens.muted, fontSize: 14),
                          ),
                          const SizedBox(height: 18),
                          _previewCard(tokens, title: '今日重点', body: '完成需求评审'),
                          const SizedBox(height: 12),
                          _previewCard(tokens, title: '日程', body: '09:00 团队站会'),
                          const SizedBox(height: 12),
                          _previewCard(tokens, title: '快速记录', body: '记下闪过的灵感'),
                          const SizedBox(height: 20),
                          // 主色按钮示意
                          FractionallySizedBox(
                            widthFactor: 1,
                            child: FilledButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.add),
                              label: const Text('新建'),
                              style: FilledButton.styleFrom(
                                backgroundColor: tokens.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 底部应用按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onApply,
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('使用此主题',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewCard(ToneTokens tokens,
      {required String title, required String body}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: tokens.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      color: tokens.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: tokens.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
