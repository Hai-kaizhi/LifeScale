import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_providers.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';

/// 「使用说明」页：本地静态内容，分节介绍 LifeScale 的核心用法。
class UsageGuidePage extends ConsumerWidget {
  const UsageGuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
    return ScenicScaffold(
      tone: tone,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _GuideHeader(tokens: tokens, title: '使用说明'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
              children: [
                Text(
                  'LifeScale 围绕「每天」组织你的生活，把日程、记录与复盘统一在一份每日文档里。下面是几个核心概念。',
                  style: TextStyle(color: tokens.muted, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 16),
                _Section(
                  tokens: tokens,
                  tone: tone,
                  icon: Icons.flag_outlined,
                  title: '今日重点',
                  body: '每天设定 1~3 件最重要的事，让注意力聚焦。在「今日」页顶部即可编辑，'
                      '它是你这一天的主线，不会被繁杂任务淹没。',
                ),
                const SizedBox(height: 14),
                _Section(
                  tokens: tokens,
                  tone: tone,
                  icon: Icons.event_note_outlined,
                  title: '日程',
                  body: '日程分为「任务」和「时间记录」两类。任务可标记完成；时间记录用于如实留痕。'
                      '日程按时段排列，支持工作 / 生活两种分类，帮你平衡一天的节奏。',
                ),
                const SizedBox(height: 14),
                _Section(
                  tokens: tokens,
                  tone: tone,
                  icon: Icons.bolt_outlined,
                  title: '快速记录',
                  body: '灵感、想法、待办碎片，随手记下即可。快速记录不占用日程位，'
                      '留出当天思路，沉淀后再整理进日程或笔记。',
                ),
                const SizedBox(height: 14),
                _Section(
                  tokens: tokens,
                  tone: tone,
                  icon: Icons.insights_outlined,
                  title: '复盘',
                  body: '每天结束时，针对几个固定问题做轻量复盘。坚持下去，你会在「回看」里'
                      '看到自己的变化轨迹——人生在刻度。',
                ),
                const SizedBox(height: 14),
                _Section(
                  tokens: tokens,
                  tone: tone,
                  icon: Icons.cloud_sync_outlined,
                  title: '云同步与多端',
                  body: '登录后即可在桌面端、移动端之间同步。所有内容以每日 Markdown 为单一事实来源，'
                      '本地优先，离线也能完整使用；联网后自动补推同步。',
                ),
                const SizedBox(height: 14),
                _Section(
                  tokens: tokens,
                  tone: tone,
                  icon: Icons.shield_outlined,
                  title: '本地优先',
                  body: '不登录也能完整使用所有功能，数据安全保存在你的设备上。登录只是为了让内容'
                      '跨设备流转，你的记录始终掌握在自己手中。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 全屏内容页通用顶栏：返回 + 标题。
class _GuideHeader extends StatelessWidget {
  const _GuideHeader({required this.tokens, required this.title});
  final Phase1ToneTokens tokens;
  final String title;

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
              title,
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

/// 一节说明卡片：图标标题 + 正文。
class _Section extends StatelessWidget {
  const _Section({
    required this.tokens,
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
  });
  final Phase1ToneTokens tokens;
  final TodayTone tone;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      tone: tone,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tokens.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(color: tokens.muted, fontSize: 14, height: 1.65),
          ),
        ],
      ),
    );
  }
}
