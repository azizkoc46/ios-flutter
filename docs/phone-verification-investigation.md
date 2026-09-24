# Phone verification investigation - 2026-09-08

## Production configuration inspected

- Project: `pazarcik-portal-7faf2`; billing enabled.
- Phone provider enabled; two fictional test numbers configured. Test numbers
  do not demonstrate real SMS delivery. No phone numbers or test codes were
  exported or modified.
- `smsRegionConfig` was `{}`. Set an explicit Turkey-only allowlist (`TR`).
  Firebase documents that new projects do not allow SMS regions by default.
- `www.pazarcikportal.com` was missing from authorized domains. Added it while
  preserving all existing domains.
- Android app `1:615903758381:android:f4d24ce9835910e9b610a4` has three SHA-1
  and three SHA-256 entries. This establishes their presence, not whether the
  current Play App Signing certificate matches every entry.
- iOS bundle ID and Firebase app ID match the local configuration.
- iOS source includes the encoded app-ID URL scheme, remote-notification
  background mode, APNs entitlement, and production/release APNs environment.
  Installed FlutterFire implements APNs and SceneDelegate URL forwarding.
- The APNs key validity in Firebase/Apple was not independently verified.
- No recent Identity Toolkit ERROR audit entries were returned by the log
  query. This is not evidence of successful SMS delivery; end-user auth
  operations may not be available in audit logs.
- User reports `An internal error has occurred. Error code:39` across Turkish
  operators, including a first attempt from the account. The exact reason for
  that opaque backend response is not established by this code alone.

## Application defects fixed

- Existing phone provider previously bypassed credential validation and wrote
  `phoneVerified: true`. It now calls Firebase `updatePhoneNumber` with the
  credential. New phone providers use `linkWithCredential`.
- Web no longer unlinks the existing phone before verifying the replacement,
  nor treats an unlink/recent-login exception as proof of verification.
- The installed FlutterFire web implementation supports `verifyPhoneNumber`;
  the same credential-validation flow is used on Android, iOS and web.
- Verified phone is checked against Firebase Auth before profile persistence;
  user identity is checked and ID-token claims are refreshed before saving.
- Incorrect-code errors no longer leave the confirm button permanently busy.
- Profile-save failures permit a save-only retry, without resending SMS or
  resubmitting a consumed credential. Save wait is bounded to 20 seconds.
- Callbacks arriving after cancellation, disposal or request timeout are ignored.
- Resend cooldown is 90 seconds, tracked by phone during the running session.
  Firebase retains responsibility for server-side rate limiting.
- Removed the incorrect statement that the 60-second automatic retrieval timeout
  is the SMS code expiry. Firebase determines actual session expiry.
- Internal error 39 is preserved in the UI and is not incorrectly translated
  to a confirmed rate-limit reason. Phone numbers and OTPs are not logged.
- Profile verification badge compares the entered phone with Firebase Auth.
- New scrollable verification screen supports Turkish copy, code autofill,
  resend countdown, dark mode and large text.

## Validation

```text
flutter test test/phone_verification_test.dart --no-pub
flutter analyze lib/services/phone_verification.dart lib/profil/phone_verification_page.dart lib/profil/edit_profile.dart test/phone_verification_test.dart --no-pub
flutter build web --release -t lib/main_web.dart --no-wasm-dry-run --no-pub
```

15 automated tests cover wrong codes, existing phone providers, persistence
retries, callbacks, timeouts and layouts at 320x568, 390x844 and 820x1180 with
large text and a keyboard inset. These are not real-SMS transport tests.

No Android bundle, iOS archive, GitHub push or Hosting deployment was performed.
The two Firebase configuration changes above are already live.

## Follow-up: real number still returns error 39

The user closed/reopened the installed app and reproduced the same error after
the TR region change. The region change did NOT establish successful delivery.

Readback confirmed TR is allowed, Phone is enabled, project subtype is
IDENTITY_PLATFORM, `recaptchaConfig` is absent and the reCAPTCHA Enterprise API
is DISABLED. SMS Defense is therefore not configured. Its absence alone does
not establish the cause of error 39; it is not enabled speculatively.

Identity Platform user activity logging was disabled. Enabled
`monitoring.requestLogging.enabled` on 2026-09-08 and verified via readback,
so the next SendVerificationCode request can be investigated. Activity logs
are distinct from administrator audit logs. They can contain personal data
and contribute to Cloud Logging usage; disable this temporary diagnostic
setting after the incident. Extract only timestamp, method and error/status
for investigation, not request payloads, OTPs, tokens or phone numbers.

Official activity logging setup:
https://docs.cloud.google.com/identity-platform/docs/activity-logging

Do not force SMS Defense ENFORCE on the currently installed clients before
validating compatible native reCAPTCHA dependencies and AUDIT-mode results:
https://docs.cloud.google.com/identity-platform/docs/recaptcha-tfp

## Required delivery check

### Captured failure after logging was enabled

The user's subsequent retry was captured at `2026-09-08T10:31:06.488Z`
(13:31:06.488 Turkey time). `SendVerificationCode` returned status `13`,
message `Error code: 39`, insertId `-psbwpme5y32n`. No additional backend
reason was exposed. GetRecaptchaConfig and GetRecaptchaParam succeeded just
before this event; this does not prove that app attestation itself succeeded.

The request reached the expected project and failed in the SMS-send operation.
Root cause (anti-abuse, delivery restriction, quota or other internal error)
remains undetermined. Do not claim a confirmed carrier block or recommend
repeated retries. A ready-to-submit request with the exact evidence is in
`docs/firebase-sms-support-request.txt`. It has not been submitted.

After capturing the event, temporary request logging was restored to disabled.
The captured log remains subject to the existing Cloud Logging retention policy.

1. Close and reopen the installed app and request one SMS for a real number
   that is NOT in Firebase's fictional test-number list.
2. Record the time, platform, operator and returned error code, without posting
   the phone number or OTP in shared logs.
3. On the new client, check wrong-code rejection, correct-code acceptance,
   save/reopen, changing an existing verified phone, and resend after cooldown.
4. Check at least one physical iPhone and one Play-installed Android device.
5. If error 39 persists, escalate to Firebase Authentication support with the
   details below. Do not keep sending requests or disable app verification.

### Support request draft (not submitted)

Project: pazarcik-portal-7faf2
Product: Firebase Authentication / phone SMS verification
Real numbers across Turkcell, Vodafone and Turk Telekom reportedly receive
`An internal error has occurred. Error code:39` on Android and iOS, including
the first attempt from a user account. Fictional Firebase test numbers work.
Billing and Phone provider are enabled. An explicit TR SMS allowlist was set
on 2026-09-08. Please investigate project-level SMS delivery restrictions,
anti-abuse decisions and carrier routing for a recent failed request.
Recent reproduction timestamp, platform and app version: [fill after retest].
Please provide a secure support channel for any requested phone number.

## References

- https://firebase.google.com/docs/auth/android/phone-auth
- https://firebase.google.com/docs/auth/ios/phone-auth
- https://firebase.google.com/docs/auth/flutter/phone-auth
- https://firebase.google.com/docs/auth/web/phone-auth
- https://firebase.google.com/docs/auth/limits
- https://docs.cloud.google.com/identity-platform/docs/admin/sms-regions
- https://firebase.google.com/support
