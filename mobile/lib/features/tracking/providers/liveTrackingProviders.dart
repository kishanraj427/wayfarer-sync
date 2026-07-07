import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wayfarer_sync_mobile/features/tracking/models/realtimeEvent.dart';
import 'package:wayfarer_sync_mobile/features/tracking/services/trackingSocketService.dart';

/// Listens directly to the socket stream and filters for active location updates from others.
final liveLocationStreamProvider = StreamProvider.autoDispose.family<MemberLocationUpdate, String>((ref, tripId) async* {
  final socketService = ref.read(trackingSocketServiceProvider);
  
  // Open the connection when the provider turns on
  socketService.connect(tripId);
  
  // Ensure we drop the socket connection if the user exits the map screen
  ref.onDispose(() {
    socketService.disconnect();
  });

  // Yield filtered location objects down to the UI map layer
  await for (final message in socketService.messagesStream) {
    if (message is Map<String, dynamic> && message['type'] == 'member_location') {
      final payload = message['payload'] as Map<String, dynamic>;
      yield MemberLocationUpdate.fromJson(payload);
    }
  }
});