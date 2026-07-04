import 'package:flutter/material.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTokens.dart';

class StatusPill extends StatelessWidget {
  final bool isActive;
  const StatusPill({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dotColor =
        isActive ? context.semantic.signalOnline : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpace.xs),
          Text(isActive ? 'Active' : 'Ended',
              style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
