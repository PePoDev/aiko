import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/aiko_colors.dart';

class AikoAvatar extends StatelessWidget {
  const AikoAvatar({
    super.key,
    this.size = 32,
    this.pulse = false,
    this.borderColor,
  });

  final double size;
  final bool pulse;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ringColor =
        borderColor ?? AikoColors.primaryBlue.withValues(alpha: 0.18);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: pulse ? 1.06 : 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AikoColors.premiumPurple, AikoColors.primaryBlue],
              ),
              border: Border.all(color: ringColor, width: 1),
              boxShadow: pulse
                  ? [
                      BoxShadow(
                        color: AikoColors.premiumPurple.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            padding: EdgeInsets.all(size * 0.22),
            child: child,
          ),
        );
      },
      child: SvgPicture.asset(
        'assets/icons/aiko_aiko.svg',
        colorFilter: const ColorFilter.mode(AikoColors.white, BlendMode.srcIn),
        placeholderBuilder: (_) => const Icon(
          Icons.face_retouching_natural,
          color: AikoColors.white,
          size: 16,
        ),
      ),
    );
  }
}
