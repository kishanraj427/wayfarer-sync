import 'package:flutter/material.dart';
import '../theme/appSemanticColors.dart';
import '../theme/appTokens.dart';

/// Soft, route-tinted inline error used on forms — replaces raw red text.
class InlineErrorBanner extends StatelessWidget {
  final String message;
  const InlineErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: semantic.routeSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: semantic.route),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: semantic.route, size: 20),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(message, style: TextStyle(color: onSurface)),
          ),
        ],
      ),
    );
  }
}
