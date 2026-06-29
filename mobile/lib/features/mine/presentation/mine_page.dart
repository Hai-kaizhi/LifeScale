import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/storage/prefs_store.dart';
import '../../../core/theme/theme_providers.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';

/// 本地资料 Provider：读写昵称（纯本地，无密码、无服务器）。
final localNicknameProvider =
    StateNotifierProvider<_NicknameNotifier, String>((ref) {
  final prefs = ref.watch(prefsStoreProvider);
  return _NicknameNotifier(prefs);
});

class _NicknameNotifier extends StateNotifier<String> {
  _NicknameNotifier(this._prefs) : super(_prefs.getNickname());

  final PrefsStore _prefs;

  Future<void> set(String name) async {
    final trimmed = name.trim();
    final value = trimmed.isEmpty ? '本地用户' : trimmed;
    state = value;
    await _prefs.setNickname(value);
  }
}

/// 「我的」页：本地资料、设置入口、帮助与支持（tab 式，底部导航）。
///
/// 开源本地版无账号/云同步：账号卡片改为本地资料（昵称，可编辑），
/// 私有版的登录/登出/同步状态入口随网络层一并移除。
class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  @override
  Widget build(BuildContext context) {
    // 时段色调跟随全局 ThemeController。
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
    final nickname = ref.watch(localNicknameProvider);
    // 当前主题选择（设置分组的「主题」项右侧展示用）。
    final choice = ref.watch(currentThemeChoiceProvider);

    return ScenicScaffold(
      tone: tone,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // 顶部标题
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: tokens.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '我的',
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              child: Column(
                children: [
                  // 本地资料卡片
                  _SectionCard(
                    tokens: tokens,
                    tone: tone,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: tokens.primary.withValues(
                              alpha: 0.16,
                            ),
                            child: Icon(
                              Icons.person,
                              color: tokens.primary,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nickname,
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '本地资料 · 数据仅存于本机',
                                  style: TextStyle(
                                    color: tokens.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _editNickname(context, tokens),
                          icon: Icon(Icons.edit_outlined,
                              color: tokens.primary, size: 18),
                          label: Text(
                            '编辑昵称',
                            style: TextStyle(color: tokens.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: tokens.primary.withValues(alpha: 0.3),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 设置（内联展开：主题）
                  _SectionLabel(tokens: tokens, text: '设置'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    tokens: tokens,
                    tone: tone,
                    children: [
                      _ActionRow(
                        tokens: tokens,
                        icon: Icons.palette_outlined,
                        label: '主题',
                        trailing: Text(
                          choice.label,
                          style: TextStyle(
                            color: tokens.muted,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () => context.push('/theme'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 帮助与支持
                  _SectionLabel(tokens: tokens, text: '帮助与支持'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    tokens: tokens,
                    tone: tone,
                    children: [
                      _ActionRow(
                        tokens: tokens,
                        icon: Icons.menu_book_outlined,
                        label: '使用说明',
                        onTap: () => context.push('/usage-guide'),
                      ),
                      _Divider(tokens: tokens),
                      _ActionRow(
                        tokens: tokens,
                        icon: Icons.support_agent,
                        label: '帮助与反馈',
                        onTap: () => context.push('/help-feedback'),
                      ),
                      _Divider(tokens: tokens),
                      _ActionRow(
                        tokens: tokens,
                        icon: Icons.info_outline,
                        label: '关于 LifeScale',
                        onTap: () => context.push('/about'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'LifeScale Mobile · 本地优先',
                      style: TextStyle(color: tokens.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNickname(
    BuildContext context,
    Phase1ToneTokens tokens,
  ) async {
    final controller =
        TextEditingController(text: ref.read(localNicknameProvider));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入你的昵称（仅保存在本机）',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      await ref.read(localNicknameProvider.notifier).set(result);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.tokens, required this.text});
  final Phase1ToneTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: TextStyle(
            color: tokens.muted,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.tokens,
    required this.tone,
    required this.children,
  });
  final Phase1ToneTokens tokens;
  final TodayTone tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      tone: tone,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final Phase1ToneTokens tokens;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: tokens.primary, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: tokens.text, fontSize: 15)),
            const Spacer(),
            if (trailing != null) trailing!,
            Icon(Icons.chevron_right, color: tokens.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.tokens});
  final Phase1ToneTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: tokens.muted.withValues(alpha: 0.16));
  }
}
