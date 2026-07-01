import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Builds the human-readable message shared/copied to invite others to a trip.
String buildTripShareText({required String tripId, required String title}) {
  return 'Join my trip "$title" on Wayfarer Sync!\n'
      'Trip ID: $tripId\n'
      'Open the app, tap Join Trip, and paste this ID.';
}

/// Opens the OS share sheet with the trip invite text.
Future<void> shareTrip({required String tripId, required String title}) {
  return Share.share(buildTripShareText(tripId: tripId, title: title));
}

/// Copies the raw trip id to the clipboard for pasting into Join Trip.
Future<void> copyTripId(String tripId) {
  return Clipboard.setData(ClipboardData(text: tripId));
}
