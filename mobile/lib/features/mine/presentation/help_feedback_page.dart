import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_providers.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';

/// 「帮助与反馈」页（开源本地版）：常见问题 + 项目指引。
///
/// 私有版在此提交云端反馈并查看官方回复；开源版无后端，改为：
/// - 常见问题（本地优先说明）。
/// - 指引到项目的 Issue 渠道（GitHub/Gitee）反馈。
class HelpFeedbackPage extends ConsumerWidget {
  const HelpFeedbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
    return ScenicScaffold(
      tone: tone,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _Header(tokens: tokens, title: '帮助与反馈'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
              children: [
                _FaqSection(tokens: tokens, tone: tone),
                const SizedBox(height: 18),
                _FeedbackGuide(tokens: tokens, tone: tone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶栏：返回 + 标题。
class _Header extends StatelessWidget {
  const _Header({required this.tokens, required this.title});
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

/// 常见问题。
class _FaqSection extends StatelessWidget {
  const _FaqSection({required this.tokens, required this.tone});
  final Phase1ToneTokens tokens;
  final TodayTone tone;

  static const _items = <(String, String)>[
    (
      '数据保存在哪里？',
      'LifeScale 是本地优先应用，所有内容（日程、快速记录、复盘、笔记）都保存在你的设备本地，不上传任何服务器。',
    ),
    (
      '数据会丢失吗？',
      '不会。结构化数据存于本地数据库，每日沉淀为 Markdown 归档；本地优先存储，绝不丢数据。建议定期备份应用数据目录。',
    ),
    (
      '能在多台设备间同步吗？',
      '开源本地版不支持云同步。每台设备独立运行、独立存储。如需多端同步，请关注项目的完整版本。',
    ),
    (
      '附件（图片）怎么处理？',
      '图片按内容哈希缓存在本地数据目录，仅在本地可见。删除笔记不会自动清理未被引用的附件缓存。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      tone: tone,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '常见问题',
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          ..._items.map(
            (it) => ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: tokens.primary,
              collapsedIconColor: tokens.muted,
              title: Text(
                it.$1,
                style: TextStyle(color: tokens.text, fontSize: 15),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              children: [
                Text(
                  it.$2,
                  style: TextStyle(color: tokens.muted, fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 反馈指引：到项目 Issue 渠道反馈。
class _FeedbackGuide extends StatelessWidget {
  const _FeedbackGuide({required this.tokens, required this.tone});
  final Phase1ToneTokens tokens;
  final TodayTone tone;

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
              Icon(Icons.edit_note, color: tokens.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                '反馈与建议',
                style: TextStyle(
                  color: tokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '开源本地版不内置反馈通道。欢迎到项目仓库提交 Issue 反馈问题或建议：',
            style: TextStyle(color: tokens.muted, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}
