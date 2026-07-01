import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/apiUrl.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/network/authTokenProvider.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/widgets/contourBackground.dart';
import '../../../core/widgets/inlineErrorBanner.dart';
import '../../../core/widgets/primaryButton.dart';
import '../../../core/widgets/skeletonBox.dart';
import '../../../core/widgets/tripTicketCard.dart';
import '../services/tripShare.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  List<dynamic> _trips = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get(ApiUrl.trips);
      if (mounted) {
        setState(() {
          _trips = response as List<dynamic>;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiException) {
            _errorMessage = e.message;
          } else {
            _errorMessage = e.toString().replaceFirst('Exception: ', '');
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinTrip(String tripId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post(ApiUrl.joinTrip(tripId), {});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined trip.')),
        );
        _fetchTrips();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is ApiException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join trip: $errorMsg')),
        );
      }
    }
  }

  void _showJoinTripDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Trip'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Trip ID (UUID)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _joinTrip(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
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
      body: _buildBody(userId),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'join',
            onPressed: _showJoinTripDialog,
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

  Widget _buildBody(String userId) {
    if (_isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpace.md),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
        itemBuilder: (context, index) =>
            const SkeletonBox(height: 84, radius: AppRadius.md),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InlineErrorBanner(message: _errorMessage!),
              const SizedBox(height: AppSpace.md),
              PrimaryButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: _fetchTrips,
              ),
            ],
          ),
        ),
      );
    }

    if (_trips.isEmpty) {
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
                PrimaryButton(
                  label: 'Start a trip',
                  icon: Icons.add,
                  onPressed: () => context.push('/create-trip'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTrips,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.md),
        itemCount: _trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
        itemBuilder: (context, index) {
          final trip = _trips[index];
          final tripId = trip['id'] as String;
          final title = trip['title'] as String? ?? 'Unnamed trip';
          return _FadeInItem(
            index: index,
            child: TripTicketCard(
              title: title,
              tripId: tripId,
              memberColors: const [],
              onTap: () => context.push('/trip/$tripId/map/$userId'),
              onShare: () => shareTrip(tripId: tripId, title: title),
            ),
          );
        },
      ),
    );
  }
}

/// Entrance animation for list items — a short fade + rise, disabled under
/// the platform reduce-motion setting.
class _FadeInItem extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeInItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + index * 40),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
