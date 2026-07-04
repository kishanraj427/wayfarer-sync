import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTheme.dart';
import '../../../core/theme/appTokens.dart';
import '../models/trip.dart';
import 'member_avatar_cluster.dart';
import 'status_pill.dart';

class TripDashboardCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onEnd;

  const TripDashboardCard({
    super.key,
    required this.trip,
    required this.onOpen,
    required this.onShare,
    required this.onEnd,
  });

  Color _memberColor(BuildContext context, String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return context.semantic.peerFallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final destination = trip.primaryDestination;
    final memberColors = trip.members
        .map((member) => _memberColor(context, member.color))
        .toList();
    final startText = trip.startedAt == null
        ? ''
        : DateFormat('MMM d').format(trip.startedAt!);

    return Opacity(
      opacity: trip.isActive ? 1.0 : 0.6,
      child: Card(
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.title,
                        style: textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (startText.isNotEmpty)
                      Text(startText, style: monoData(context, size: 11)),

                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'share') onShare();
                        if (value == 'end') onEnd();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'share',
                          child: Text('Share'),
                        ),
                        if (trip.isActive)
                          const PopupMenuItem(
                            value: 'end',
                            child: Text('End trip'),
                          ),
                      ],
                    ),
                  ],
                ),
                if (destination != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: context.semantic.destinationPin,
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(
                        child: Text(
                          destination.name,
                          style: textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpace.sm),
                const SizedBox(height: AppSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: MemberAvatarCluster(
                        colors: memberColors,
                        total: trip.memberCount,
                      ),
                    ),
                    StatusPill(isActive: trip.isActive),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
