import 'package:flutter/material.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTheme.dart';
import '../../../core/theme/appTokens.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  const StatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: monoData(context,
                size: 22, color: colorScheme.onSurface, weight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
