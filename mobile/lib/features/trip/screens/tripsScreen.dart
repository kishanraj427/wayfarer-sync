import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/appRoutes.dart';
import '../../../core/constants/appStrings.dart';
import '../../../core/network/authTokenProvider.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/util/text_input_rules.dart';
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

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  bool _searching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);
    final userId = ref.watch(currentUserIdProvider) ?? 'unknown';

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                inputFormatters: inputRules(),
                decoration: const InputDecoration(
                  hintText: AppStrings.searchTrips,
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : const Text(AppStrings.myTrips),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _query = '';
                _searchController.clear();
              }
            }),
          ),
        ],
      ),
      body: tripsAsync.when(
        loading: () => _SkeletonList(),
        error: (error, _) => _ErrorView(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.read(tripsProvider.notifier).refresh(),
        ),
        data: (trips) {
          final active = trips.where((trip) => trip.isActive).toList();
          final query = _query.trim().toLowerCase();
          final visible = query.isEmpty
              ? active
              : active
                  .where((trip) =>
                      trip.title.toLowerCase().contains(query) ||
                      (trip.primaryDestination?.name.toLowerCase().contains(query) ??
                          false))
                  .toList();
          if (active.isEmpty) {
            return _EmptyView(onCreate: () => context.push(AppRoutes.createTrip));
          }
          if (visible.isEmpty) {
            return _NoMatchView(query: _query);
          }
          return _Dashboard(trips: active, visible: visible, userId: userId, ref: ref);
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'join',
            onPressed: () => _showJoinDialog(context, ref, userId),
            tooltip: AppStrings.joinTripTooltip,
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: AppSpace.md),
          FloatingActionButton.extended(
            heroTag: 'create',
            onPressed: () => context.push(AppRoutes.createTrip),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.newTrip),
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
        context.push(AppRoutes.tripMap(tripId: tripId, userId: userId));
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text(AppStrings.joinedTripSuccess)),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.failedToJoinTrip(error))),
      );
    }
  }
}

class _Dashboard extends StatelessWidget {
  final List<Trip> trips;
  final List<Trip> visible;
  final String userId;
  final WidgetRef ref;
  const _Dashboard({
    required this.trips,
    required this.visible,
    required this.userId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
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
              Expanded(child: StatTile(label: AppStrings.statActive, value: '${trips.length}')),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: StatTile(label: AppStrings.statTravelers, value: '$travelers')),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: StatTile(label: AppStrings.statDestinations, value: '$destinations')),
            ],
          ),
          const SectionHeader(label: AppStrings.activeTripsHeader),
          ...visible.map((trip) => _cardFor(context, trip)),
        ],
      ),
    );
  }

  Widget _cardFor(BuildContext context, Trip trip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: TripDashboardCard(
        trip: trip,
        onOpen: () => context.push(
          AppRoutes.tripMap(tripId: trip.id, userId: userId),
          extra: trip.title,
        ),
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
        title: const Text(AppStrings.endTripDialogTitle),
        content: const Text(AppStrings.endTripDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.endTrip),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(tripsProvider.notifier).endTrip(trip.id);
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.tripEnded)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(AppStrings.failedToEndTrip(error))));
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
            PrimaryButton(label: AppStrings.retry, icon: Icons.refresh, onPressed: onRetry),
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
              Text(AppStrings.noTripsYet, style: textTheme.headlineSmall),
              const SizedBox(height: AppSpace.sm),
              Text(
                AppStrings.emptyTripsPrompt,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.lg),
              PrimaryButton(label: AppStrings.startATrip, icon: Icons.add, onPressed: onCreate),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMatchView extends StatelessWidget {
  final String query;
  const _NoMatchView({required this.query});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: context.semantic.route),
            const SizedBox(height: AppSpace.md),
            Text(
              AppStrings.noTripsMatch(query),
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: context.semantic.route,
            child: Icon(Icons.group_add, color: context.semantic.onRoute),
          ),
          const SizedBox(height: AppSpace.md),
          Text(AppStrings.joinTripTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.xs),
          Text(
            AppStrings.joinTripPrompt,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _controller,
            inputFormatters: inputRules(),
            decoration: const InputDecoration(
              labelText: AppStrings.tripIdLabel,
              prefixIcon: Icon(Icons.key),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final tripId = _controller.text.trim();
            if (tripId.isNotEmpty) {
              Navigator.of(context).pop();
              widget.onJoin(tripId);
            }
          },
          child: const Text(AppStrings.join),
        ),
      ],
    );
  }
}
