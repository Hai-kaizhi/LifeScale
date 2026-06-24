import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_providers.dart';
import '../../../shared/constants/assets.dart';
import '../domain/phase1_models.dart';
import 'phase1_controller.dart';
import 'phase1_theme.dart';
import 'phase1_widgets.dart';

class SyncingPage extends ConsumerWidget {
  const SyncingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(phase1ControllerProvider);
    // 时段色调跟随全局 ThemeController（不再写死 afternoon）。
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
    final completed = state.steps
        .where((step) => step.status == SyncStepStatus.success)
        .length;
    final progress = completed / state.steps.length;

    return ScenicScaffold(
      tone: tone,
      backgroundAsset: AppAssets.loginDayCycleBackground,
      child: Column(
        children: [
          const SizedBox(height: 32),
          const BrandMark(
            compact: true,
            appIcon: false,
            subtitle: '同步 Daily、Vault 和本地缓存',
            iconSize: 56,
            titleSize: 27,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: 268,
            height: 268,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const _SyncOrbitVisual(size: 260),
                ProgressRing(
                  progress: progress,
                  color: tokens.primary,
                  size: 218,
                  label: '',
                ),
                Container(
                  width: 152,
                  height: 152,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.68),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.primary.withValues(alpha: 0.16),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.syncPending
                            ? Icons.cloud_sync_outlined
                            : Icons.check_circle,
                        color: tokens.primary,
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        state.syncPending ? '正在同步你的\n今日刻度' : '同步状态\n待确认',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tokens.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            tone: tone,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Column(
              children: [
                for (var i = 0; i < state.steps.length; i++) ...[
                  _StepTile(step: state.steps[i], tokens: tokens),
                  if (i != state.steps.length - 1)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 2,
                        height: 18,
                        margin: const EdgeInsets.only(left: 17),
                        color: tokens.primary.withValues(alpha: 0.2),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const Spacer(),
          if (state.error != null) ...[
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: state.syncPending
                ? null
                : () => ref
                      .read(phase1ControllerProvider.notifier)
                      .runInitialSync(),
            icon: const Icon(Icons.refresh),
            label: Text(state.syncPending ? '请稍候' : '重试同步'),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '请稍候，马上进入今天',
            style: TextStyle(color: tokens.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.tokens});

  final SyncStepView step;
  final Phase1ToneTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.status) {
      SyncStepStatus.pending => tokens.muted,
      SyncStepStatus.running => tokens.primary,
      SyncStepStatus.success => tokens.success,
      SyncStepStatus.error => tokens.error,
    };
    final icon = switch (step.status) {
      SyncStepStatus.pending => Icons.radio_button_unchecked,
      SyncStepStatus.running => Icons.sync,
      SyncStepStatus.success => Icons.check_circle,
      SyncStepStatus.error => Icons.error,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: TextStyle(
                  color: tokens.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                step.message ?? step.description,
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyncOrbitVisual extends StatelessWidget {
  const _SyncOrbitVisual({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SyncOrbitPainter()),
    );
  }
}

class _SyncOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    final orbitRect = Rect.fromCircle(center: center, radius: radius);

    final glowPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7BB6FF).withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(orbitRect, math.pi * 0.68, math.pi * 1.24, false, glowPaint);

    final activePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.72);
    canvas.drawArc(
      orbitRect,
      math.pi * 0.66,
      math.pi * 1.24,
      false,
      activePaint,
    );

    final dashPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF73A9F8).withValues(alpha: 0.5);
    const dashCount = 28;
    for (var i = 0; i < dashCount; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / dashCount;
      final inner = Offset(
        center.dx + math.cos(angle) * radius * 0.72,
        center.dy + math.sin(angle) * radius * 0.72,
      );
      final outer = Offset(
        center.dx + math.cos(angle) * radius * 0.82,
        center.dy + math.sin(angle) * radius * 0.82,
      );
      canvas.drawLine(inner, outer, dashPaint);
    }

    _drawSun(
      canvas,
      Offset(center.dx - radius * 0.86, center.dy - radius * 0.82),
    );
    _drawMoon(
      canvas,
      Offset(center.dx + radius * 0.86, center.dy + radius * 0.82),
    );
  }

  void _drawSun(Canvas canvas, Offset center) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFFF8A1C);
    canvas.drawCircle(center, 8, paint);
    final rayPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF8A1C);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        center + Offset(math.cos(angle) * 14, math.sin(angle) * 14),
        center + Offset(math.cos(angle) * 20, math.sin(angle) * 20),
        rayPaint,
      );
    }
  }

  void _drawMoon(Canvas canvas, Offset center) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFF2367F4);
    canvas.drawCircle(center, 11, paint);
    canvas.drawCircle(
      center + const Offset(5, -4),
      11,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _SyncOrbitPainter oldDelegate) => false;
}
