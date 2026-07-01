import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayfarer_sync_mobile/features/tracking/providers/mapStateProvider.dart';

void main() {
  test('keeps an independent ordered trail per user', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mapStateProvider.notifier);

    notifier.updateMemberPosition('user-a', const LatLng(1.0, 1.0));
    notifier.updateMemberPosition('user-b', const LatLng(5.0, 5.0));
    notifier.updateMemberPosition('user-a', const LatLng(2.0, 2.0));

    final state = container.read(mapStateProvider);
    expect(state.trails['user-a']!.length, 2);
    expect(state.trails['user-b']!.length, 1);
    expect(state.trails['user-a']!.last, const LatLng(2.0, 2.0));
    expect(state.positions['user-a'], const LatLng(2.0, 2.0));
  });

  test('caps each trail at maxTrailPoints, dropping the oldest', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mapStateProvider.notifier);

    for (var index = 0; index < maxTrailPoints + 10; index++) {
      notifier.updateMemberPosition('user-a', LatLng(index.toDouble(), 0.0));
    }

    final trail = container.read(mapStateProvider).trails['user-a']!;
    expect(trail.length, maxTrailPoints);
    expect(trail.first.latitude, 10.0);
    expect(trail.last.latitude, (maxTrailPoints + 9).toDouble());
  });
}
