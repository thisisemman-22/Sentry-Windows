import 'package:campus_parking_desktop/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'SENTRY Desktop End-to-End Flow: Login -> Overview -> Live Gate Cosine Similarity & Confirm Passage -> Access Logs U007 V007/V008',
      (WidgetTester tester) async {
    // Configure widescreen 1920x1080 Windows Command Center surface
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: SentryDesktopApp(),
      ),
    );
    await tester.pump();

    // 1. Verify SENTRY Login Screen renders
    expect(find.text('Sign in to Guard & ICT Console'), findsOneWidget);

    // Sign in as Guard (guard01@sentry.test is pre-filled)
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pump();

    // 2. Verify Overview Command Dashboard renders with confirmed post-passage visit label
    expect(find.text('CONFIRMED VEHICLES INSIDE CAMPUS'), findsOneWidget);

    // 3. Navigate to View 3: Live Gate Monitoring
    await tester.tap(find.byKey(const Key('nav_tab_liveGateMonitoring')));
    await tester.pump();

    // Verify face_similarity_score is displayed strictly as cosine similarity, never as %
    final cosineFinder = find.byKey(const Key('face_cosine_similarity_value'));
    expect(cosineFinder, findsOneWidget);
    final cosineText = tester.widget<Text>(cosineFinder).data ?? '';
    expect(cosineText, contains('cosine similarity'));
    expect(cosineText.contains('%'), isFalse);

    // Verify Confirm Vehicle Crossed Gate button is present for allowed attempt
    expect(
      find.byKey(const Key('confirm_vehicle_crossed_button')),
      findsOneWidget,
    );

    // 4. Navigate to View 6: Access Logs & Lookup and verify U007's V007 and V008 are separate cards
    await tester.tap(find.byKey(const Key('nav_tab_accessLogs')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('access_logs_subtab_2')));
    await tester.pump();

    expect(find.byKey(const Key('vehicle_card_V007')), findsOneWidget);
    expect(find.byKey(const Key('vehicle_card_V008')), findsOneWidget);
  });
}
