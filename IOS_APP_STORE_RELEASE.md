# Pazarcık Portal iOS Yayın Kontrol Listesi

## Sabit uygulama bilgileri

- Uygulama adı: `Pazarcık Portal`
- Bundle ID: `com.pp.pazarckportal.pazarckportal`
- Firebase proje kimliği: `pazarcik-portal-7faf2`
- Sürüm: `1.0.2`
- Build: `30`
- Minimum iOS: `13.0`

Bundle ID yazımındaki `pazarckportal` bölümü mevcut Firebase iOS kaydıyla aynıdır. App Store kaydı oluşturulduktan sonra Bundle ID değiştirilemeyeceği için farklı bir kimlik kullanmayın.

## Windows'ta tamamlananlar

- `GoogleService-Info.plist` ve Flutter Firebase iOS seçenekleri eşleştirildi.
- Google ile giriş URL şeması eklendi.
- Firebase telefon doğrulaması için Encoded App ID URL şeması eklendi.
- Apple ile giriş düğmesi gerçek Firebase Apple oturumuna bağlandı.
- Push bildirimleri için arka plan modu ve imzalama yetkileri eklendi.
- Kamera, galeri ve konum izin metinleri düzeltildi.
- App Store şifreleme beyanı standart HTTPS kullanımı için ayarlandı.
- Genel ve güvensiz HTTP izni kaldırıldı.

## Apple Developer web paneli

1. Certificates, Identifiers & Profiles > Identifiers bölümünde App ID oluşturun veya açın.
2. Bundle ID olarak tam `com.pp.pazarckportal.pazarckportal` kullanın.
3. `Push Notifications` ve `Sign in with Apple` yeteneklerini açın.
4. Keys bölümünde APNs anahtarı oluşturun. `.p8` dosyasını yalnızca bir kez indirebilirsiniz; Key ID ve Team ID ile güvenli saklayın.

## Firebase Console

1. Project Settings > General > iOS uygulamasında Bundle ID'nin `com.pp.pazarckportal.pazarckportal` olduğunu doğrulayın.
2. Project Settings > Cloud Messaging > Apple app configuration alanına APNs `.p8` anahtarını, Key ID ve Team ID'yi yükleyin.
3. Authentication > Sign-in method bölümünde `Apple` sağlayıcısını etkinleştirin ve Apple Developer bilgilerinizle tamamlayın.
4. App Check > iOS uygulamasında `DeviceCheck` sağlayıcısını kaydedin. İlk yayında metrikleri görmeden zorunlu kılmayın.

Telefon doğrulama ve kapalı uygulamaya bildirim için APNs anahtarının Firebase'e yüklenmesi zorunludur.

## Mac'te bir kez yapılacaklar

1. Mac'te `Xcode 26` veya daha yeni bir sürümün kurulu olduğunu doğrulayın. Apple, 28 Nisan 2026'dan beri iOS yüklemelerinde iOS 26 SDK ile Xcode 26 veya yenisini zorunlu tutuyor.
2. Projeyi Mac'e alın ve terminalde proje klasörüne girin.
3. `open ios/Runner.xcworkspace` komutunu çalıştırın. Workspace henüz oluşmadıysa önce `flutter pub get`, ardından `cd ios && pod install` çalıştırın.
4. Xcode'da Runner target > Signing & Capabilities bölümünde Apple Developer Team'inizi seçin ve `Automatically manage signing` açık olsun.
5. Bundle Identifier alanını `com.pp.pazarckportal.pazarckportal` yapın.
6. Push Notifications ve Sign in with Apple yeteneklerinin listede göründüğünü doğrulayın.
7. Gerçek bir iPhone'da Apple/Google giriş, SMS kodu ve bildirim testini bir kez yapın.

Ardından:

```bash
chmod +x tool/prepare_ios_release.sh
./tool/prepare_ios_release.sh
```

Oluşan IPA `build/ios/ipa/` klasöründedir. Xcode Organizer veya Transporter ile yükleyin.

## App Store Connect

- App'i aynı Bundle ID ile oluşturun.
- Bir destek URL'si ve herkese açık gizlilik politikası URL'si girin.
- App Privacy bölümünde ad, e-posta, telefon, kullanıcı içeriği, konum, sipariş/işlem bilgileri, cihaz kimliği ve Firebase/Cloudinary gibi üçüncü tarafların işlediği verileri gerçeğe uygun beyan edin.
- İnceleme hesabı isteyen bölümler için çalışan bir demo kullanıcı ve kullanım notu verin.
- Uygulama içindeki Profil Düzenle > Hesabını Sil akışını inceleme notunda belirtin.
- Uygulamanın yerel bilgilendirme ve iletişim amacı taşıyan, kâr amacı gütmeyen bir şehir portalı olduğunu açıklayın.

## Son cihaz testi

- E-posta, Google ve Apple giriş
- Telefon doğrulama ve reCAPTCHA geri dönüşü
- Uygulama açık/kapalıyken sesli bildirim
- Sipariş alıcı/satıcı bildirim yönlendirmesi
- Kamera, galeri, konum izinleri
- Hesap silme
- Harici bağlantılar ve derin bağlantılar
- Küçük iPhone ekranında taşma kontrolü
