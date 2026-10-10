import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/aiko_colors.dart';

class AikoSparkleBackdrop extends StatelessWidget {
  const AikoSparkleBackdrop({this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _SparklePainter(),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class AikoWordmark extends StatelessWidget {
  const AikoWordmark({
    this.size = 54,
    this.alignment = MainAxisAlignment.center,
    super.key,
  });

  final double size;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aiko', // l10n-ignore
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: AikoColors.deepBlue,
            fontSize: size,
            fontWeight: FontWeight.w900,
            height: 0.95,
            letterSpacing: 0,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: size * 0.02, left: size * 0.02),
          child: Icon(
            Icons.auto_awesome,
            size: size * 0.25,
            color: AikoColors.deepBlue,
          ),
        ),
      ],
    );
  }
}

class AikoPrimaryButton extends StatelessWidget {
  const AikoPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w800),
    );
    final style = _buttonStyle(context);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: icon == null
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 20),
              label: child,
            ),
    );
  }

  ButtonStyle _buttonStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: AikoColors.deepBlue,
      foregroundColor: AikoColors.white,
      disabledBackgroundColor: scheme.outlineVariant,
      disabledForegroundColor: AikoColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()
      ..color = AikoColors.primaryBlue.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()
      ..color = AikoColors.softBlue.withValues(alpha: 0.34)
      ..style = PaintingStyle.fill;

    final circles = <Offset>[
      Offset(size.width * 0.1, size.height * 0.22),
      Offset(size.width * 0.9, size.height * 0.2),
      Offset(size.width * 0.16, size.height * 0.65),
      Offset(size.width * 0.82, size.height * 0.76),
    ];
    for (final point in circles) {
      canvas.drawCircle(point, 4, blue);
    }

    final dots = <Offset>[
      Offset(size.width * 0.18, size.height * 0.34),
      Offset(size.width * 0.72, size.height * 0.16),
      Offset(size.width * 0.88, size.height * 0.47),
      Offset(size.width * 0.12, size.height * 0.82),
      Offset(size.width * 0.68, size.height * 0.9),
    ];
    for (final point in dots) {
      canvas.drawCircle(point, 2.4, fill);
    }

    _drawDiamond(canvas, Offset(size.width * 0.86, size.height * 0.33), 12);
    _drawDiamond(canvas, Offset(size.width * 0.19, size.height * 0.5), 8);
    _drawDiamond(canvas, Offset(size.width * 0.74, size.height * 0.67), 7);
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = AikoColors.primaryBlue.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);

    final inner = Path()
      ..moveTo(center.dx, center.dy - radius * 0.45)
      ..lineTo(center.dx + radius * 0.45, center.dy)
      ..lineTo(center.dx, center.dy + radius * 0.45)
      ..lineTo(center.dx - radius * 0.45, center.dy)
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..color = AikoColors.primaryBlue.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

double clampIdeaWidth(BuildContext context) {
  return math.min(MediaQuery.sizeOf(context).width, 430);
}
