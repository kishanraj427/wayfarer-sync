import 'package:flutter/material.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTokens.dart';

/// A single row in the profile's Trip History list: an icon tile, a
/// title/subtitle pair, and a chevron affordance for drilling into the trip.
class HistoryRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const HistoryRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Container(
                width: AppSpace.xl,
                height: AppSpace.xl,
                decoration: BoxDecoration(
                  color: context.semantic.activeContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.flight_takeoff,
                  color: context.semantic.onActiveContainer,
                  size: AppSpace.md,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(subtitle, style: textTheme.bodyMedium),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.semantic.hairline),
            ],
          ),
        ),
      ),
    );
  }
}
