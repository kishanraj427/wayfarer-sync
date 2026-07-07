import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wayfarer_sync_mobile/core/network/authTokenProvider.dart';
import 'package:wayfarer_sync_mobile/core/network/apiUrl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TrackingSocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  
  final String _wsBaseUrl = ApiUrl.wsBaseUrl;

  TrackingSocketService(this._ref);

  /// Establishes the real-time link for a specific trip
  void connect(String tripId) {
    if (_channel != null) {
      debugPrint('[WS] connect skipped: already connected');
      return; // Prevent creating duplicate sockets
    }

    final token = _ref.read(authTokenProvider);
    if (token == null) {
      debugPrint('[WS] connect ABORTED: auth token is null');
      return;
    }

    // Securely inject authentication credentials into the query parameters
    final uri = Uri.parse('$_wsBaseUrl?token=$token&tripId=$tripId');
    debugPrint('[WS] connecting to $_wsBaseUrl?tripId=$tripId (token present)');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    channel.ready
        .then((_) => debugPrint('[WS] CONNECTED for trip $tripId'))
        .catchError((Object error) {
          debugPrint('[WS] CONNECTION FAILED: $error');
        });
  }

  /// Exposes the incoming WebSocket data stream to the application
  Stream<dynamic> get messagesStream {
    if (_channel == null) return const Stream.empty();
    return _channel!.stream.map((rawMessage) => jsonDecode(rawMessage));
  }

  /// Sends your live location frame up to the server matching its expected JSON structure
  void sendLocationUpdate({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) {
    if (_channel == null) {
      debugPrint('[WS] send skipped: no channel (socket not connected)');
      return;
    }

    final frame = {
      'type': 'location_update',
      'payload': {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'accuracy': ?accuracy,
      }
    };

    _channel!.sink.add(jsonEncode(frame));
    debugPrint('[WS] sent location_update ($latitude, $longitude)');
  }

  /// Cleanly closes the socket pool when leaving the map view
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}

final trackingSocketServiceProvider = Provider<TrackingSocketService>((ref) {
  return TrackingSocketService(ref);
});