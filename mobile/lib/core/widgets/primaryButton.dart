import 'package:flutter/material.dart';
import '../theme/appTokens.dart';

/// Full-width primary action with a subtle press-scale, inline loading state,
/// and optional leading icon. Colours come from the theme's button style.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (widget.onPressed == null || widget.loading) return;
    setState(() => _scale = pressed ? 0.97 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.loading;
    final onRoute = Theme.of(context).colorScheme.onPrimary;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isDisabled ? null : widget.onPressed,
            child: widget.loading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: onRoute),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18),
                        const SizedBox(width: AppSpace.sm),
                      ],
                      Text(widget.label),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
