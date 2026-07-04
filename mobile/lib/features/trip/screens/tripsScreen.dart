import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/authTokenProvider.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/widgets/contourBackground.dart';
import '../../../core/widgets/inlineErrorBanner.dart';
import '../../../core/widgets/primaryButton.dart';
import '../../../core/widgets/skeletonBox.dart';
import '../models/trip.dart';
import '../providers/trips_provider.dart';
import '../services/tripShare.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_tile.dart';
import '../widgets/trip_dashboard_card.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripsProvider);
    final userId = ref.watch(currentUserIdProvider) ?? 'unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authTokenProvider.notifier).clearToken(),
          ),
        ],
      ),
      body: tripsAsync.when(
        loading: () => _SkeletonList(),
        error: (error, _) => _ErrorView(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.read(tripsProvider.notifier).refresh(),
        ),
        data: (trips) => trips.isEmpty
            ? _EmptyView(onCreate: () => context.push('/create-trip'))
            : _Dashboard(trips: trips, userId: userId, ref: ref),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'join',
            onPressed: () => _showJoinDialog(context, ref, userId),
            tooltip: 'Join trip',
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: AppSpace.md),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () => context.push('/create-trip'),
            icon: const Icon(Icons.add),
            label: const Text('New trip'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context, WidgetRef ref, String userId) {
    showDialog(
      context: context,
      builder: (dialogContext) => _JoinTripDialog(
        onJoin: (tripId) => _joinTrip(context, ref, tripId, userId),
      ),
    );
  }

  Future<void> _joinTrip(
      BuildContext context, WidgetRef ref, String tripId, String userId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(tripsProvider.notifier).join(tripId);
      if (!context.mounted) return;
      if (result.alreadyMember) {
        context.push('/trip/$tripId/map/$userId');
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Joined trip. Open it to start tracking.')),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to join trip: $error')),
      );
    }
  }
}

class _Dashboard extends StatelessWidget {
  final List<Trip> trips;
  final String userId;
  final WidgetRef ref;
  const _Dashboard({required this.trips, required this.userId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final active = trips.where((trip) => trip.isActive).toList();
    final ended = trips.where((trip) => !trip.isActive).toList();
    final travelers = trips.fold<int>(0, (sum, trip) => sum + trip.memberCount);
    final destinations =
        trips.fold<int>(0, (sum, trip) => sum + trip.destinations.length);

    return RefreshIndicator(
      onRefresh: () => ref.read(tripsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          Row(
            children: [
              Expanded(child: StatTile(label: 'Active', value: '${active.length}')),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: StatTile(label: 'Travelers', value: '$travelers')),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: StatTile(label: 'Dest.', value: '$destinations')),
            ],
          ),
          if (active.isNotEmpty) ...[
            const SectionHeader(label: 'Active'),
            ...active.map((trip) => _cardFor(context, trip)),
          ],
          if (ended.isNotEmpty) ...[
            const SectionHeader(label: 'Ended'),
            ...ended.map((trip) => _cardFor(context, trip)),
          ],
        ],
      ),
    );
  }

  Widget _cardFor(BuildContext context, Trip trip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: TripDashboardCard(
        trip: trip,
        onOpen: () => context.push('/trip/${trip.id}/map/$userId'),
        onShare: () => shareTrip(tripId: trip.id, title: trip.title),
        onEnd: () => _confirmEnd(context, trip),
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context, Trip trip) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End this trip?'),
        content: const Text('Live tracking will stop for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End trip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(tripsProvider.notifier).endTrip(trip.id);
      messenger.showSnackBar(const SnackBar(content: Text('Trip ended.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to end trip: $error')));
    }
  }
}

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.md),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
      itemBuilder: (context, index) =>
          const SkeletonBox(height: 120, radius: AppRadius.md),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InlineErrorBanner(message: message),
            const SizedBox(height: AppSpace.md),
            PrimaryButton(label: 'Retry', icon: Icons.refresh, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyView({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ContourBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: context.semantic.route),
              const SizedBox(height: AppSpace.md),
              Text('No trips yet', style: textTheme.headlineSmall),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Start a trip and share the ID so your people can join.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.lg),
              PrimaryButton(label: 'Start a trip', icon: Icons.add, onPressed: onCreate),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinTripDialog extends StatefulWidget {
  final Future<void> Function(String tripId) onJoin;
  const _JoinTripDialog({required this.onJoin});

  @override
  State<_JoinTripDialog> createState() => _JoinTripDialogState();
}

class _JoinTripDialogState extends State<_JoinTripDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join trip'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(labelText: 'Trip ID (UUID)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final tripId = _controller.text.trim();
            if (tripId.isNotEmpty) {
              Navigator.of(context).pop();
              widget.onJoin(tripId);
            }
          },
          child: const Text('Join'),
        ),
      ],
    );
  }
}
