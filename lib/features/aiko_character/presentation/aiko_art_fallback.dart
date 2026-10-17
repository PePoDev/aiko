import 'package:flutter/material.dart';

import '../../../theme/aiko_colors.dart';

/// Stands in for Aiko's art when an image can't load (on the web, one that
/// wasn't downloaded before going offline), so her place on screen is never
/// left empty. Needs no assets of its own.
class AikoArtFallback extends StatelessWidget {
  const AikoArtFallback({this.size, super.key});

  /// Diameter; fills the space it is given when null.
  final double? size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AikoColors.premiumPurple, AikoColors.primaryBlue],
          ),
        ),
        child: FractionallySizedBox(
          widthFactor: 0.5,
          heightFactor: 0.5,
          child: FittedBox(
            child: Icon(Icons.face_retouching_natural, color: AikoColors.white),
          ),
        ),
      ),
    );
  }
}
