import 'package:flutter/material.dart';
import '../theme/appSemanticColors.dart';
import '../theme/appTheme.dart';
import '../theme/appTokens.dart';

/// Dashboard "ticket" for a trip: title in the display face, the trip id in the
/// mono signature face, an optional member colour cluster, and a share action.
class TripTicketCard extends StatelessWidget {
  final String title;
  final String tripId;
  final List<Color> memberColors;
  final VoidCallback onTap;
  final VoidCallback onShare;

  const TripTicketCard({
    super.key,
    required this.title,
    required this.tripId,
    required this.memberColors,
    required this.onTap,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final colorScheme = Theme.of(context).colorScheme;
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.route, color: semantic.route, size: 22),
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
                    Text(
                      tripId,
                      style: monoData(context, size: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (memberColors.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.sm),
                      _MemberDots(colors: memberColors),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share trip',
                onPressed: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberDots extends StatelessWidget {
  final List<Color> colors;
  const _MemberDots({required this.colors});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final shown = colors.take(4).toList();
    return SizedBox(
      height: 18,
      child: Stack(
        children: [
          for (var index = 0; index < shown.length; index++)
            Positioned(
              left: index * 12.0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: shown[index],
                  shape: BoxShape.circle,
                  border: Border.all(color: surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
