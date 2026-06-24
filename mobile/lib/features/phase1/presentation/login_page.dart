import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/assets.dart';
import 'phase1_controller.dart';
import 'phase1_widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userCtrl = TextEditingController(text: 'lifescale');
  final _passCtrl = TextEditingController(text: 'lifescale');
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phase1ControllerProvider);
    ref.listen(phase1ControllerProvider, (_, next) {
      final message = next.error ?? next.info;
      if (message == null || message.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    return _LoginScaffold(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom -
                26,
          ),
          child: Column(
            children: [
              const SizedBox(height: 36),
              const BrandMark(
                compact: true,
                appIcon: true,
                subtitle: '时间在流动，人生在刻度',
                iconSize: 70,
                titleSize: 28,
              ),
              const SizedBox(height: 34),
              _LoginCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '欢迎回到人生刻度',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _LoginPalette.title,
                        fontWeight: FontWeight.w800,
                        fontSize: 25,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '同步你的 Daily、记录和复盘',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _LoginPalette.subtitle,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _LoginField(
                      controller: _userCtrl,
                      icon: Icons.mail_outline,
                      hint: '邮箱 / 手机号',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    _LoginField(
                      controller: _passCtrl,
                      icon: Icons.lock_outline,
                      hint: '密码 / 验证码',
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      trailing: IconButton(
                        splashRadius: 22,
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _LoginPalette.icon,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LoginPrimaryButton(
                      pending: state.loginPending,
                      onPressed: state.loginPending
                          ? null
                          : () => ref
                                .read(phase1ControllerProvider.notifier)
                                .loginAndSync(
                                  _userCtrl.text.trim(),
                                  _passCtrl.text,
                                ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => ref
                          .read(phase1ControllerProvider.notifier)
                          .showFutureFeature('创建账号'),
                      style: TextButton.styleFrom(
                        foregroundColor: _LoginPalette.primary,
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('还没有账号？ 创建账号'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: _LoginPalette.divider),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '或',
                            style: TextStyle(
                              color: _LoginPalette.subtitle,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: _LoginPalette.divider),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _WechatAuthButton(
                          semanticLabel: '微信登录',
                          onTap: () => ref
                              .read(phase1ControllerProvider.notifier)
                              .showFutureFeature('微信登录'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _LoginTrustLine(),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class _LoginPalette {
  static const pageFallback = Color(0xFFEAF4FF);
  static const title = Color(0xFF0B2B70);
  static const body = Color(0xFF14213D);
  static const subtitle = Color(0xFF64748B);
  static const hint = Color(0xFF7A879B);
  static const icon = Color(0xFF7C83B7);
  static const iconSurface = Color(0xFFF1F5FF);
  static const field = Color(0xFFFBFCFF);
  static const fieldBorder = Color(0xFFE4E8F2);
  static const divider = Color(0xFFD9E0EF);
  static const primary = Color(0xFF6D5DFB);
  static const primaryDark = Color(0xFF3157E8);
  static const cardShadow = Color(0x33213B72);
}

class _LoginScaffold extends StatelessWidget {
  const _LoginScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LoginPalette.pageFallback,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppAssets.loginDayCycleBackground,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99FFFFFF),
                    Color(0x33F3F8FF),
                    Color(0xCCDFEAFF),
                  ],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.82),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: _LoginPalette.cardShadow,
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LoginField extends StatefulWidget {
  const _LoginField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscureText = false,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscureText;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 60,
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      decoration: BoxDecoration(
        color: _LoginPalette.field,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? _LoginPalette.primary : _LoginPalette.fieldBorder,
          width: focused ? 1.5 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: _LoginPalette.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _LoginPalette.iconSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon, color: _LoginPalette.icon, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: widget.controller,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              style: const TextStyle(
                color: _LoginPalette.body,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              cursorColor: _LoginPalette.primary,
              decoration: InputDecoration.collapsed(
                hintText: widget.hint,
                hintStyle: const TextStyle(
                  color: _LoginPalette.hint,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 4),
            SizedBox(width: 44, height: 44, child: widget.trailing),
          ] else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _LoginPrimaryButton extends StatelessWidget {
  const _LoginPrimaryButton({required this.pending, required this.onPressed});

  final bool pending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !pending;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled || pending ? 1 : 0.58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_LoginPalette.primaryDark, _LoginPalette.primary],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _LoginPalette.primary.withValues(alpha: 0.24),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 56,
              child: Center(
                child: pending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '登录并同步',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WechatAuthButton extends StatelessWidget {
  const _WechatAuthButton({required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return WechatLoginButton(
      size: 58,
      semanticLabel: semanticLabel,
      onTap: onTap,
    );
  }
}

class _LoginTrustLine extends StatelessWidget {
  const _LoginTrustLine();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_sync_outlined,
              color: _LoginPalette.primaryDark,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              '本地优先 · 云端同步 · Markdown 资产',
              style: TextStyle(
                color: _LoginPalette.subtitle,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
