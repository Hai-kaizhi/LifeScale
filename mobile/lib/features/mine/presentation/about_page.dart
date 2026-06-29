import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_providers.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';

/// 「关于」页：品牌信息 + 简介 + 用户协议 / 隐私政策 + 版本与版权。
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  /// 应用版本（与 pubspec.yaml version 对齐，避免引入 package_info_plus 依赖）。
  static const appVersion = '0.0.1';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
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
                // 品牌区
                GlassPanel(
                  tone: tone,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 28,
                  ),
                  child: Column(
                    children: [
                      LifeScaleLogoMark(
                        size: 72,
                        color: tokens.primary,
                        appIcon: true,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '人生刻度 LifeScale',
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '时间在流动，人生在刻度',
                        style: TextStyle(color: tokens.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '版本 $appVersion',
                          style: TextStyle(
                            color: tokens.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 简介
                _InfoCard(
                  tokens: tokens,
                  tone: tone,
                  icon: Icons.auto_stories_outlined,
                  title: '应用简介',
                  body: 'LifeScale 是一款本地优先的日程与笔记应用。今日重点、日程、快速记录、'
                      '复盘均以每日 Markdown 为单一事实来源，通过 Vault 在移动端、桌面端之间同步。\n\n'
                      '我们相信「专注当下，重视行动」——让每一天都成为人生的刻度。',
                ),
                const SizedBox(height: 14),
                // 用户协议
                _InfoCard(
                  tokens: tokens,
                  tone: tone,
                  icon: Icons.description_outlined,
                  title: '用户协议',
                  body: '欢迎使用 LifeScale。使用本应用即表示你同意以下条款：\n\n'
                      '1. 你对自己记录的所有内容拥有完全所有权，应用仅作为工具协助你管理时间与生活。\n'
                      '2. 请勿利用本应用从事任何违反法律法规的行为。\n'
                      '3. 本应用按「现状」提供，我们持续优化，但不对服务的绝对可用性作保证。\n'
                      '4. 如有疑问，可在「帮助与反馈」中与我们联系。',
                ),
                const SizedBox(height: 14),
                // 隐私政策
                _InfoCard(
                  tokens: tokens,
                  tone: tone,
                  icon: Icons.privacy_tip_outlined,
                  title: '隐私政策',
                  body: '我们高度重视你的隐私：\n\n'
                      '1. 本地优先：不登录时，所有数据仅保存在你的设备上，不会上传任何服务器。\n'
                      '2. 登录同步：仅当你主动登录后，你的内容才会在云端与你已授权的设备间同步，用于跨端流转。\n'
                      '3. 最小化收集：我们仅收集账号与设备标识等必要信息，不会读取或分析你的笔记内容。\n'
                      '4. 你的控制权：你可随时退出登录或删除数据，同步内容不会被用于其他用途。',
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    '© 2026 LifeScale · 本地优先，云同步',
                    style: TextStyle(color: tokens.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              '关于',
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
              Icon(icon, color: tokens.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
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
            body,
            style: TextStyle(color: tokens.muted, fontSize: 14, height: 1.7),
          ),
        ],
      ),
    );
  }
}
