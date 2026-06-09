import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

      // When transitioning from offline (or unknown/none) to online, run synchronization
      if (isOnline && !wasOnline) {
        ref.read(syncServiceProvider).synchronizeAll();
      }
    }
  });
});
