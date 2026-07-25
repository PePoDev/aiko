import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/aiko_colors.dart';
import '../../domain/daily_spending_reaction.dart';

extension DailySpendingReactionPresentation on DailySpendingReaction {
  Color get color => switch (this) {
    DailySpendingReaction.comfortable => AikoColors.successGreen,
    DailySpendingReaction.caution => AikoColors.warningOrange,
    DailySpendingReaction.exceeded => AikoColors.dangerRed,
  };

  String get title => switch (this) {
    DailySpendingReaction.comfortable => "You're spending comfortably",
    DailySpendingReaction.caution => "You're close to today's limit",
    DailySpendingReaction.exceeded => "Today's safe amount is used up",
  };

  String get message => switch (this) {
    DailySpendingReaction.comfortable =>
      "Nice work—today's spending is in a healthy range.",
    DailySpendingReaction.caution =>
      'Aiko is a little worried—take care with the next expense.',
    DailySpendingReaction.exceeded =>
      'Aiko wants you to pause before spending more.',
  };

  String get semanticsLabel => switch (this) {
    DailySpendingReaction.comfortable => 'Aiko is smiling',
    DailySpendingReaction.caution => 'Aiko looks worried',
    DailySpendingReaction.exceeded => 'Aiko looks angry',
  };
}

class AikoSpendingReactionStrip extends StatelessWidget {
  const AikoSpendingReactionStrip({required this.reaction, super.key});

  final DailySpendingReaction reaction;

  @override
  Widget build(BuildContext context) {
    final color = reaction.color;
    return Container(
      key: ValueKey('aiko-reaction-${reaction.name}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            label: reaction.semanticsLabel,
            image: true,
            child: ExcludeSemantics(
              child: CustomPaint(
                size: const Size.square(52),
                painter: _AikoReactionPainter(reaction: reaction, color: color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reaction.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reaction.message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AikoReactionPainter extends CustomPainter {
  const _AikoReactionPainter({required this.reaction, required this.color});

  final DailySpendingReaction reaction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 52;
    Offset point(double x, double y) => Offset(x * scale, y * scale);

    final backdrop = Paint()..color = color.withValues(alpha: 0.14);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final features = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(point(26, 26), 25 * scale, backdrop);
    canvas.drawCircle(point(26, 26), 24 * scale, outline);
    canvas.drawOval(
      Rect.fromCenter(
        center: point(26, 28),
        width: 30 * scale,
        height: 34 * scale,
      ),
      outline,
    );
    canvas.drawLine(point(18, 12), point(14, 6), outline);
    canvas.drawLine(point(34, 12), point(38, 6), outline);

    switch (reaction) {
      case DailySpendingReaction.comfortable:
        canvas.drawCircle(point(21, 24), 1.3 * scale, features);
        canvas.drawCircle(point(31, 24), 1.3 * scale, features);
        final smile = Path()
          ..moveTo(point(20, 31).dx, point(20, 31).dy)
          ..quadraticBezierTo(
            point(26, 36).dx,
            point(26, 36).dy,
            point(32, 31).dx,
            point(32, 31).dy,
          );
        canvas.drawPath(smile, outline);
        break;
      case DailySpendingReaction.caution:
        canvas.drawLine(point(19, 22), point(23, 21), outline);
        canvas.drawLine(point(29, 21), point(33, 22), outline);
        canvas.drawCircle(point(21, 25), 1.2 * scale, features);
        canvas.drawCircle(point(31, 25), 1.2 * scale, features);
        final worried = Path()
          ..moveTo(point(21, 34).dx, point(21, 34).dy)
          ..quadraticBezierTo(
            point(26, 30).dx,
            point(26, 30).dy,
            point(31, 34).dx,
            point(31, 34).dy,
          );
        canvas.drawPath(worried, outline);
        break;
      case DailySpendingReaction.exceeded:
        canvas.drawLine(point(18, 20), point(23, 22), outline);
        canvas.drawLine(point(34, 20), point(29, 22), outline);
        canvas.drawCircle(point(21, 25), 1.2 * scale, features);
        canvas.drawCircle(point(31, 25), 1.2 * scale, features);
        final angry = Path()
          ..moveTo(point(20, 35).dx, point(20, 35).dy)
          ..quadraticBezierTo(
            point(26, 29).dx,
            point(26, 29).dy,
            point(32, 35).dx,
            point(32, 35).dy,
          );
        canvas.drawPath(angry, outline);
        break;
    }

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, scale);
    canvas.drawArc(
      Rect.fromCircle(center: point(26, 26), radius: 21 * scale),
      math.pi * 1.05,
      math.pi * 0.35,
      false,
      highlight,
    );
  }

  @override
  bool shouldRepaint(covariant _AikoReactionPainter oldDelegate) =>
      reaction != oldDelegate.reaction || color != oldDelegate.color;
}
