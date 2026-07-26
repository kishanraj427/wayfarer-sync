import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/authTokenProvider.dart';
import '../../../core/network/refreshCoordinator.dart';
import '../services/syncService.dart';

/// Exposes the real-time connectivity status stream
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// A notifier/listener provider that reacts to connectivity status changes
/// and triggers a sync of unsynced path points when online connectivity resumes.
final connectivitySyncListenerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityStreamProvider, (previous, next) {
    if (next is AsyncData<List<ConnectivityResult>>) {
      final currentResults = next.value;
      
      final isOnline = currentResults.any((result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn);
      
      final wasOnline = previous?.value?.any((result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn) ?? false;

      // On offline->online transitions, renew credentials first (most likely expired
      // while offline) then sync. Renewal failure is always retryLater (R1), so sync
      // still runs either way.
      if (isOnline && !wasOnline) {
        final session = ref.read(authSessionProvider);
        if (session.isAuthenticated) {
          final coordinator = ref.read(refreshCoordinatorProvider);
          final renew = session.needsExchange
              ? coordinator.exchange()
              : coordinator.refresh();
          renew
              .then((_) => ref.read(syncServiceProvider).synchronizeAll())
              .catchError((_) => ref.read(syncServiceProvider).synchronizeAll());
        } else {
          ref.read(syncServiceProvider).synchronizeAll();
        }
      }
    }
  });
});
