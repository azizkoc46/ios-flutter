import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Projene Ã¶zel yollar
import 'package:pazarcik_portal/esnaf_sistemi/lib/components/loading.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/constants/colors.dart';
import 'package:pazarcik_portal/auth/auth.dart';
import 'package:pazarcik_portal/admin/request_complaint_page.dart';
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
  // --- DEÄÄ°ÅKENLER ---
  String _appVersion = "SÃ¼rÃ¼m yÃ¼kleniyor";
  bool _isNamazNotificationOn = true;
  bool _isUploadingImage = false;
  bool _hasAdminClaim = false;

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
          claimRole == 'yÃ¶netici';
      if (mounted && hasAdminClaim != _hasAdminClaim) {
        setState(() => _hasAdminClaim = hasAdminClaim);
      }
    } catch (e) {
      debugPrint('YÃ¶netici yetkisi okunamadÄ±: $e');
    }
  }

  // SÃ¼rÃ¼m bilgisini dinamik Ã§eken fonksiyon
  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = "v${packageInfo.version} (${packageInfo.buildNumber})";
        });
      }
    } catch (e) {
      debugPrint("SÃ¼rÃ¼m Ã§ekilemedi: $e");
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNamazNotificationOn = prefs.getBool('namaz_bildirim') ?? true;
    });
  }

  // --- FOTOÄRAF YÃœKLEME ---
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
          "BaÅŸarÄ±lÄ±", "Profil fotoÄŸrafÄ±nÄ±z gÃ¼ncellendi.");
    } catch (e) {
      debugPrint("Resim yÃ¼kleme hatasÄ±: $e");
      _showInAppNotificationDialog(
          "Hata", "FotoÄŸraf yÃ¼klenirken bir sorun oluÅŸtu.");
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  // --- Ã‡IKIÅ YAP ---
  _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Auth()),
        (route) => false,
      );
    }
  }

  // --- BÄ°LDÄ°RÄ°M AYARLARI ---
  void _showNotificationCategoryDialog() {
    showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Haber Bildirim BÃ¶lgesi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTile("ğŸ‡¹ğŸ‡· TÃ¼rkiye GÃ¼ndemi", () {
              Navigator.pop(context);
              _showNotificationFrequencyDialog("TÃ¼rkiye GÃ¼ndemi", "gundem");
            }),
            _buildDialogTile("ğŸŒ¶ï¸ KahramanmaraÅŸ", () {
              Navigator.pop(context);
              _showNotificationFrequencyDialog("KahramanmaraÅŸ", "maras");
            }),
            _buildDialogTile("ğŸ“ PazarcÄ±k", () {
              Navigator.pop(context);
              _showNotificationFrequencyDialog("PazarcÄ±k", "pazarcik");
            }),
          ],
        ),
      ),
    );
  }

  void _showNotificationFrequencyDialog(String category, String prefix) {
    showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(category),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTile(
                "âš¡ AnÄ±nda",
                () => _bildirimAyariniKaydet(
                    category, prefix, "AnÄ±nda", "_aninda"),
                icon: Icons.flash_on,
                color: Colors.orange),
            _buildDialogTile(
                "ğŸ•’ Saatlik",
                () => _bildirimAyariniKaydet(
                    category, prefix, "Saatlik", "_saatlik"),
                icon: Icons.access_time,
                color: Colors.blue),
            _buildDialogTile(
                "ğŸ“… GÃ¼nlÃ¼k",
                () => _bildirimAyariniKaydet(
                    category, prefix, "GÃ¼nlÃ¼k", "_gunluk"),
                icon: Icons.calendar_today,
                color: Colors.green),
            const Divider(),
            _buildDialogTile("ğŸ”• Kapat",
                () => _bildirimAyariniKaydet(category, prefix, "KapalÄ±", ""),
                icon: Icons.notifications_off, color: Colors.grey),
          ],
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
            "BaÅŸarÄ±lÄ±", "$cat bildirimleri '$gos' olarak ayarlandÄ±.");
      }
    } catch (e) {
      if (mounted) {
        _showInAppNotificationDialog(
            "Hata", "Ayar gÃ¼ncellenirken bir sorun oluÅŸtu.");
      }
    }
  }

  // --- GÄ°ZLÄ°LÄ°K POLÄ°TÄ°KASI PENCERESÄ° ---
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
            const Text("Gizlilik PolitikasÄ±",
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
                "PazarcÄ±k Portal resmi belediye veya kamu kurumu uygulamasÄ± deÄŸildir. "
                "Dernek/yerel topluluk hesabÄ± Ã¼zerinden yÃ¼rÃ¼tÃ¼len, kar amacÄ± gÃ¼tmeyen, "
                "satÄ±ÅŸ yeri olmayan ve yalnÄ±zca bilgilendirme, duyuru, yerel rehber ve "
                "topluluk iletiÅŸimi amacÄ± taÅŸÄ±yan baÄŸÄ±msÄ±z bir ÅŸehir portalÄ±dÄ±r.",
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
                  "PAZARCIK PORTAL GÄ°ZLÄ°LÄ°K POLÄ°TÄ°KASI VE KULLANIM ÅARTLARI\n\n"
                  "1. Kapsam ve AmacÄ±mÄ±z\n"
                  "PazarcÄ±k Portal ('Uygulama'), kullanÄ±cÄ±larÄ±n yerel iÅŸletmelere ulaÅŸmasÄ±nÄ±, ilan vermesini ve Ã§eÅŸitli hizmetlerden faydalanmasÄ±nÄ± saÄŸlayan bir bilgi, iletiÅŸim ve sergileme platformudur. Bu politika, kiÅŸisel verilerinizin nasÄ±l iÅŸlendiÄŸini ve platformun kullanÄ±m koÅŸullarÄ±nÄ± ÅŸeffaf bir ÅŸekilde belirler.\n\n"
                  "2. Veri Toplama ve KullanÄ±m AmacÄ±\n"
                  "UygulamamÄ±z; hizmetlerin doÄŸru ve eksiksiz sunulabilmesi, kullanÄ±cÄ± gÃ¼venliÄŸinin saÄŸlanmasÄ± ve uygulama iÃ§i sistemlerin Ã§alÄ±ÅŸabilmesi amacÄ±yla temel kullanÄ±cÄ± verilerini (ad, soyad, iletiÅŸim bilgileri vb.) Firebase altyapÄ±sÄ± Ã¼zerinden iÅŸler. Toplanan hiÃ§bir kiÅŸisel veri, hukuki bir zorunluluk (adli makamlarÄ±n resmi talepleri vb.) olmadÄ±kÃ§a 3. ÅŸahÄ±slarla, kurumlarla veya reklam ÅŸirketleriyle bilerek ve isteyerek paylaÅŸÄ±lmaz, satÄ±lamaz ve ticari amaÃ§la kullanÄ±lamaz.\n\n"
                  "3. Cihaz Ä°zinleri (Kamera ve Galeri)\n"
                  "Profil fotoÄŸrafÄ± gÃ¼ncelleme, maÄŸaza ilanÄ± verme veya istek/ÅŸikayet formlarÄ±na medya (resim/video) ekleme gibi iÅŸlemler iÃ§in cihazÄ±nÄ±zÄ±n kamera ve galeri eriÅŸimi talep edilir. Bu izinler yalnÄ±zca sizin onayÄ±nÄ±z ve inisiyatifinizle, uygulamanÄ±n Ã¶zelliklerini kullanabilmeniz iÃ§in istenir. Arka planda gizli bir veri Ã§ekimi yapÄ±lmaz.\n\n"
                  "4. Sorumluluk Reddi ve Platformun RolÃ¼ (Ã–NEMLÄ°)\n"
                  "PazarcÄ±k Portal, 5651 sayÄ±lÄ± yasa kapsamÄ±nda hukuki tanÄ±mÄ±yla yalnÄ±zca bir 'Yer SaÄŸlayÄ±cÄ±' ve dijital bir 'Sergileme AlanÄ±'dÄ±r.\n\n"
                  "â€¢ Uygulama Ã¼zerinden sergilenen hiÃ§bir Ã¼rÃ¼n, hizmet veya ilan Ã¼zerinden platformumuzca KOMÄ°SYON ALINMAMAKTADIR.\n"
                  "â€¢ Platformda yer alan ilanlarÄ±n, satÄ±lan Ã¼rÃ¼nlerin, verilen hizmetlerin kalitesi, teslimatÄ±, yasallÄ±ÄŸÄ± veya kullanÄ±cÄ±larÄ±n birbiriyle olan iletiÅŸimlerinin doÄŸruluÄŸu konusunda PazarcÄ±k Portal'Ä±n hiÃ§bir hukuki, maddi veya cezai sorumluluÄŸu BULUNMAMAKTADIR.\n"
                  "â€¢ AlÄ±cÄ± ve satÄ±cÄ± arasÄ±ndaki her tÃ¼rlÃ¼ ticari, maddi veya hukuki anlaÅŸmazlÄ±ktan doÄŸrudan doÄŸruya taraflarÄ±n kendileri sorumludur. PazarcÄ±k Portal yÃ¶netimi taraf, kefil veya hakem deÄŸildir.\n\n"
                  "5. KullanÄ±cÄ± YÃ¼kÃ¼mlÃ¼lÃ¼kleri\n"
                  "KullanÄ±cÄ±lar, uygulama iÃ§erisinde paylaÅŸtÄ±klarÄ± her tÃ¼rlÃ¼ iÃ§eriÄŸin, yazÄ±nÄ±n ve gÃ¶rselin TÃ¼rkiye Cumhuriyeti kanunlarÄ±na uygun olduÄŸunu peÅŸinen kabul eder. YasadÄ±ÅŸÄ±, yanÄ±ltÄ±cÄ±, telif hakkÄ± ihlali iÃ§eren veya suÃ§ teÅŸkil eden her tÃ¼rlÃ¼ iÃ§erikte tÃ¼m hukuki ve cezai sorumluluk tamamen paylaÅŸÄ±mÄ± yapan kiÅŸiye aittir.\n\n"
                  "UygulamayÄ± kullanan her birey, KVKK aydÄ±nlatma metnini, bu gizlilik politikasÄ±nÄ± ve kullanÄ±m ÅŸartlarÄ±nÄ± okumuÅŸ, anlamÄ±ÅŸ ve eksiksiz olarak kabul etmiÅŸ sayÄ±lÄ±r.",
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
                child: const Text("AnladÄ±m"),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- YARDIMCI METOTLAR ---
  Widget _buildDialogTile(String title, VoidCallback onTap,
      {IconData? icon, Color? color}) {
    return ListTile(
      leading: icon != null ? Icon(icon, color: color) : null,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

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
              role == 'yÃ¶netici' ||
              userData['isAdmin'] == true ||
              userData['admin'] == true ||
              _hasAdminClaim;
          bool isApproved = userData['isApproved'] ?? false;
          String imageUrl = userData['image'] ?? "";
          String fullname = userData['fullname'] ?? "PazarcÄ±klÄ±";
          String phone = userData['phone'] ?? "Telefon kayÄ±tlÄ± deÄŸil";

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // --- PROFÄ°L FOTOÄRAFI ---
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
                              : const AssetImage('assets/images/user.png')
                                  as ImageProvider,
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
                _buildSectionTitle("Hesap AyarlarÄ±"),
                _buildMenuCard(isDark, [
                  _menuItem(Icons.person_outline, "KiÅŸisel Bilgiler",
                      isDark: isDark,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const EditProfile()))),
                  if (!isAdmin)
                    _menuItem(Icons.shopping_bag_outlined, "SipariÅŸlerim",
                        isDark: isDark,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const MyOrdersScreen()))),
                  if (isAdmin)
                    _menuItem(Icons.admin_panel_settings, "YÃ¶netici Paneli",
                        isDark: isDark,
                        color: Colors.red,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const AdminPanelScreen()))),
                  if (role == 'satici' && isApproved)
                    _menuItem(Icons.dashboard_customize, "MaÄŸazamÄ± YÃ¶net",
                        isDark: isDark,
                        color: Colors.green,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => DashboardScreen()))),
                  if (role == 'customer')
                    _menuItem(
                      Icons.storefront,
                      "Esnaf HesabÄ± AÃ§",
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
                    _menuItem(Icons.hourglass_empty, "BaÅŸvuru Ä°nceleniyor",
                        isDark: isDark, color: Colors.grey),
                ]),

                const SizedBox(height: 25),

                // --- 2. GRUP: Ä°ÅLETME REHBERÄ° ---
                _buildSectionTitle("Ä°ÅŸletme Rehberi"),
                _buildMenuCard(isDark, [
                  _menuItem(Icons.add_business_outlined, "Ä°ÅŸletmemi Ekle",
                      isDark: isDark,
                      color: const Color(0xFF004D40),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const BusinessAddPage(
                                  existingBusiness: {}, docId: '')))),
                  _menuItem(Icons.list_alt_outlined, "Ä°ÅŸletmelerimi YÃ¶net",
                      isDark: isDark,
                      color: Colors.blueGrey,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MyBusinessesPage()))),
                ]),

                const SizedBox(height: 25),

                // --- 3. GRUP: Ä°Å & KARÄ°YER ---
                _buildSectionTitle("Ä°ÅŸ & Kariyer"),
                _buildMenuCard(isDark, [
                  _menuItem(Icons.work_outline, "Ä°ÅŸ Ä°lanÄ± Ver",
                      isDark: isDark,
                      color: const Color(0xFF0284C7),
                      onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (context) => const AddJobPage()))),
                  _menuItem(
                      Icons.manage_search_outlined, "Ä°ÅŸ Ä°lanlarÄ±mÄ± YÃ¶net",
                      isDark: isDark, color: Colors.deepPurple, onTap: () {
                    debugPrint("Ä°ÅŸ ilanlarÄ±m sayfasÄ±na gidilecek");
                  }),
                ]),

                const SizedBox(height: 25),

                // --- 4. GRUP: BÄ°LDÄ°RÄ°M VE UYGULAMA ---
                _buildSectionTitle("Uygulama AyarlarÄ±"),
                _buildMenuCard(isDark, [
                  // ğŸ”¥ KaranlÄ±k Mod (Sorun Ã§Ã¶zÃ¼ldÃ¼!)
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined,
                        color: Colors.indigo),
                    title: Text("KaranlÄ±k Mod",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black)),
                    trailing: CupertinoSwitch(
                      value: isDark,
                      activeTrackColor: primaryColor,
                      onChanged: (v) async {
                        // BURASI Ã–NEMLÄ°: State'i zorla gÃ¼ncelliyoruz!
                        setState(() {});
                        isDarkModeNotifier.value = v;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('darkMode', v);
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 50),
                  // Namaz Bildirimleri (AÃ§/Kapat)
                  ListTile(
                    leading: const Icon(CupertinoIcons.moon_stars,
                        color: Colors.teal),
                    title: Text("Namaz Vakti UyarÄ±larÄ±",
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
                  // Haber Bildirimleri (DetaylÄ±)
                  _menuItem(
                      Icons.notifications_active_outlined, "Haber Bildirimleri",
                      isDark: isDark,
                      color: Colors.orange,
                      onTap: _showNotificationCategoryDialog),
                ]),

                const SizedBox(height: 25),

                // --- 5. GRUP: DESTEK ---
                _buildSectionTitle("Destek & Ä°letiÅŸim"),
                _buildMenuCard(isDark, [
                  _menuItem(Icons.message_outlined, "Ä°stek & Åikayet",
                      isDark: isDark,
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                          context,
                          CupertinoPageRoute(
                              builder: (context) =>
                                  const RequestComplaintPage()))),
                  _menuItem(Icons.privacy_tip_outlined, "Gizlilik PolitikasÄ±",
                      isDark: isDark, onTap: _showPrivacyPolicy),
                  _menuItem(Icons.info_outline, "Uygulama HakkÄ±nda",
                      isDark: isDark, trailingText: _appVersion),
                ]),

                const SizedBox(height: 40),

                // --- Ã‡IKIÅ YAP ---
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
                      Text("Ã‡Ä±kÄ±ÅŸ Yap",
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
