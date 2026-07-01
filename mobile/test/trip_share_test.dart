import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/features/trip/services/tripShare.dart';

void main() {
  test('share text contains the trip id, title, and join instruction', () {
    final text = buildTripShareText(tripId: 'abc-123', title: 'Alpine Trail');
    expect(text, contains('abc-123'));
    expect(text, contains('Alpine Trail'));
    expect(text, contains('Join Trip'));
  });
}
