import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wayfarer_sync_mobile/core/constants/appConstants.dart';
import 'package:wayfarer_sync_mobile/core/network/apiClient.dart';
import 'package:wayfarer_sync_mobile/core/network/apiUrl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Wire protocol shared with the backend. Values must not change without a
/// matching backend change — see `backend/src/websocket.ts`.
const String _msgTypeField = 'type';
const String _msgPayloadField = 'payload';
const String _msgAuthRefresh = 'auth_refresh';
const String _msgLocationUpdate = 'location_update';
const String _ticketField = 'ticket';
const String _tripIdField = 'tripId';

class TrackingSocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  Timer? _reauthTimer;
  String? _tripId;
  bool _reconnectingForAuth = false;

  TrackingSocketService(this._ref);

  final String _wsBaseUrl = ApiUrl.wsBaseUrl;

  /// Fetches a short-lived, trip-scoped ticket. Returns null on any failure
  /// (usually offline); caller treats that as "skip this cycle", not a logout (R1).
  Future<String?> _fetchTicket(String tripId) async {
    try {
      final response = await _ref
          .read(apiClientProvider)
          .post(ApiUrl.wsTicket, {_tripIdField: tripId});
      if (response is Map<String, dynamic>) {
        return response[_ticketField] as String?;
      }
      return null;
    } catch (error) {
      // Logged so a missing credential doesn't silently disable live tracking.
      debugPrint('WS ticket fetch failed: $error');
      return null;
    }
  }

  /// Returns whether the socket was actually established, so the caller can
  /// surface "reconnecting" rather than showing an empty map forever.
  Future<bool> connect(String tripId) async {
    // This singleton can outlive its autoDispose consumer, so trip B could call
    // connect() before trip A disposes — must not hand B trip A's socket.
    if (_channel != null) {
      if (_tripId == tripId) return true;
      disconnect();
    }
    _tripId = tripId;

    final ticket = await _fetchTicket(tripId);
    if (ticket == null) return false;

    _channel = WebSocketChannel.connect(
      Uri.parse('$_wsBaseUrl?$_ticketField=$ticket&$_tripIdField=$tripId'),
    );
    _startReauthTimer();
    return true;
  }

  /// Shorter than the server's own re-auth window, so one missed cycle (a brief
  /// network drop) is survivable rather than fatal.
  void _startReauthTimer() {
    _reauthTimer?.cancel();
    _reauthTimer = Timer.periodic(AppConstants.wsReauthInterval, (_) async {
      final tripId = _tripId;
      if (tripId == null || _channel == null) return;

      final ticket = await _fetchTicket(tripId);
      if (ticket == null) return; // offline — try again next cycle

      _channel?.sink.add(jsonEncode({
        _msgTypeField: _msgAuthRefresh,
        _msgPayloadField: {_ticketField: ticket},
      }));
    });
  }

  Stream<dynamic> get messagesStream {
    final channel = _channel;
    if (channel == null) return const Stream.empty();
    return channel.stream.map((raw) {
      try {
        return jsonDecode(raw as String);
      } catch (_) {
        // A malformed frame must not tear down the whole stream.
        return const <String, dynamic>{};
      }
    });
  }

  /// Narrow reconnect for the auth path only (general backoff/heartbeat is separate
  /// work). Returns true only if a NEW socket was established, so the caller knows
  /// to listen to a fresh stream — returning void left callers frozen.
  Future<bool> handleClose() async {
    final code = _channel?.closeCode;
    final tripId = _tripId;
    if (code != AppConstants.wsAuthExpiredCloseCode || tripId == null) {
      return false;
    }
    if (_reconnectingForAuth) return false;

    _reconnectingForAuth = true;
    try {
      _channel = null;
      _reauthTimer?.cancel();
      return await connect(tripId);
    } finally {
      // `finally`, not a trailing assignment: a throw from connect() would
      // otherwise latch auth-reconnect off for the rest of the session.
      _reconnectingForAuth = false;
    }
  }

  void sendLocationUpdate({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) {
    final channel = _channel;
    if (channel == null) return;

    channel.sink.add(jsonEncode({
      _msgTypeField: _msgLocationUpdate,
      _msgPayloadField: {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'accuracy': ?accuracy,
      },
    }));
  }

  void disconnect() {
    _reauthTimer?.cancel();
    _reauthTimer = null;
    _channel?.sink.close();
    _channel = null;
    _tripId = null;
  }
}

final trackingSocketServiceProvider =
    Provider<TrackingSocketService>((ref) => TrackingSocketService(ref));
