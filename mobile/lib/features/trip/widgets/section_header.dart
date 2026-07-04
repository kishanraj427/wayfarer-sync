import 'package:flutter/material.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTokens.dart';

class SectionHeader extends StatelessWidget {
  final String label;
  const SectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Text(label.toUpperCase(),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Divider(color: context.semantic.hairline)),
        ],
      ),
    );
  }
}
