import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pazarcik_portal/profil/phone_verification_page.dart';
import 'package:pazarcik_portal/services/phone_verification.dart';

class FakeGateway implements PhoneVerificationGateway {
  int sends = 0;
  int checks = 0;
  int saves = 0;
  Object? sendError;
  Object? verifyError;
  Object? saveError;
  bool defer = false;
  void Function(String, int?)? sentCallback;
  void Function(PhoneAuthCredential)? autoCallback;

  @override
  Future<void> send(
      {required String phone,
      required int? resendToken,
      required void Function(String, int?) codeSent,
      required void Function(PhoneAuthCredential) completed,
      required void Function(Object) failed}) async {
    sends++;
    sentCallback = codeSent;
    autoCallback = completed;
    if (sendError != null) {
      failed(sendError!);
      return;
    }
    if (!defer) codeSent('session-$sends', 1);
  }

  @override
  Future<void> verify(PhoneAuthCredential credential, String phone) async {
    checks++;
    if (verifyError != null) throw verifyError!;
  }

  @override
  Future<void> save(String phone, [String? fullname]) async {
    saves++;
    if (saveError != null) throw saveError!;
  }
}

class AuthSpy extends Fake implements FirebaseAuth {
  AuthSpy(this.user);
  final User user;
  @override
  User? get currentUser => user;
}

class StoreSpy extends Fake implements FirebaseFirestore {}

class PhoneProviderSpy extends Fake implements UserInfo {
  @override
  String get providerId => 'phone';
}

class PhoneUserSpy extends Fake implements User {
  PhoneUserSpy(this.phoneNumber);
  @override
  String? phoneNumber;
  PhoneAuthCredential? checked;
  FirebaseAuthException? failure;
  @override
  String get uid => 'same-account';
  @override
  bool get isAnonymous => false;
  @override
  List<UserInfo> get providerData => [
        PhoneProviderSpy(),
      ];
  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential credential) async {
    checked = credential;
    if (failure != null) throw failure!;
    phoneNumber = '+905551112234';
  }

  @override
  Future<void> reload() async {}
}

void main() {
  test('existing phone provider still validates new SMS through Firebase',
      () async {
    final user = PhoneUserSpy('+905551112233');
    final gateway = FirebasePhoneVerificationGateway(
        auth: AuthSpy(user), store: StoreSpy());
    final credential = PhoneAuthProvider.credential(
        verificationId: 'real-session', smsCode: '111111');
    await gateway.verify(credential, '+905551112234');
    expect(user.checked, same(credential));
    expect(user.phoneNumber, '+905551112234');
  });

  test('existing phone rejects invalid code instead of marking it verified',
      () async {
    final user = PhoneUserSpy('+905551112233')
      ..failure = FirebaseAuthException(code: 'invalid-verification-code');
    final gateway = FirebasePhoneVerificationGateway(
        auth: AuthSpy(user), store: StoreSpy());
    final credential = PhoneAuthProvider.credential(
        verificationId: 'real-session', smsCode: '123456');
    await expectLater(gateway.verify(credential, '+905551112234'),
        throwsA(isA<FirebaseAuthException>()));
    expect(user.phoneNumber, '+905551112233');
    expect(user.checked, same(credential));
  });

  test('profile write is refused if Auth verified a different phone', () async {
    final user = PhoneUserSpy('+905551112233');
    final gateway = FirebasePhoneVerificationGateway(
        auth: AuthSpy(user), store: StoreSpy());
    await expectLater(
        gateway.save('+905551112234'), throwsA(isA<FirebaseAuthException>()));
  });
  test('normalizes Turkish mobile formats, rejects landlines and letters', () {
    for (final input in [
      '0555 111 22 33',
      '5551112233',
      '+90 (555) 111-22-33',
      '00905551112233'
    ]) {
      expect(normalizeTurkishMobile(input), '+905551112233');
    }
    for (final input in [
      '+902121112233',
      'abc5551112233',
      '555111223',
      '+495551112233'
    ]) {
      expect(normalizeTurkishMobile(input), isNull);
    }
  });

  test('internal error 39 is not misreported as rate limiting', () {
    final message = phoneVerificationError(FirebaseAuthException(
        code: 'unknown',
        message: 'An internal error has occurred. [ Error code:39 ]'));
    expect(message, contains('/ 39'));
    expect(message, isNot(contains('birkaç saat')));
  });

  test('wrong code never saves and allows correction in same session',
      () async {
    final gateway = FakeGateway()
      ..verifyError = FirebaseAuthException(code: 'invalid-verification-code');
    final state =
        PhoneVerificationController(gateway: gateway, phone: '+905550000001');
    addTearDown(state.dispose);
    await state.send();
    await state.submit('111111');
    expect(state.verifying, false);
    expect(state.done, false);
    expect(gateway.saves, 0);
    gateway.verifyError = null;
    await state.submit('222222');
    expect(state.done, true);
    expect(gateway.checks, 2);
    expect(gateway.sends, 1);
  });

  test(
      'save failure retries without spending another SMS or reusing credential',
      () async {
    final gateway = FakeGateway()
      ..saveError = FirebaseAuthException(code: 'permission-denied');
    final state =
        PhoneVerificationController(gateway: gateway, phone: '+905550000002');
    addTearDown(state.dispose);
    await state.send();
    await state.submit('222222');
    expect(state.verified, true);
    expect(state.done, false);
    gateway.saveError = null;
    await state.submit('');
    expect(state.done, true);
    expect(gateway.checks, 1);
    expect(gateway.saves, 2);
  });

  test('cooldown and in-flight request prevent duplicate sends', () async {
    var now = DateTime(2026, 9, 8);
    final gateway = FakeGateway()..defer = true;
    final state = PhoneVerificationController(
        gateway: gateway, phone: '+905550000003', now: () => now);
    addTearDown(state.dispose);
    await state.send();
    await state.send();
    expect(gateway.sends, 1);
    gateway.sentCallback!('first', 1);
    await state.send();
    expect(gateway.sends, 1);
    now = now.add(const Duration(seconds: 91));
    await state.send();
    expect(gateway.sends, 2);
  });

  test('send failure clears busy state without a cooldown', () async {
    final gateway = FakeGateway()
      ..sendError =
          FirebaseAuthException(code: 'unknown', message: 'Error code:39');
    final state =
        PhoneVerificationController(gateway: gateway, phone: '+905550000004');
    addTearDown(state.dispose);
    await state.send();
    expect(state.sending, false);
    expect(state.secondsRemaining, 0);
    expect(state.hasCode, false);
    expect(state.error, contains('/ 39'));
  });

  test('late callbacks after disposal cannot verify or save', () async {
    final gateway = FakeGateway()..defer = true;
    final state =
        PhoneVerificationController(gateway: gateway, phone: '+905550000005');
    await state.send();
    state.dispose();
    gateway.sentCallback!('late', null);
    gateway.autoCallback!(PhoneAuthProvider.credential(
        verificationId: 'late', smsCode: '111111'));
    await Future<void>.delayed(Duration.zero);
    expect(gateway.checks, 0);
    expect(gateway.saves, 0);
  });

  test('automatic verification saves once even when codeSent follows',
      () async {
    final gateway = FakeGateway()..defer = true;
    final state =
        PhoneVerificationController(gateway: gateway, phone: '+905550000006');
    addTearDown(state.dispose);
    await state.send();
    gateway.autoCallback!(PhoneAuthProvider.credential(
        verificationId: 'automatic', smsCode: '111111'));
    await Future<void>.delayed(Duration.zero);
    gateway.sentCallback!('late', null);
    expect(state.done, true);
    expect(gateway.checks, 1);
    expect(gateway.saves, 1);
  });

  test('request watchdog releases UI and ignores late response', () async {
    final gateway = FakeGateway()..defer = true;
    final state = PhoneVerificationController(
        gateway: gateway,
        phone: '+905550000007',
        requestTimeout: const Duration(milliseconds: 5));
    addTearDown(state.dispose);
    await state.send();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(state.sending, false);
    expect(state.error, contains('request-timeout'));
    gateway.sentCallback!('expired', null);
    expect(state.hasCode, false);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180)
  ]) {
    testWidgets('verification form fits $size with large text and keyboard',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gateway = FakeGateway()
        ..verifyError =
            FirebaseAuthException(code: 'invalid-verification-code');
      final phone = '+90555${size.width.toInt().toString().padLeft(7, '0')}';
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.5),
                  viewInsets: const EdgeInsets.only(bottom: 240)),
              child: child!),
          home: PhoneVerificationPage(phone: phone, gateway: gateway)));
      final send = find.text('SMS kodu gönder');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '111111');
      await tester.pump();
      await tester.ensureVisible(find.text('Kodu doğrula'));
      await tester.tap(find.text('Kodu doğrula'));
      await tester.pump();
      expect(find.textContaining('Kod hatalı'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
