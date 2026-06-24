import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_status_controller.dart';
import '../../../core/theme/theme_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import '../../phase1/domain/phase1_models.dart';
import '../../phase1/presentation/phase1_controller.dart';
import '../../phase1/presentation/phase1_theme.dart';
import '../../phase1/presentation/phase1_widgets.dart';

/// 「我的」页：账号信息、设备与同步状态、设置入口（tab 式，底部导航）。
class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  @override
  void initState() {
    super.initState();
    // 进入页面刷新一次同步状态计数。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncStatusControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 时段色调跟随全局 ThemeController（不再写死 night）。
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
    final prefs = ref.watch(prefsStoreProvider);
    final auth = ref.watch(authControllerProvider);
    final isAuthenticated = auth.status == AuthStatus.authenticated;
    final user = auth.user;
    final deviceId = auth.deviceId ?? prefs.getOrCreateDeviceId();
    final cursor = prefs.getLastCursor();
    final syncStatus = ref.watch(syncStatusControllerProvider);
    final accountName = switch (auth.status) {
      AuthStatus.loading => '正在检查账号',
      AuthStatus.authenticated => user?.username ?? '云端用户',
      AuthStatus.local => '本地模式',
    };
    final accountSubtitle = switch (auth.status) {
      AuthStatus.loading => '正在恢复本地会话',
      AuthStatus.authenticated => user?.email ?? '已登录，云同步可用',
      AuthStatus.local => '不登录也可完整使用本地功能',
    };

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
                  // 账号卡片
                  _SectionCard(
                    tokens: tokens,
                    tone: tone,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: tokens.primary.withValues(
                              alpha: 0.16,
                            ),
                            child: Icon(
                              Icons.person,
                              color: tokens.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  accountName,
                                  style: TextStyle(
                                    color: tokens.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  accountSubtitle,
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
                      _Divider(tokens: tokens),
                      _ActionRow(
                        tokens: tokens,
                        icon: isAuthenticated
                            ? Icons.logout_outlined
                            : Icons.login_outlined,
                        label: isAuthenticated ? '退出登录' : '登录并开启云同步',
                        onTap: auth.status == AuthStatus.loading
                            ? () {}
                            : () {
                                if (isAuthenticated) {
                                  _logout(context);
                                } else {
                                  _showLoginSheet(context, tokens);
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 同步状态
                  _SectionLabel(tokens: tokens, text: '同步状态'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    tokens: tokens,
                    tone: tone,
                    children: [
                      _InfoRow(
                        tokens: tokens,
                        icon: Icons.devices_outlined,
                        label: '设备 ID',
                        value: _shortId(deviceId),
                      ),
                      _Divider(tokens: tokens),
                      _InfoRow(
                        tokens: tokens,
                        icon: Icons.cloud_done_outlined,
                        label: '同步游标',
                        value: cursor == null
                            ? '尚未同步'
                            : _shortId(cursor, head: 16),
                      ),
                      _Divider(tokens: tokens),
                      _InfoRow(
                        tokens: tokens,
                        icon: syncStatus.hasPending
                            ? Icons.cloud_upload_outlined
                            : Icons.cloud_done_outlined,
                        label: '待同步',
                        value: syncStatus.syncing
                            ? '同步中…'
                            : '${syncStatus.pendingCount} 条',
                        valueColor: syncStatus.hasPending
                            ? tokens.warning
                            : tokens.success,
                      ),
                      _Divider(tokens: tokens),
                      _ActionRow(
                        tokens: tokens,
                        icon: Icons.sync,
                        label: isAuthenticated
                            ? (syncStatus.syncing ? '同步中…' : '立即同步')
                            : '登录后同步云端',
                        onTap: syncStatus.syncing
                            ? () {}
                            : () => _flushNow(context),
                      ),
                      _Divider(tokens: tokens),
                      _ActionRow(
                        tokens: tokens,
                        icon: Icons.warning_amber_rounded,
                        iconColor: syncStatus.hasConflict
                            ? tokens.error
                            : tokens.muted,
                        label: '冲突处理',
                        trailing: syncStatus.hasConflict
                            ? _countBadge(
                                tokens,
                                '${syncStatus.conflictCount}',
                                tokens.error,
                              )
                            : null,
                        onTap: () => context.push('/sync/conflicts'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 设置入口
                  _SectionLabel(tokens: tokens, text: '设置'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    tokens: tokens,
                    tone: tone,
                    children: [
                      _ActionRow(
                        tokens: tokens,
                        icon: Icons.info_outline,
                        label: '关于 LifeScale',
                        onTap: () => _showAbout(context, tokens),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'LifeScale Mobile · 本地优先，云同步',
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

  String _shortId(String id, {int head = 10}) {
    if (id.length <= head * 2) return id;
    return '${id.substring(0, head)}…${id.substring(id.length - 6)}';
  }

  /// 阶段九：手动触发补推所有 dirty 记录。
  Future<void> _flushNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!ref.read(cloudSyncEnabledProvider)) {
      messenger
        ?..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('登录后可开启云同步，本地内容已保存在设备上')));
      return;
    }
    ref.read(syncStatusControllerProvider.notifier).setSyncing(true);
    try {
      final engine = ref.read(syncEngineProvider);
      final result = await engine.flushPending();
      await ref.read(syncStatusControllerProvider.notifier).refresh();
      if (!mounted) return;
      final msg = result.skipped
          ? '同步进行中…'
          : result.hadActivity
          ? '已同步 ${result.pushed} 条${result.conflicts > 0 ? '，${result.conflicts} 条冲突待处理' : ''}'
          : '没有待同步内容';
      messenger
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
        );
    } finally {
      ref.read(syncStatusControllerProvider.notifier).setSyncing(false);
    }
  }

  Future<void> _showLoginSheet(
    BuildContext context,
    Phase1ToneTokens tokens,
  ) async {
    final loggedIn = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: tokens.isDark ? const Color(0xFF11102A) : tokens.card,
      builder: (context) => _LoginSheet(tokens: tokens),
    );
    if (!mounted || loggedIn != true) return;
    await _runLoginSync(context);
  }

  Future<void> _runLoginSync(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    ref.read(syncStatusControllerProvider.notifier).setSyncing(true);
    try {
      await ref.read(phase1ControllerProvider.notifier).runInitialSync();
      await ref.read(syncStatusControllerProvider.notifier).refresh();
      if (!mounted) return;
      final phase = ref.read(phase1ControllerProvider);
      final failed = phase.error != null && phase.error!.isNotEmpty;
      messenger
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(failed ? '已登录，本地可用，云同步稍后重试' : '已登录，云同步已开启'),
            duration: const Duration(seconds: 2),
          ),
        );
    } finally {
      ref.read(syncStatusControllerProvider.notifier).setSyncing(false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await ref.read(authControllerProvider.notifier).logout();
    await ref.read(syncStatusControllerProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('已退出登录，继续使用本地模式'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  /// 计数徽标（冲突数量等）。
  Widget _countBadge(Phase1ToneTokens tokens, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _showAbout(BuildContext context, Phase1ToneTokens tokens) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于 LifeScale'),
        content: const Text(
          'LifeScale 是一款本地优先的日程与笔记应用。\n\n'
          '今日重点、日程、快速记录、复盘均以每日 Markdown 为单一事实来源，'
          '通过 Vault 与桌面端、知识库同步。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('知道了', style: TextStyle(color: tokens.primary)),
          ),
        ],
      ),
    );
  }
}

class _LoginSheet extends ConsumerStatefulWidget {
  const _LoginSheet({required this.tokens});

  final Phase1ToneTokens tokens;

  @override
  ConsumerState<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<_LoginSheet> {
  final _usernameController = TextEditingController(text: 'lifescale');
  final _passwordController = TextEditingController(text: 'lifescale');
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入账号和密码');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await ref
        .read(authControllerProvider.notifier)
        .login(username, password);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync_outlined, color: tokens.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '登录并开启云同步',
                    style: TextStyle(
                      color: tokens.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _usernameController,
              enabled: !_submitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '账号',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: !_submitting,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_submitting) {
                  _submit();
                }
              },
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: tokens.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(_submitting ? '登录中…' : '登录'),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final Phase1ToneTokens tokens;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: tokens.muted, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: tokens.text, fontSize: 15)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: valueColor ?? tokens.muted,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.trailing,
  });
  final Phase1ToneTokens tokens;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
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
            Icon(icon, color: iconColor ?? tokens.primary, size: 20),
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
