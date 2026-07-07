import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/core/theme/appTheme.dart';
import 'package:wayfarer_sync_mobile/core/widgets/inlineErrorBanner.dart';

// buildLightTheme() registers the AppSemanticColors theme extension that
// InlineErrorBanner reads via context.semantic. The inner MediaQuery (injected
// through MaterialApp's builder) is how we override disableAnimations below the
// MaterialApp, which otherwise supplies its own MediaQuery from the window.
Widget _host({required bool disableAnimations}) => MaterialApp(
      theme: buildLightTheme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: const Scaffold(body: InlineErrorBanner(message: 'Oops')),
        ),
      ),
    );

void main() {
  testWidgets('renders message and animates when motion enabled',
      (tester) async {
    await tester.pumpWidget(_host(disableAnimations: false));
    expect(find.text('Oops'), findsOneWidget);
    expect(find.byType(Animate), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('no Animate wrapper under reduced motion', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));
    expect(find.text('Oops'), findsOneWidget);
    expect(find.byType(Animate), findsNothing);
    await tester.pumpAndSettle();
  });
}
