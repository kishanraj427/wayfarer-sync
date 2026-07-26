import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wayfarer_sync_mobile/features/tracking/models/realtimeEvent.dart';
import 'package:wayfarer_sync_mobile/features/tracking/services/trackingSocketService.dart';

const String _msgTypeField = 'type';
const String _msgPayloadField = 'payload';
const String _msgMemberLocation = 'member_location';

/// Listens directly to the socket stream and filters for active location updates from others.
final liveLocationStreamProvider = StreamProvider.autoDispose
    .family<MemberLocationUpdate, String>((ref, tripId) async* {
  final socketService = ref.read(trackingSocketServiceProvider);

  // Register disposal BEFORE the first await: if the screen is popped while
  // the ticket request is still in flight, this still tears the socket down.
  ref.onDispose(socketService.disconnect);

  // Must await connect(): reading messagesStream before the channel exists
  // yields an empty stream forever.
  if (!await socketService.connect(tripId)) return;

  // LOOP, not a single pass: a 4001 close makes handleClose() open a NEW channel
  // with its own stream, so draining only once would silently freeze other members' markers.
  while (true) {
    await for (final message in socketService.messagesStream) {
      if (message is Map<String, dynamic> &&
          message[_msgTypeField] == _msgMemberLocation) {
        // Defensive (L1): payload is server-controlled, so no hard cast.
        final payload = message[_msgPayloadField];
        if (payload is Map<String, dynamic>) {
          yield MemberLocationUpdate.fromJson(payload);
        }
      }
    }

    // Stream ended => the server closed the socket. Reconnect only for the
    // auth-expiry case; any other close ends the provider.
    if (!await socketService.handleClose()) return;
  }
});
