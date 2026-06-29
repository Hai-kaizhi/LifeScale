import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_providers.dart';
import '../../../shared/constants/assets.dart';
import 'phase1_theme.dart';
import 'phase1_widgets.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 启动页跟随当前时段色调（不再写死 afternoon）。
    final tone = ref.watch(currentToneProvider);
    final tokens = Phase1Theme.of(tone);
    return ScenicScaffold(
      tone: tone,
      backgroundAsset: AppAssets.splashDayCycleBackground,
      overlayColors: const [
        Color(0x11FFFFFF),
        Color(0x00FFFFFF),
        Color(0x28FFFFFF),
      ],
      child: Column(
        children: [
          const Spacer(flex: 3),
          const BrandMark(
            appIcon: false,
            subtitle: '顺着一天的节律，完成计划、记录与沉淀',
            iconSize: 64,
            titleSize: 33,
          ),
          const SizedBox(height: 66),
          SizedBox(
            height: 108,
            width: double.infinity,
            child: CustomPaint(painter: _DayArcPainter()),
          ),
          const Spacer(flex: 4),
          const SizedBox(height: 20),
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: tokens.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '正在初始化本地缓存',
            style: TextStyle(
              color: tokens.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.62)
      ..quadraticBezierTo(size.width * 0.5, 0, size.width, size.height * 0.62);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.82);
    canvas.drawPath(path, paint);

    final labels = [
      (
        Offset(size.width * 0.12, size.height * 0.54),
        Icons.wb_sunny_outlined,
        '早晨',
      ),
      (
        Offset(size.width * 0.5, size.height * 0.16),
        Icons.light_mode_outlined,
        '下午',
      ),
      (
        Offset(size.width * 0.88, size.height * 0.54),
        Icons.nightlight_round,
        '夜晚',
      ),
    ];
    for (final item in labels) {
      final tp = TextPainter(
        text: TextSpan(
          text: item.$3,
          style: const TextStyle(
            color: Color(0xFF174EA6),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(item.$2.codePoint),
          style: TextStyle(
            fontFamily: item.$2.fontFamily,
            package: item.$2.fontPackage,
            color: item.$3 == '早晨'
                ? const Color(0xFFFF7A1A)
                : const Color(0xFF1D66F2),
            fontSize: 24,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(canvas, item.$1 - Offset(iconPainter.width / 2, 24));
      tp.paint(canvas, item.$1 + Offset(-tp.width / 2, 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
