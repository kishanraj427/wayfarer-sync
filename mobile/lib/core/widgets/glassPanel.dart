import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/appSemanticColors.dart';
import '../theme/appTokens.dart';

/// Translucent, blurred, hairline-bordered surface used for floating map
/// controls and the peer rail. Fill/stroke are theme-aware via [context.semantic].
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.sm),
    this.radius = AppRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: semantic.glassFill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: semantic.glassStroke),
          ),
          child: child,
        ),
      ),
    );
  }
}
