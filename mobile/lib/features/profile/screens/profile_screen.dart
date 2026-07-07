import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/appRoutes.dart';
import '../../../core/constants/appStrings.dart';
import '../../../core/network/authTokenProvider.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/theme/themeModeController.dart';
import '../../../core/util/name_monogram.dart';
import '../../../core/widgets/skeletonBox.dart';
import '../../auth/models/current_user.dart';
import '../../auth/providers/current_user_provider.dart';
import '../../trip/models/trip.dart';
import '../../trip/providers/trips_provider.dart';
import '../../trip/widgets/section_header.dart';
import '../../trip/widgets/stat_tile.dart';
import '../widgets/history_row.dart';
import '../widgets/setting_row.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final tripsAsync = ref.watch(tripsProvider);
    final userId = ref.watch(currentUserIdProvider) ?? 'unknown';
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final trips = tripsAsync.maybeWhen(
      data: (tripList) => tripList,
      orElse: () => const <Trip>[],
    );
    final activeTrips = trips.where((trip) => trip.isActive).toList();
    final endedTrips = trips.where((trip) => !trip.isActive).toList();
    final destinationCount =
        trips.fold<int>(0, (sum, trip) => sum + trip.destinations.length);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          _IdentitySection(currentUserAsync: currentUserAsync),
          const SizedBox(height: AppSpace.lg),
          const SectionHeader(label: AppStrings.travelSummary),
          Row(
            children: [
              Expanded(
                child: StatTile(label: AppStrings.statTrips, value: '${trips.length}'),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: StatTile(label: AppStrings.statActive, value: '${activeTrips.length}'),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: StatTile(label: AppStrings.statDestinations, value: '$destinationCount'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          const SectionHeader(label: AppStrings.tripHistory),
          if (endedTrips.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              child: Text(
                AppStrings.noPastTrips,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...endedTrips.map(
              (trip) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: HistoryRow(
                  title: trip.title,
                  subtitle: trip.startedAt == null
                      ? ''
                      : DateFormat('MMM d, yyyy').format(trip.startedAt!),
                  onTap: () => context.push(AppRoutes.tripMap(tripId: trip.id, userId: userId)),
                ),
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          const SectionHeader(label: AppStrings.account),
          SettingRow(
            icon: Icons.dark_mode_outlined,
            label: AppStrings.darkMode,
            trailing: Switch(
              value: isDark,
              onChanged: (value) => ref
                  .read(themeModeProvider.notifier)
                  .setMode(value ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          SettingRow(
            icon: Icons.logout,
            label: AppStrings.logOut,
            isDestructive: true,
            onTap: () => ref.read(authTokenProvider.notifier).clearToken(),
          ),
        ],
      ),
    );
  }
}

class _IdentitySection extends StatelessWidget {
  final AsyncValue<CurrentUser?> currentUserAsync;
  const _IdentitySection({required this.currentUserAsync});

  @override
  Widget build(BuildContext context) {
    return currentUserAsync.when(
      loading: () => const _IdentitySkeleton(),
      error: (error, stackTrace) => const _IdentityFallback(),
      data: (user) =>
          user == null ? const _IdentityFallback() : _IdentityContent(user: user),
    );
  }
}

class _IdentityContent extends StatelessWidget {
  final CurrentUser user;
  const _IdentityContent({required this.user});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final monogram = nameMonogram(
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
    );

    return Row(
      children: [
        CircleAvatar(
          radius: AppSpace.lg,
          backgroundColor: context.semantic.route,
          child: Text(
            monogram,
            style: textTheme.titleLarge?.copyWith(color: context.semantic.onRoute),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                user.email,
                style: textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityFallback extends StatelessWidget {
  const _IdentityFallback();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        CircleAvatar(
          radius: AppSpace.lg,
          backgroundColor: context.semantic.route,
          child: Text(
            '?',
            style: textTheme.titleLarge?.copyWith(color: context.semantic.onRoute),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(child: Text(AppStrings.guest, style: textTheme.headlineSmall)),
      ],
    );
  }
}

class _IdentitySkeleton extends StatelessWidget {
  const _IdentitySkeleton();

  static const double _avatarDiameter = AppSpace.lg * 2;
  static const double _nameLineHeight = AppSpace.lg - AppSpace.xs;
  static const double _nameLineWidth = AppSpace.xl * 5;
  static const double _emailLineHeight = AppSpace.md - AppSpace.xs;
  static const double _emailLineWidth = AppSpace.xl * 6;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SkeletonBox(
          height: _avatarDiameter,
          width: _avatarDiameter,
          radius: AppSpace.lg,
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(height: _nameLineHeight, width: _nameLineWidth),
              SizedBox(height: AppSpace.xs),
              SkeletonBox(height: _emailLineHeight, width: _emailLineWidth),
            ],
          ),
        ),
      ],
    );
  }
}
