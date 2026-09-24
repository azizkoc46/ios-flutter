import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pazarcik_portal/onboarding/portal_welcome.dart';

void main() {
  testWidgets('pages support next, back and finish', (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: PortalWelcomePages(onFinish: () async => finished++),
    ));
    expect(find.text('Hoş geldin, Pazarcıklı!'), findsOneWidget);
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('Mahallenin lezzetleri'), findsOneWidget);
    await tester.tap(find.byTooltip('Önceki sayfa'));
    await tester.pumpAndSettle();
    expect(find.text('Hoş geldin, Pazarcıklı!'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('fits $size with large text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PortalWelcomePages(onFinish: () async {}),
      ));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Devam Et'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Başlayalım').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('skip persists and next launch opens app directly',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    Widget app() => const MaterialApp(
          home: PortalWelcomeGate(
            splashDuration: Duration.zero,
            child: Scaffold(body: Text('Application home')),
          ),
        );
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Atla'), findsOneWidget);
    expect(find.text('Application home'), findsNothing);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(find.text('Application home'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance()).getBool(portalWelcomeSeenKey),
        isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Atla'), findsNothing);
    expect(find.text('Application home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
