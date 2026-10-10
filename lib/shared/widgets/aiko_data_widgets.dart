import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/aiko_colors.dart';
import '../../theme/aiko_status_colors.dart';

class AikoDetailScaffold extends StatelessWidget {
  const AikoDetailScaffold({
    required this.title,
    required this.children,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 112),
    this.bottomBar,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: ListView.separated(
        padding: padding,
        itemCount: children.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => children[index],
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: bottomBar!,
            ),
    );
  }
}

class AikoInlineNotice extends StatelessWidget {
  const AikoInlineNotice({
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome,
    this.accentColor = AikoColors.premiumPurple,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 12), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AikoMetricCard extends StatelessWidget {
  const AikoMetricCard({
    required this.label,
    required this.value,
    this.change,
    this.icon,
    this.accentColor = AikoColors.primaryBlue,
    this.progress,
    super.key,
  });

  final String label;
  final String value;
  final String? change;
  final IconData? icon;
  final Color accentColor;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: accentColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.headlineMedium),
            ),
            if (change != null) ...[
              const SizedBox(height: 4),
              Text(
                change!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AikoStatusColors.of(context).textFor(accentColor),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 12),
              _AikoProgressBar(value: progress!, color: accentColor),
            ],
          ],
        ),
      ),
    );
  }
}

class AikoMetricGrid extends StatelessWidget {
  const AikoMetricGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth < 520 ? 2 : 4;
        return GridView.count(
          crossAxisCount: count,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: constraints.maxWidth < 360 ? 1.05 : 1.25,
          children: children,
        );
      },
    );
  }
}

class _AikoProgressBar extends StatelessWidget {
  const _AikoProgressBar({
    required this.value,
    this.color = AikoColors.primaryBlue,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 8,
        color: color,
        backgroundColor: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class AikoDataListCard extends StatelessWidget {
  const AikoDataListCard({
    required this.title,
    required this.rows,
    this.icon,
    this.accentColor = AikoColors.primaryBlue,
    super.key,
  });

  final String title;
  final List<AikoDataRow> rows;
  final IconData? icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: accentColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class AikoDataRow extends StatelessWidget {
  const AikoDataRow({
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.color = AikoColors.primaryBlue,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ??
              Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AikoStatusColors.of(context).textFor(color),
                  fontWeight: FontWeight.w700,
                ),
              ),
        ],
      ),
    );
  }
}

class AikoDonutChart extends StatelessWidget {
  const AikoDonutChart({
    required this.values,
    required this.colors,
    this.centerLabel,
    super.key,
  });

  final List<double> values;
  final List<Color> colors;
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(168),
            painter: _DonutPainter(values: values, colors: colors),
          ),
          if (centerLabel != null)
            Text(
              centerLabel!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
        ],
      ),
    );
  }
}

class AikoGauge extends StatelessWidget {
  const AikoGauge({
    required this.value,
    required this.label,
    this.color = AikoColors.successGreen,
    super.key,
  });

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(220, 132),
            painter: _GaugePainter(
              value: value.clamp(0, 1),
              color: color,
              trackColor: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}%',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;

    final strokeWidth = 22.0;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    var start = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        start,
        sweep - 0.03,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 16.0;
    final rect = Rect.fromLTWH(16, 18, size.width - 32, size.height * 1.55);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = color;

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);
    canvas.drawArc(rect, math.pi, math.pi * value, false, valuePaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
