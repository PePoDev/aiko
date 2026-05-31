import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/aiko_colors.dart';

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
                      color: AikoColors.mutedText,
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
                      color: AikoColors.mutedText,
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
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 12),
              AikoProgressBar(value: progress!, color: accentColor),
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

class AikoProgressBar extends StatelessWidget {
  const AikoProgressBar({
    required this.value,
    this.color = AikoColors.primaryBlue,
    this.height = 8,
    super.key,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        color: color,
        backgroundColor: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class AikoProgressRow extends StatelessWidget {
  const AikoProgressRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    this.color = AikoColors.primaryBlue,
    super.key,
  });

  final String label;
  final String valueLabel;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                valueLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AikoProgressBar(value: value, color: color),
        ],
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
                      color: AikoColors.mutedText,
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
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
        ],
      ),
    );
  }
}

class AikoMiniBarChart extends StatelessWidget {
  const AikoMiniBarChart({
    required this.values,
    this.color = AikoColors.primaryBlue,
    super.key,
  });

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: CustomPaint(
        painter: _BarChartPainter(
          values: values,
          color: color,
          trackColor: Theme.of(context).colorScheme.outlineVariant,
        ),
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

class AikoSankeyPreview extends StatelessWidget {
  const AikoSankeyPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: CustomPaint(
        painter: _SankeyPainter(
          colors: const [
            AikoColors.primaryBlue,
            AikoColors.warningOrange,
            AikoColors.successGreen,
            AikoColors.premiumPurple,
            AikoColors.dangerRed,
          ],
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.values,
    required this.color,
    required this.trackColor,
  });

  final List<double> values;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max).clamp(1, double.infinity);
    final gap = 4.0;
    final width = (size.width - gap * (values.length - 1)) / values.length;
    final trackPaint = Paint()..color = trackColor;
    final barPaint = Paint()..color = color;

    for (var i = 0; i < values.length; i++) {
      final left = i * (width + gap);
      final track = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, width, size.height),
        const Radius.circular(4),
      );
      final barHeight = size.height * (values[i] / maxValue);
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - barHeight, width, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(track, trackPaint);
      canvas.drawRRect(bar, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
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

class _SankeyPainter extends CustomPainter {
  const _SankeyPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final source = Rect.fromLTWH(0, size.height * 0.28, 54, size.height * 0.44);
    final targets = [
      Rect.fromLTWH(size.width - 56, 18, 56, 32),
      Rect.fromLTWH(size.width - 56, 62, 56, 32),
      Rect.fromLTWH(size.width - 56, 106, 56, 32),
      Rect.fromLTWH(size.width - 56, 150, 56, 32),
      Rect.fromLTWH(size.width - 56, 194, 56, 26),
    ];
    final blockPaint = Paint()
      ..color = AikoColors.primaryBlue.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(source, const Radius.circular(8)),
      blockPaint,
    );

    for (var i = 0; i < targets.length; i++) {
      final targetPaint = Paint()..color = colors[i].withValues(alpha: 0.18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(targets[i], const Radius.circular(8)),
        targetPaint,
      );
      final path = Path()
        ..moveTo(source.right, source.top + source.height * (0.15 + i * 0.17))
        ..cubicTo(
          size.width * 0.35,
          source.top + i * 16,
          size.width * 0.55,
          targets[i].center.dy,
          targets[i].left,
          targets[i].center.dy,
        );
      final flowPaint = Paint()
        ..color = colors[i].withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12.0 - i
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, flowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SankeyPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
