import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/phase1_models.dart';
import 'phase1_theme.dart';

class ScenicScaffold extends StatelessWidget {
  const ScenicScaffold({
    super.key,
    required this.tone,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 18),
    this.backgroundAsset,
    this.overlayColors,
    this.resizeToAvoidBottomInset,
  });

  final TodayTone tone;
  final Widget child;
  final EdgeInsets padding;
  final String? backgroundAsset;
  final List<Color>? overlayColors;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final tokens = Phase1Theme.of(tone);
    final asset = backgroundAsset ?? tokens.backgroundAsset;
    return Scaffold(
      backgroundColor: tokens.background.first,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tokens.background,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) =>
                    CustomPaint(painter: _ScenicPainter(tokens)),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: overlayColors ?? tokens.scrim,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.compact = false,
    this.dark = false,
    this.appIcon = true,
    this.title = '人生刻度 LifeScale',
    this.subtitle = '时间在流动，人生在刻度',
    this.iconSize,
    this.titleSize,
  });

  final bool compact;
  final bool dark;
  final bool appIcon;
  final String title;
  final String subtitle;
  final double? iconSize;
  final double? titleSize;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : const Color(0xFF0B2B70);
    final resolvedIconSize = iconSize ?? (compact ? 62.0 : 78.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LifeScaleLogoMark(
          size: resolvedIconSize,
          color: appIcon
              ? const Color(0xFF246BFF)
              : (dark ? Colors.white : const Color(0xFF0B2B70)),
          appIcon: appIcon,
        ),
        SizedBox(height: compact ? 12 : 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize ?? (compact ? 28 : 34),
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: color,
            height: 1.15,
          ),
        ),
        SizedBox(height: compact ? 7 : 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 14 : 15,
            color: color.withValues(alpha: dark ? 0.76 : 0.68),
            height: 1.4,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class WechatLoginButton extends StatelessWidget {
  const WechatLoginButton({
    super.key,
    required this.onTap,
    this.size = 54,
    this.semanticLabel,
  });

  final VoidCallback onTap;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.8),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Semantics(
          label: semanticLabel,
          button: true,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: CustomPaint(
                size: Size.square(size * 0.46),
                painter: _WechatPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LifeScaleLogoMark extends StatelessWidget {
  const LifeScaleLogoMark({
    super.key,
    required this.size,
    required this.color,
    this.appIcon = false,
  });

  final double size;
  final Color color;
  final bool appIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LifeScaleLogoPainter(color: color, appIcon: appIcon),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.tone,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final TodayTone tone;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tokens = Phase1Theme.of(tone);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.07),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ToneSegmentedControl extends StatelessWidget {
  const ToneSegmentedControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TodayTone value;
  final ValueChanged<TodayTone> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = Phase1Theme.of(value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Row(
        children: TodayTone.values.map((tone) {
          final selected = tone == value;
          final itemTokens = Phase1Theme.of(tone);
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tone),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                height: 34,
                decoration: BoxDecoration(
                  color: selected ? tokens.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  itemTokens.label,
                  style: TextStyle(
                    color: selected ? Colors.white : tokens.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 74,
    this.label,
  });

  final double progress;
  final Color color;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(progress: progress.clamp(0, 1), color: color),
          ),
          Text(
            label ?? '${(progress * 100).round()}%',
            style: TextStyle(
              fontSize: size * 0.24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class FutureActionButton extends StatelessWidget {
  const FutureActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: filled ? Colors.white : color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifeScaleLogoPainter extends CustomPainter {
  const _LifeScaleLogoPainter({required this.color, required this.appIcon});

  final Color color;
  final bool appIcon;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (appIcon) {
      final radius = size.width * 0.24;
      final bg = RRect.fromRectAndRadius(
        rect.deflate(1),
        Radius.circular(radius),
      );
      final shadow = Paint()
        ..color = const Color(0xFF1F6BFF).withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawRRect(bg.shift(Offset(0, size.height * 0.06)), shadow);
      canvas.drawRRect(
        bg,
        Paint()..color = Colors.white.withValues(alpha: 0.94),
      );
      canvas.drawRRect(
        bg,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.72),
      );
    }

    final center = Offset(size.width / 2, size.height / 2);
    final logoSize = appIcon ? size.width * 0.52 : size.width * 0.72;
    final stroke = logoSize * 0.13;
    final logoRect = Rect.fromCircle(center: center, radius: logoSize / 2);

    final arcPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = appIcon
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7CB7FF), Color(0xFF155BFF)],
            ).createShader(logoRect)
          : null
      ..color = color;
    canvas.drawArc(logoRect, math.pi * 0.18, math.pi * 1.46, false, arcPaint);

    final dotPaint = Paint()
      ..isAntiAlias = true
      ..color = appIcon ? const Color(0xFF155BFF) : color;
    canvas.drawCircle(
      Offset(center.dx + logoSize * 0.28, center.dy - logoSize * 0.24),
      logoSize * 0.13,
      dotPaint,
    );

    if (!appIcon) {
      final linePaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.52
        ..strokeCap = StrokeCap.square
        ..color = color;
      canvas.drawLine(
        Offset(center.dx, center.dy - logoSize * 0.56),
        Offset(center.dx, center.dy + logoSize * 0.36),
        linePaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy + logoSize * 0.54),
        Offset(center.dx, center.dy + logoSize * 0.68),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LifeScaleLogoPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.appIcon != appIcon;
}

class _WechatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final green = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFF21C45D);
    final white = Paint()
      ..isAntiAlias = true
      ..color = Colors.white;

    final back = Rect.fromLTWH(
      size.width * 0.03,
      size.height * 0.06,
      size.width * 0.64,
      size.height * 0.55,
    );
    canvas.drawOval(back, green);
    final backTail = Path()
      ..moveTo(size.width * 0.23, size.height * 0.55)
      ..lineTo(size.width * 0.16, size.height * 0.74)
      ..lineTo(size.width * 0.35, size.height * 0.61)
      ..close();
    canvas.drawPath(backTail, green);

    final front = Rect.fromLTWH(
      size.width * 0.31,
      size.height * 0.28,
      size.width * 0.66,
      size.height * 0.58,
    );
    canvas.drawOval(front, green);
    final frontTail = Path()
      ..moveTo(size.width * 0.72, size.height * 0.78)
      ..lineTo(size.width * 0.84, size.height)
      ..lineTo(size.width * 0.58, size.height * 0.83)
      ..close();
    canvas.drawPath(frontTail, green);

    canvas.drawCircle(
      Offset(size.width * 0.26, size.height * 0.27),
      2.4,
      white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.27),
      2.4,
      white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.52),
      2.6,
      white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.77, size.height * 0.52),
      2.6,
      white,
    );
  }

  @override
  bool shouldRepaint(covariant _WechatPainter oldDelegate) => false;
}

class _ScenicPainter extends CustomPainter {
  const _ScenicPainter(this.tokens);

  final Phase1ToneTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final horizon = size.height * (tokens.isDark ? 0.34 : 0.38);

    paint.color = tokens.secondary.withValues(alpha: tokens.isDark ? 0.18 : 0.26);
    canvas.drawCircle(
      Offset(size.width * 0.18, horizon - 34),
      tokens.isDark ? 24 : 36,
      paint,
    );

    paint.color = Colors.white.withValues(alpha: tokens.isDark ? 0.18 : 0.45);
    canvas.drawCircle(Offset(size.width * 0.76, horizon - 86), 20, paint);

    final mountain = Path()
      ..moveTo(0, horizon + 36)
      ..lineTo(size.width * 0.28, horizon - 8)
      ..lineTo(size.width * 0.48, horizon + 24)
      ..lineTo(size.width * 0.72, horizon - 28)
      ..lineTo(size.width, horizon + 8)
      ..lineTo(size.width, horizon + 80)
      ..lineTo(0, horizon + 80)
      ..close();
    paint.shader = LinearGradient(
      colors: [
        tokens.primary.withValues(alpha: tokens.isDark ? 0.22 : 0.18),
        tokens.secondary.withValues(alpha: tokens.isDark ? 0.24 : 0.12),
      ],
    ).createShader(Rect.fromLTWH(0, horizon - 40, size.width, 140));
    canvas.drawPath(mountain, paint);
    paint.shader = null;

    final water = Rect.fromLTWH(
      0,
      horizon + 62,
      size.width,
      size.height - horizon,
    );
    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        tokens.secondary.withValues(alpha: tokens.isDark ? 0.16 : 0.18),
        Colors.white.withValues(alpha: tokens.isDark ? 0.03 : 0.35),
      ],
    ).createShader(water);
    canvas.drawRect(water, paint);
    paint.shader = null;

    final arc = Path()
      ..moveTo(size.width * 0.08, size.height * 0.29)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.18,
        size.width * 0.92,
        size.height * 0.31,
      );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: tokens.isDark ? 0.34 : 0.72);
    canvas.drawPath(arc, paint);
    paint.style = PaintingStyle.fill;

    if (tokens.isDark) {
      paint.color = Colors.white.withValues(alpha: 0.52);
      for (var i = 0; i < 36; i++) {
        final x = (i * 47 % size.width.toInt()).toDouble();
        final y = 18 + (i * 31 % (horizon.toInt().clamp(80, 240))).toDouble();
        canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.2 : 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScenicPainter oldDelegate) =>
      oldDelegate.tokens != tokens;
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.12;
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.16);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, base);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, active);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
