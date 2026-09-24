# Acilis gorselleri

Gorselleri proje icindeki `assets` klasorune ekleyin:

| Dosya | Onerilen boyut | Kullanim |
| --- | --- | --- |
| portal_splash_portrait.jpg | 1080 x 1920 px | Dikey telefon ve tablet |
| portal_splash_landscape.jpg | 1920 x 1080 px | Yatay tablet ve web |

Logo ve metni arka plana gommeden gonderin. Mevcut logo uygulamada ayri
gosterilir. Gorseller ekran oranina gore kirpilir; onemli detaylari kenarlara
yerlestirmeyin. Tek gorsel varsa diger yon icin de kullanilir. Hic gorsel yoksa
siyah zemin ve logo gosterilir. Gorseller eklendikten sonra yeni derleme gerekir.

Isletim sisteminin ilk yukleme ekrani siyah zemin ve logodur. Tam ekran arka
plan Flutter hazir oldugunda gorunur; Android 12'nin sistem acilis ekrani
tam ekran fotograf yerine kendi logo duzenini kullanir.

Tanitim, cihaz/tarayici yerel depolamasindaki `portal_welcome_completed_v1`
anahtariyla bir kez gosterilir. Atla ve Baslayalim tamamlandi olarak kaydeder.
Hesaptan cikis bu kaydi silmez. Tarayici verileri temizlenirse veya yeni bir
cihaz/tarayici kullanilirsa tanitim yeniden gorunebilir. Depolama kapaliysa
kullanici uygulamaya girmeye devam edebilir.

Tanitimdan sonra uye oturumu olmayanlar mevcut e-posta/sifre ve sosyal giris
ekranini gorur. Anonim Firebase oturumu uyelik sayilmaz. "Misafir olarak kesfet"
form doldurmadan ana sayfayi acar. Uye oturumu acik olanlar tekrar giris yapmaz.
Surum ve duyuru kontrolleri giris/misafir seciminden sonra ana sayfada calisir.

Bu degisiklik icin GitHub aktariminda `lib/onboarding`, `lib/main.dart`,
`pubspec.yaml`, gorseller ve uretilen Android/iOS/web splash dosyalari birlikte
dahil edilmelidir. Yalnizca main.dart kopyalanmamali.
