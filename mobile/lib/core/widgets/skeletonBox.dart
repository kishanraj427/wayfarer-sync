import 'package:flutter/material.dart';
import '../theme/appTokens.dart';

/// A softly pulsing placeholder for load states. Uses a theme surface tone and
/// respects the platform reduce-motion setting (holds a static tone instead).
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = AppRadius.sm,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = reduceMotion ? 1.0 : 0.5 + (_controller.value * 0.5);
        return Opacity(
          opacity: opacity,
          child: Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}
