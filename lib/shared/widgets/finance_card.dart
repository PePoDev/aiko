import 'package:flutter/material.dart';

import '../../theme/aiko_colors.dart';

class FinanceCard extends StatefulWidget {
  const FinanceCard({
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.accentColor,
    this.prominent = false,
    this.onTap,
    super.key,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final Color? accentColor;
  final bool prominent;
  final VoidCallback? onTap;

  @override
  State<FinanceCard> createState() => _FinanceCardState();
}

class _FinanceCardState extends State<FinanceCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = widget.accentColor ?? colorScheme.primary;

    final content = Padding(
      padding: EdgeInsets.all(widget.prominent ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.icon != null) ...[
                _CardIcon(icon: widget.icon!, color: accent),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 12),
                Flexible(child: widget.trailing!),
              ],
            ],
          ),
          SizedBox(height: widget.prominent ? 16 : 12),
          DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium,
            child: widget.child,
          ),
        ],
      ),
    );

    return Semantics(
      button: widget.onTap != null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: _hovered && widget.onTap != null ? 1.01 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: _hovered && widget.onTap != null
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Card(
              child: widget.onTap == null
                  ? content
                  : InkWell(onTap: widget.onTap, child: content),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
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
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class AmountText extends StatelessWidget {
  const AmountText(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.headlineLarge,
      overflow: TextOverflow.visible,
      softWrap: true,
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: onTap != null,
      label: label,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
        title: Text(label),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right, color: AikoColors.mutedText),
        onTap: onTap,
      ),
    );
  }
}
