import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/status_line.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';
import 'foundation_controller.dart';

/// 第 0 步验收页（单页，Material，无视觉优化）。
/// 四个分区对应四个验收闸门：登录 / 注册设备 / 调用 /vault/changes / 缓存 Markdown。
class FoundationPage extends ConsumerStatefulWidget {
  const FoundationPage({super.key});

  @override
  ConsumerState<FoundationPage> createState() => _FoundationPageState();
}

class _FoundationPageState extends ConsumerState<FoundationPage> {
  final _userCtrl = TextEditingController(text: 'lifescale');
  final _passCtrl = TextEditingController(text: 'lifescale');

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(foundationControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final authed = auth.status == AuthStatus.authenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('LifeScale 移动端 · 第 0 步')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StatusLine(),
          const SizedBox(height: 24),
          _section(context, '① 登录（获取 token）', [
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(labelText: '用户名'),
            ),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: f.busy
                  ? null
                  : () => ref
                        .read(foundationControllerProvider.notifier)
                        .login(_userCtrl.text.trim(), _passCtrl.text),
              child: const Text('登录'),
            ),
            _result(f.loginMessage),
          ]),
          _section(context, '② 注册设备', [
            ElevatedButton(
              onPressed: (!authed || f.busy)
                  ? null
                  : () => ref
                        .read(foundationControllerProvider.notifier)
                        .registerDevice(),
              child: const Text('注册设备'),
            ),
            _result(f.deviceMessage),
          ]),
          _section(context, '③ 调用 /api/vault/changes', [
            ElevatedButton(
              onPressed: (!authed || f.busy)
                  ? null
                  : () => ref
                        .read(foundationControllerProvider.notifier)
                        .callChanges(),
              child: const Text('调用 /vault/changes'),
            ),
            _result(f.changesMessage),
          ]),
          _section(context, '④ 缓存示例 Markdown 到本地', [
            ElevatedButton(
              onPressed: f.busy
                  ? null
                  : () => ref
                        .read(foundationControllerProvider.notifier)
                        .cacheSample(),
              child: const Text('缓存示例 Markdown'),
            ),
            _result(f.cacheMessage),
          ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _result(String message) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
        ),
        child: SelectableText(
          message,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
