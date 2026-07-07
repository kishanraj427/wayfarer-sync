import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/core/motion/motion.dart';

Widget _wrap({required bool disableAnimations, required Widget child}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

void main() {
  testWidgets('appEntrance wraps child in Animate when motion enabled',
      (tester) async {
    await tester.pumpWidget(_wrap(
      disableAnimations: false,
      child: Builder(
        builder: (context) => const Text('hi').appEntrance(context),
      ),
    ));
    expect(find.byType(Animate), findsOneWidget);
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('appEntrance is a no-op under reduced motion', (tester) async {
    await tester.pumpWidget(_wrap(
      disableAnimations: true,
      child: Builder(
        builder: (context) => const Text('hi').appEntrance(context),
      ),
    ));
    expect(find.byType(Animate), findsNothing);
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('motionEnabled reflects MediaQuery.disableAnimations',
      (tester) async {
    late bool enabledOn;
    late bool enabledOff;
    await tester.pumpWidget(_wrap(
      disableAnimations: true,
      child: Builder(builder: (context) {
        enabledOn = motionEnabled(context);
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(_wrap(
      disableAnimations: false,
      child: Builder(builder: (context) {
        enabledOff = motionEnabled(context);
        return const SizedBox();
      }),
    ));
    expect(enabledOn, isFalse);
    expect(enabledOff, isTrue);
  });
}
