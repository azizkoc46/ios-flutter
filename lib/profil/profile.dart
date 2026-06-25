import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Projene özel yollar
import 'package:pazarcik_portal/esnaf_sistemi/lib/components/loading.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/constants/colors.dart';
import 'package:pazarcik_portal/auth/auth.dart';
import 'package:pazarcik_portal/admin/request_complaint_page.dart';
import 'package:pazarcik_portal/admin/admin_notification_service.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/views/main/seller/dashboard.dart';
import 'package:pazarcik_portal/admin/admin_panel.dart';
import 'package:pazarcik_portal/business/business_add_page.dart';
import 'package:pazarcik_portal/business/my_businesses_page.dart';
import 'package:pazarcik_portal/services/notification_service.dart';
import 'package:pazarcik_portal/services/prayer_time_service.dart';
import 'package:pazarcik_portal/main.dart';
import 'edit_profile.dart';
import '../esnaf_sistemi/lib/views/main/customer/my_orders_screen.dart';
import 'package:pazarcik_portal/profil/vendor_application_page.dart';
import 'package:pazarcik_portal/isilani/add_job_page.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- DEĞİŞKENLER ---
  String _appVersion = "Sürüm yükleniyor";
  bool _isNamazNotificationOn = true;
  bool _isUploadingImage = false;
  bool _hasAdminClaim = false;
  bool _adminTokenRegistered = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _getAppVersion();
    _loadAdminClaim();
  }

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? "";
  bool get _isGuestUser =>
      FirebaseAuth.instance.currentUser == null ||
      FirebaseAuth.instance.currentUser?.isAnonymous == true;

  Future<void> _loadAdminClaim() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult();
      final claims = token?.claims ?? const <String, dynamic>{};
      final claimRole = (claims['role'] ?? claims['rol'] ?? claims['userRole'])
          ?.toString()
          .toLowerCase()
          .trim();
      final hasAdminClaim = claims['admin'] == true ||
          claims['isAdmin'] == true ||
          claimRole == 'admin' ||
          claimRole == 'yonetici' ||
          claimRole == 'yönetici';
      if (hasAdminClaim) {
        _ensureAdminNotificationsRegistered();
      }
      if (mounted && hasAdminClaim != _hasAdminClaim) {
        setState(() => _hasAdminClaim = hasAdminClaim);
      }
    } catch (e) {
      debugPrint('Yönetici yetkisi okunamadı: $e');
    }
  }

  // Sürüm bilgisini dinamik çeken fonksiyon
  Future<void> _ensureAdminNotificationsRegistered() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_adminTokenRegistered || uid == null || uid.isEmpty) return;
    _adminTokenRegistered = true;
    await AdminNotificationService.instance.registerAdminToken(uid);
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = "v${packageInfo.version} (${packageInfo.buildNumber})";
        });
      }
    } catch (e) {
      debugPrint("Sürüm çekilemedi: $e");
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNamazNotificationOn = prefs.getBool('namaz_bildirim') ?? true;
    });
  }

  // --- FOTOĞRAF YÜKLEME ---
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      File file = File(image.path);
      String uid = currentUserId;

      Reference ref =
          FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
      await uploadPortalFile(ref, file);

      String downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .update({'image': downloadUrl});

      _showInAppNotificationDialog(
          "Başarılı", "Profil fotoğrafınız güncellendi.");
    } catch (e) {
      debugPrint("Resim yükleme hatası: $e");
      _showInAppNotificationDialog(
          "Hata", "Fotoğraf yüklenirken bir sorun oluştu.");
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  // --- ÇIKIŞ YAP ---
  _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Auth()),
        (route) => false,
      );
    }
  }

  // --- BİLDİRİM AYARLARI ---
  void _showNotificationCategoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NotificationBottomSheet(
        title: "Haber Bildirim Bölgesi",
        subtitle: "Hangi bölgeden haber bildirimi almak istediğinizi seçin.",
        children: [
          _buildNotificationSheetTile(
            title: "Türkiye Gündemi",
            subtitle: "Ülke gündemindeki önemli haberler",
            leading: "🇹🇷",
            onTap: () {
              Navigator.pop(sheetContext);
              _showNotificationFrequencyDialog("Türkiye Gündemi", "gundem");
            },
          ),
          _buildNotificationSheetTile(
            title: "Kahramanmaraş",
            subtitle: "Şehir geneli duyuru ve haberleri",
            leading: "🌶️",
            onTap: () {
              Navigator.pop(sheetContext);
              _showNotificationFrequencyDialog("Kahramanmaraş", "maras");
            },
          ),
          _buildNotificationSheetTile(
            title: "Pazarcık",
            subtitle: "İlçe haberleri, duyurular ve acil bilgiler",
            leading: "📍",
            onTap: () {
              Navigator.pop(sheetContext);
              _showNotificationFrequencyDialog("Pazarcık", "pazarcik");
            },
          ),
        ],
      ),
    );
  }

  void _showNotificationFrequencyDialog(String category, String prefix) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NotificationBottomSheet(
        title: category,
        subtitle: "Bu bölgeden haberleri hangi sıklıkta almak istersiniz?",
        children: [
          _buildNotificationSheetTile(
            title: "Anında",
            subtitle: "Önemli haberleri gelir gelmez bildir",
            icon: Icons.flash_on,
            color: Colors.orange,
            onTap: () =>
                _bildirimAyariniKaydet(category, prefix, "Anında", "_aninda"),
          ),
          _buildNotificationSheetTile(
            title: "Saatlik",
            subtitle: "Bildirimleri saatlik özet halinde al",
            icon: Icons.access_time,
            color: Colors.blue,
            onTap: () =>
                _bildirimAyariniKaydet(category, prefix, "Saatlik", "_saatlik"),
          ),
          _buildNotificationSheetTile(
            title: "Günlük",
            subtitle: "Günde bir kez özet bildirim al",
            icon: Icons.calendar_today,
            color: Colors.green,
            onTap: () =>
                _bildirimAyariniKaydet(category, prefix, "Günlük", "_gunluk"),
          ),
          const Divider(height: 18),
          _buildNotificationSheetTile(
            title: "Kapat",
            subtitle: "Bu bölge için haber bildirimi alma",
            icon: Icons.notifications_off,
            color: Colors.grey,
            onTap: () => _bildirimAyariniKaydet(category, prefix, "Kapalı", ""),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSheetTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? leading,
    IconData? icon,
    Color? color,
  }) {
    final isDark = isDarkModeNotifier.value;
    final tileColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE5E7EB);
    final iconColor = color ?? const Color(0xFFFF7A00);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: leading != null
                      ? Text(leading, style: const TextStyle(fontSize: 21))
                      : Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _bildirimAyariniKaydet(
      String cat, String pre, String gos, String suf) async {
    if (Navigator.canPop(context)) Navigator.pop(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${pre}_tercih', suf);
      await NotificationService().updateSubscription(pre, suf);
      if (mounted) {
        _showInAppNotificationDialog(
            "Başarılı", "$cat bildirimleri '$gos' olarak ayarlandı.");
      }
    } catch (e) {
      if (mounted) {
        _showInAppNotificationDialog(
            "Hata", "Ayar güncellenirken bir sorun oluştu.");
      }
    }
  }

  // --- GİZLİLİK POLİTİKASI PENCERESİ ---
  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Gizlilik Politikası",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBD7FF)),
              ),
              child: const Text(
                "Pazarcık Portal resmi belediye veya kamu kurumu uygulaması değildir. "
                "Dernek/yerel topluluk hesabı üzerinden yürütülen, kar amacı gütmeyen, "
                "satış yeri olmayan ve yalnızca bilgilendirme, duyuru, yerel rehber ve "
                "topluluk iletişimi amacı taşıyan bağımsız bir şehir portalıdır.",
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF123B69),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  "PAZARCIK PORTAL GİZLİLİK POLİTİKASI VE KULLANIM ŞARTLARI\n\n"
                  "1. Kapsam ve Amacımız\n"
                  "Pazarcık Portal ('Uygulama'), kullanıcıların yerel işletmelere ulaşmasını, ilan vermesini ve çeşitli hizmetlerden faydalanmasını sağlayan bir bilgi, iletişim ve sergileme platformudur. Bu politika, kişisel verilerinizin nasıl işlendiğini ve platformun kullanım koşullarını şeffaf bir şekilde belirler.\n\n"
                  "2. Veri Toplama ve Kullanım Amacı\n"
                  "Uygulamamız; hizmetlerin doğru ve eksiksiz sunulabilmesi, kullanıcı güvenliğinin sağlanması ve uygulama içi sistemlerin çalışabilmesi amacıyla temel kullanıcı verilerini (ad, soyad, iletişim bilgileri vb.) Firebase altyapısı üzerinden işler. Toplanan hiçbir kişisel veri, hukuki bir zorunluluk (adli makamların resmi talepleri vb.) olmadıkça 3. şahıslarla, kurumlarla veya reklam şirketleriyle bilerek ve isteyerek paylaşılmaz, satılamaz ve ticari amaçla kullanılamaz.\n\n"
                  "3. Cihaz İzinleri (Kamera ve Galeri)\n"
                  "Profil fotoğrafı güncelleme, mağaza ilanı verme veya istek/şikayet formlarına medya (resim/video) ekleme gibi işlemler için cihazınızın kamera ve galeri erişimi talep edilir. Bu izinler yalnızca sizin onayınız ve inisiyatifinizle, uygulamanın özelliklerini kullanabilmeniz için istenir. Arka planda gizli bir veri çekimi yapılmaz.\n\n"
                  "4. Sorumluluk Reddi ve Platformun Rolü (ÖNEMLİ)\n"
                  "Pazarcık Portal, 5651 sayılı yasa kapsamında hukuki tanımıyla yalnızca bir 'Yer Sağlayıcı' ve dijital bir 'Sergileme Alanı'dır.\n\n"
                  "• Uygulama üzerinden sergilenen hiçbir ürün, hizmet veya ilan üzerinden platformumuzca KOMİSYON ALINMAMAKTADIR.\n"
                  "• Platformda yer alan ilanların, satılan ürünlerin, verilen hizmetlerin kalitesi, teslimatı, yasallığı veya kullanıcıların birbiriyle olan iletişimlerinin doğruluğu konusunda Pazarcık Portal'ın hiçbir hukuki, maddi veya cezai sorumluluğu BULUNMAMAKTADIR.\n"
                  "• Alıcı ve satıcı arasındaki her türlü ticari, maddi veya hukuki anlaşmazlıktan doğrudan doğruya tarafların kendileri sorumludur. Pazarcık Portal yönetimi taraf, kefil veya hakem değildir.\n\n"
                  "5. Kullanıcı Yükümlülükleri\n"
                  "Kullanıcılar, uygulama içerisinde paylaştıkları her türlü içeriğin, yazının ve görselin Türkiye Cumhuriyeti kanunlarına uygun olduğunu peşinen kabul eder. Yasadışı, yanıltıcı, telif hakkı ihlali içeren veya suç teşkil eden her türlü içerikte tüm hukuki ve cezai sorumluluk tamamen paylaşımı yapan kişiye aittir.\n\n"
                  "Uygulamayı kullanan her birey, KVKK aydınlatma metnini, bu gizlilik politikasını ve kullanım şartlarını okumuş, anlamış ve eksiksiz olarak kabul etmiş sayılır.",
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                child: const Text("Anladım"),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- YARDIMCI METOTLAR ---
  void _showInAppNotificationDialog(String title, String message) {
    NotificationService().showSimpleDetail(title, message);
  }

  Widget _buildGuestProfile(BuildContext context) {
    final isDark = isDarkModeNotifier.value;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title:
            const Text("Profil", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Align(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.person_crop_circle_badge_plus,
                    color: primaryColor,
                    size: 54,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                "Misafir olarak geziniyorsunuz",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Menüleri, haberleri ve yerel içerikleri giriş yapmadan inceleyebilirsiniz. Sipariş vermek, ilan eklemek, başvuru yapmak ve bildirim ayarlarını kişiselleştirmek için hesap açmanız gerekir.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 28),
              CupertinoButton.filled(
                borderRadius: BorderRadius.circular(14),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const Auth()),
                ),
                child: const Text("Giriş Yap / Kayıt Ol"),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.dark_mode_outlined,
                      color: Colors.indigo),
                  title: Text(
                    "Karanlık Mod",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  trailing: CupertinoSwitch(
                    value: isDark,
                    activeTrackColor: primaryColor,
                    onChanged: (v) async {
                      isDarkModeNotifier.value = v;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('darkMode', v);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGuestUser) {
      return _buildGuestProfile(context);
    }

    bool isDark = isDarkModeNotifier.value;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Profilim",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .doc(currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: Loading(color: primaryColor, kSize: 50));
          }
          var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          String role = (userData['role'] ??
                  userData['rol'] ??
                  userData['userRole'] ??
                  userData['accountRole'] ??
                  'customer')
              .toString()
              .toLowerCase()
              .trim();
          final bool isAdmin = role == 'admin' ||
              role == 'yonetici' ||
              role == 'yönetici' ||
              userData['isAdmin'] == true ||
              userData['admin'] == true ||
              _hasAdminClaim;
          if (isAdmin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _ensureAdminNotificationsRegistered();
            });
          }
          bool isApproved = userData['isApproved'] ?? false;
          String imageUrl = userData['image'] ?? "";
          String fullname = userData['fullname'] ?? "Pazarcıklı";
          String phone = userData['phone'] ?? "Telefon kayıtlı değil";

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // --- PROFİL FOTOĞRAFI ---
                Center(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: primaryColor.withOpacity(0.3), width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : null,
                          child: imageUrl.isEmpty
                              ? const Icon(Icons.person,
                                  size: 58, color: Colors.white)
                              : null,
                        ),
                      ),
                      if (_isUploadingImage)
                        const Positioned.fill(
                          child: CircularProgressIndicator(color: primaryColor),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF121212)
                                      : Colors.white,
                                  width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(fullname,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black)),
                Text(phone,
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 30),

                // --- 1. GRUP: HESAP ---
                _buildSectionTitle("Hesap Ayarları"),
                _buildMenuCard(isDark, [
                  _menuItem(Icons.person_outline, "Kişisel Bilgiler",
                      isDark: isDark,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const EditProfile()))),
                  if (!isAdmin)
                    _menuItem(Icons.shopping_bag_outlined, "Siparişlerim",
                        isDark: isDark,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const MyOrdersScreen()))),
                  if (isAdmin)
                    _menuItem(Icons.admin_panel_settings, "Yönetici Paneli",
                        isDark: isDark,
                        color: Colors.red,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const AdminPanelScreen()))),
                  if (role == 'satici' && isApproved)
                    _menuItem(Icons.dashboard_customize, "Mağazamı Yönet",
                        isDark: isDark,
                        color: Colors.green,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => DashboardScreen()))),
                  if (role == 'customer')
                    _menuItem(
                      Icons.storefront,
                      "Restoran&cafe Hesabı Aç",
                      isDark: isDark,
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (context) =>
                                const VendorApplicationPage()),
                      ),
                    ),
                  if (role == 'vendor_pending')
                    _menuItem(Icons.hourglass_empty, "Başvuru İnceleniyor",
                        isDark: isDark, color: Colors.grey),
                ]),

                const SizedBox(height: 25),

                // --- 2. GRUP: İŞLETME REHBERİ ---
                _buildSectionTitle("İşletme Rehberi"),
                _buildMenuCard(isDark, [
                  _menuItem(Icons.add_business_outlined, "İşletmemi Ekle",
                      isDark: isDark,
                      color: const Color(0xFF004D40),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const BusinessAddPage(
                                  existingBusiness: {}, docId: '')))),
                  _menuItem(Icons.list_alt_outlined, "İşletmelerimi Yönet",
                      isDark: isDark,
                      color: Colors.blueGrey,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MyBusinessesPage()))),
                ]),

                const SizedBox(height: 25),

                // --- 3. GRUP: İŞ & KARİYER ---
                _buildSectionTitle("İş & Kariyer"),
                _buildMenuCard(isDark, [
                  _menuItem(Icons.work_outline, "İş İlanı Ver",
                      isDark: isDark,
                      color: const Color(0xFF0284C7),
                      onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (context) => const AddJobPage()))),
                  _menuItem(Icons.manage_search_outlined, "İş İlanlarımı Yönet",
                      isDark: isDark, color: Colors.deepPurple, onTap: () {
                    debugPrint("İş ilanlarım sayfasına gidilecek");
                  }),
                ]),

                const SizedBox(height: 25),

                // --- 4. GRUP: BİLDİRİM VE UYGULAMA ---
                _buildSectionTitle("Uygulama Ayarları"),
                _buildMenuCard(isDark, [
                  // 🔥 Karanlık Mod (Sorun çözüldü!)
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined,
                        color: Colors.indigo),
                    title: Text("Karanlık Mod",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black)),
                    trailing: CupertinoSwitch(
                      value: isDark,
                      activeTrackColor: primaryColor,
                      onChanged: (v) async {
                        // BURASI ÖNEMLİ: State'i zorla güncelliyoruz!
                        setState(() {});
                        isDarkModeNotifier.value = v;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('darkMode', v);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 50),
                  // Namaz Bildirimleri (Aç/Kapat)
                  ListTile(
                    leading: const Icon(CupertinoIcons.moon_stars,
                        color: Colors.teal),
                    title: Text("Namaz Vakti Uyarıları",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black)),
                    trailing: CupertinoSwitch(
                      value: _isNamazNotificationOn,
                      activeTrackColor: Colors.teal,
                      onChanged: (v) async {
                        setState(() => _isNamazNotificationOn = v);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('namaz_bildirim', v);
                        if (v) {
                          await PrayerTimeService().fetchVakitler();
                        } else {
                          await NotificationService().cancelPrayerAlerts();
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 50),
                  // Haber Bildirimleri (Detaylı)
                  _menuItem(
                      Icons.notifications_active_outlined, "Haber Bildirimleri",
                      isDark: isDark,
                      color: Colors.orange,
                      onTap: _showNotificationCategoryDialog),
                ]),

                const SizedBox(height: 25),

                // --- 5. GRUP: DESTEK ---
                _buildSectionTitle("Destek & İletişim"),
                _buildMenuCard(isDark, [
                  _menuItem(Icons.message_outlined, "İstek & Şikayet",
                      isDark: isDark,
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (context) =>
                                  const RequestComplaintPage()))),
                  _menuItem(Icons.privacy_tip_outlined, "Gizlilik Politikası",
                      isDark: isDark, onTap: _showPrivacyPolicy),
                  _menuItem(Icons.info_outline, "Uygulama Hakkında",
                      isDark: isDark, trailingText: _appVersion),
                ]),

                const SizedBox(height: 40),

                // --- ÇIKIŞ YAP ---
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _logout,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 10),
                      Text("Çıkış Yap",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16))
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI YARDIMCILARI ---
  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 10),
        child: Text(title,
            style: const TextStyle(
                color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildMenuCard(bool isDark, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _menuItem(IconData icon, String title,
      {Color? color,
      VoidCallback? onTap,
      String? trailingText,
      required bool isDark}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.blueAccent.withOpacity(0.8)),
      title: Text(title,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black)),
      trailing: trailingText != null
          ? Text(trailingText,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w600))
          : const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}

class _NotificationBottomSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _NotificationBottomSheet({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkModeNotifier.value;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 12,
              bottom: bottomInset + 18,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: "Kapat",
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                      color: isDark ? Colors.white54 : Colors.black38,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(children: children),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
