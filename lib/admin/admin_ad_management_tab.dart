import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/modern_app_splash_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../business/merchant_ad_service.dart';

/// Yönetim Merkezi - Kapsamlı Reklam, Paket, Fiyat, Madde ve Başvuru Yönetimi
class AdminAdManagementTab extends StatefulWidget {
  const AdminAdManagementTab({Key? key}) : super(key: key);

  @override
  State<AdminAdManagementTab> createState() => _AdminAdManagementTabState();
}

class _AdminAdManagementTabState extends State<AdminAdManagementTab> {
  int _currentSubTab = 0; // 0: Paketler, 1: Restoran Paketi, 2: Tekil Hizmetler, 3: 4K Açılış Ekranı, 4: Ayarlar, 5: Başvurular

  // Açılış / Karşılama Ekranı (4K Video & Görsel) Kontrolcüleri
  bool _splashActive = true;
  String _splashMediaType = 'video';
  final _splashMediaUrlCtrl = TextEditingController(text: 'https://assets.mixkit.co/videos/preview/mixkit-serving-dinner-to-a-table-in-a-restaurant-41484-large.mp4');
  final _splashBadgeCtrl = TextEditingController(text: 'GÜNÜN SPONSORU 💎');
  final _splashTitleCtrl = TextEditingController(text: "Saray Sofrası'nda %20 Açılış İndirimi Başladı!");
  final _splashBodyCtrl = TextEditingController(text: "Pazarcık'ın en sevilen lezzetleri ve fırın yemekleri portal üzerinden anında kapınızda. Hemen menüyü inceleyin!");
  final _splashButtonTextCtrl = TextEditingController(text: 'Menüyü İncele & Sipariş Ver ➔');
  final _splashLinkUrlCtrl = TextEditingController(text: '/reklam-paketleri');
  int _splashAutoCloseSeconds = 6;
  String _splashFrequency = 'always';
  bool _splashAllowSkip = true;
  bool _isSavingSplash = false;
  bool _splashDataLoaded = false;
  bool _isUploadingMedia = false;
  double _uploadProgress = 0.0;
  String? _uploadStatusText;


  // Genel ayar kontrolcüleri
  final _whatsappCtrl = TextEditingController();
  final _supportCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _vatCtrl = TextEditingController(text: '18');
  final _discount3Ctrl = TextEditingController(text: '15');
  final _discount6Ctrl = TextEditingController(text: '25');
  final _discount12Ctrl = TextEditingController(text: '35');

  bool _isSavingSettings = false;
  bool _settingsInitialized = false;
  String _selectedStatusFilter = 'all';

  @override
  void dispose() {
    _splashMediaUrlCtrl.dispose();
    _splashBadgeCtrl.dispose();
    _splashTitleCtrl.dispose();
    _splashBodyCtrl.dispose();
    _splashButtonTextCtrl.dispose();
    _splashLinkUrlCtrl.dispose();
    _whatsappCtrl.dispose();
    _supportCtrl.dispose();
    _instagramCtrl.dispose();
    _vatCtrl.dispose();
    _discount3Ctrl.dispose();
    _discount6Ctrl.dispose();
    _discount12Ctrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSplashData();
  }

  Future<void> _loadSplashData() async {
    if (_splashDataLoaded) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('app_settings').doc('startup_announcement').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _splashActive = data['isActive'] == true;
          _splashMediaType = (data['mediaType'] ?? 'video').toString();
          _splashMediaUrlCtrl.text = (data['mediaUrl'] ?? '').toString();
          _splashBadgeCtrl.text = (data['badgeText'] ?? 'GÜNÜN SPONSORU 💎').toString();
          _splashTitleCtrl.text = (data['title'] ?? '').toString();
          _splashBodyCtrl.text = (data['body'] ?? '').toString();
          _splashButtonTextCtrl.text = (data['buttonText'] ?? 'Fırsatı İncele ➔').toString();
          _splashLinkUrlCtrl.text = (data['linkUrl'] ?? '').toString();
          _splashAutoCloseSeconds = (data['autoCloseSeconds'] as num?)?.toInt() ?? 6;
          _splashFrequency = (data['showFrequency'] ?? 'always').toString();
          _splashAllowSkip = data['allowSkip'] != false;
          _splashDataLoaded = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadMedia() async {
    final isVideo = _splashMediaType == 'video';
    final picker = ImagePicker();

    try {
      final XFile? file = isVideo
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);

      if (file == null) return;

      setState(() {
        _isUploadingMedia = true;
        _uploadProgress = 0.0;
        _uploadStatusText = 'Dosya hazırlanıyor: ${file.name}...';
      });

      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : (isVideo ? 'mp4' : 'jpg');
      final contentType = isVideo
          ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4')
          : (ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg');

      final storagePath = 'startup_announcements/${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      final ref = FirebaseStorage.instance.ref().child(storagePath);

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _uploadStatusText = 'Yükleniyor: %${(progress * 100).toInt()}';
            });
          }
        }
      });

      final snap = await uploadTask;
      final downloadUrl = await snap.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _splashMediaUrlCtrl.text = downloadUrl;
          _isUploadingMedia = false;
          _uploadProgress = 1.0;
          _uploadStatusText = '✅ Yükleme tamamlandı!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${file.name} başarıyla yüklendi!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[AdminAdManagementTab] Medya yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
          _uploadStatusText = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Medya yüklenirken hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveSplashData() async {
    setState(() => _isSavingSplash = true);
    try {
      await FirebaseFirestore.instance.collection('app_settings').doc('startup_announcement').set({
        'isActive': _splashActive,
        'mediaType': _splashMediaType,
        'mediaUrl': _splashMediaUrlCtrl.text.trim(),
        'badgeText': _splashBadgeCtrl.text.trim(),
        'title': _splashTitleCtrl.text.trim(),
        'body': _splashBodyCtrl.text.trim(),
        'buttonText': _splashButtonTextCtrl.text.trim(),
        'linkUrl': _splashLinkUrlCtrl.text.trim(),
        'autoCloseSeconds': _splashAutoCloseSeconds,
        'showFrequency': _splashFrequency,
        'allowSkip': _splashAllowSkip,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 4K Açılış Ekranı & Sponsorluk ayarları canlıya alındı!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSplash = false);
    }
  }

  void _previewSplash() {
    final previewModel = StartupAnnouncementModel(
      isActive: true,
      mediaType: _splashMediaType,
      mediaUrl: _splashMediaUrlCtrl.text.trim(),
      badgeText: _splashBadgeCtrl.text.trim(),
      title: _splashTitleCtrl.text.trim().isNotEmpty ? _splashTitleCtrl.text.trim() : 'Örnek Başlık',
      body: _splashBodyCtrl.text.trim().isNotEmpty ? _splashBodyCtrl.text.trim() : 'Örnek açıklama metni...',
      buttonText: _splashButtonTextCtrl.text.trim().isNotEmpty ? _splashButtonTextCtrl.text.trim() : 'Fırsatı İncele ➔',
      linkUrl: _splashLinkUrlCtrl.text.trim(),
      autoCloseSeconds: _splashAutoCloseSeconds,
      showFrequency: _splashFrequency,
      allowSkip: true,
    );

    ModernAppSplashScreen.show(context, previewModel);
  }

  void _populateSettingsFromConfig(AdConfigModel config) {
    if (_settingsInitialized) return;
    _whatsappCtrl.text = config.whatsappPhone;
    _supportCtrl.text = config.supportPhone;
    _instagramCtrl.text = config.instagramUsername;
    _vatCtrl.text = config.vatRate.toString();
    _discount3Ctrl.text = (config.periodDiscounts[3] ?? 15).toString();
    _discount6Ctrl.text = (config.periodDiscounts[6] ?? 25).toString();
    _discount12Ctrl.text = (config.periodDiscounts[12] ?? 35).toString();
    _settingsInitialized = true;
  }

  Future<void> _saveGeneralSettings() async {
    setState(() => _isSavingSettings = true);
    try {
      final vat = int.tryParse(_vatCtrl.text.trim()) ?? 18;
      final d3 = int.tryParse(_discount3Ctrl.text.trim()) ?? 15;
      final d6 = int.tryParse(_discount6Ctrl.text.trim()) ?? 25;
      final d12 = int.tryParse(_discount12Ctrl.text.trim()) ?? 35;

      await MerchantAdService.instance.updateGeneralAndDiscountSettings(
        whatsappPhone: _whatsappCtrl.text.trim(),
        supportPhone: _supportCtrl.text.trim(),
        instagramUsername: _instagramCtrl.text.trim(),
        vatRate: vat,
        periodDiscounts: {
          '1': 0,
          '3': d3,
          '6': d6,
          '12': d12,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ İletişim ve İndirim Ayarları Başarıyla Kaydedildi!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ayarlar kaydedilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdConfigModel>(
      stream: MerchantAdService.instance.streamConfig(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }

        final config = snapshot.data!;
        _populateSettingsFromConfig(config);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: Column(
            children: [
              // Üst Gezinme / Segment Menü
              _buildSubNavigationHeader(),
              // İçerik Alanı
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: _buildSubTabContent(config),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  // Üst Gezinme Menüsü (Segment Bar)
  // ─────────────────────────────────────────────────────────
  Widget _buildSubNavigationHeader() {
    final tabs = [
      {'icon': Icons.inventory_2_rounded, 'title': 'Esnaf Paketleri'},
      {'icon': Icons.restaurant_menu_rounded, 'title': 'Restoran & Kafe'},
      {'icon': Icons.widgets_rounded, 'title': 'Tekil Hizmetler'},
      {'icon': Icons.smart_display_rounded, 'title': '🎬 4K Açılış Ekranı'},
      {'icon': Icons.settings_phone_rounded, 'title': 'İletişim & İndirim'},
      {'icon': Icons.notifications_active_rounded, 'title': 'Gelen Başvurular'},
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _currentSubTab == index;
            final tab = tabs[index];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _currentSubTab = index),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab['title'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSubTabContent(AdConfigModel config) {
    switch (_currentSubTab) {
      case 0:
        return _buildPackagesTab(config);
      case 1:
        return _buildRestaurantPackageTab(config);
      case 2:
        return _buildSingleServicesTab(config);
      case 3:
        return _buildSplashScreenManagerTab();
      case 4:
        return _buildGeneralSettingsTab(config);
      case 5:
      default:
        return _buildApplicationsTab();
    }
  }

  // ─────────────────────────────────────────────────────────
  // SEKME 1: ESNAF REKLAM PAKETLERİ (LİSTE, DÜZENLE, YENİ EKLE, SİL)
  // ─────────────────────────────────────────────────────────
  Widget _buildPackagesTab(AdConfigModel config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst Bilgi ve "Yeni Paket Ekle" Butonu
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esnaf Reklam Paketleri Yönetimi 📢',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tüm paketlerin fiyatlarını, başlıklarını, kotalarını ve maddelerini buradan anında güncelleyebilirsiniz.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _openPackageEditModal(context, null),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                'Yeni Paket Oluştur',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Paket Kartları Listesi
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: config.packages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final pkg = config.packages[index];
            return _buildPackageAdminCard(pkg);
          },
        ),
      ],
    );
  }

  Widget _buildPackageAdminCard(AdPackageModel pkg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pkg.isPopular ? const Color(0xFF6366F1).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          width: pkg.isPopular ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık Satırı
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pkg.name,
                            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                          ),
                        ),
                        if (pkg.badge.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pkg.badge,
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFFB45309)),
                            ),
                          ),
                        ],
                        if (pkg.isPopular) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Popüler 🔥',
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (pkg.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        pkg.subtitle,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              // Fiyat Göstergesi
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${pkg.baseMonthlyPrice.toInt()} ₺',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    '/ Ay (KDV Hariç)',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Kota ve Kapsam Özeti Rozetleri
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMiniBadge(Icons.auto_stories_rounded, 'Günde ${pkg.dailyStories} Hikaye'),
              _buildMiniBadge(Icons.grid_on_rounded, 'Haftada ${pkg.weeklyPosts} Gönderi'),
              _buildMiniBadge(Icons.notifications_rounded, '${pkg.pushNotifications} Bildirim'),
              if (pkg.appStoriesVisible) _buildMiniBadge(Icons.phone_android_rounded, 'Mobil & Web Vitrin'),
              if (pkg.splashBannerDiscount) _buildMiniBadge(Icons.star_rounded, '%50 Karşılama İndirimi'),
              if (pkg.instagramPinDiscount) _buildMiniBadge(Icons.push_pin_rounded, '%50 Sabitleme İndirimi'),
            ],
          ),
          const SizedBox(height: 14),

          // Paket Maddeleri / Avantajları Başlığı ve Listesi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paket Maddeleri (${pkg.perks.length} Madde):',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
                    ),
                    Text(
                      'ID: ${pkg.id}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...pkg.perks.map((perk) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              perk,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Düzenle & Sil Butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (pkg.id != 'starter' && pkg.id != 'growth' && pkg.id != 'premium')
                OutlinedButton.icon(
                  onPressed: () => _confirmDeletePackage(pkg),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: Text('Paketi Sil', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openPackageEditModal(context, pkg),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text('Tüm Fiyat & Maddeleri Düzenle', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF475569)),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SEKME 2: RESTORAN & KAFE SİPARİŞ PAKETİ (YILLIK)
  // ─────────────────────────────────────────────────────────
  Widget _buildRestaurantPackageTab(AdConfigModel config) {
    final restPkg = config.restaurantPackage ?? MerchantAdService.defaultRestaurantPackage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restoran & Kafe Sipariş Paketi (Yıllık Çözüm) 🍽️',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Komisyonsuz sipariş, QR menü, yapay zeka kalori/alerjen tespiti ve masa adisyon paketinin fiyat ve maddelerini buradan yönetin.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _openRestaurantEditModal(context, restPkg),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: Text(
                'Paketi ve Maddeleri Düzenle',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCCFBF1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            restPkg.badge,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF0F766E)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          restPkg.name,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          restPkg.subtitle,
                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${restPkg.yearlyPrice.toInt()} ₺',
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0D9488)),
                      ),
                      Text(
                        '/ Yıllık (KDV Hariç)',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 28),

              Text(
                'Paket İçeriği ve Yasal Uyum Maddeleri (${restPkg.perks.length} Özellik):',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF99F6E4)),
                ),
                child: Column(
                  children: restPkg.perks.map((perk) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF0D9488)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              perk,
                              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF134E4A), height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // SEKME 3: TEKİL / MODÜLER REKLAM HİZMETLERİ
  // ─────────────────────────────────────────────────────────
  Widget _buildSingleServicesTab(AdConfigModel config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tekil / Modüler Reklam Hizmetleri 🧩',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Instagram hikaye, gönderi, başa tutturma, push bildirim ve açılış ekranı fiyatlarını buradan belirleyin.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _openSingleServiceEditModal(context, null),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                'Yeni Hizmet Ekle',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 450,
            mainAxisExtent: 220,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: config.singleServices.length,
          itemBuilder: (context, index) {
            final svc = config.singleServices[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          svc.title,
                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${svc.price.toInt()} ₺',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Birim: ${svc.unit} ${svc.badge.isNotEmpty ? '• ${svc.badge}' : ''}',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      svc.description,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openSingleServiceEditModal(context, svc),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          side: const BorderSide(color: Color(0xFFC7D2FE)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.edit, size: 14),
                        label: Text('Fiyat & Metin Düzenle', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // SEKME 4: İLETİŞİM, KDV VE DÖNEMSEL İNDİRİM AYARLARI
  // ─────────────────────────────────────────────────────────
  Widget _buildGeneralSettingsTab(AdConfigModel config) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.phone_badge_plus, color: Color(0xFF059669), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İletişim, WhatsApp ve İndirim Oranları ⚙️',
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Web ve uygulamada esnafa sunulan iletişim numaraları ve 3/6/12 aylık paket indirimleri.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),

          Text(
            'İletişim & Sosyal Medya Bilgileri:',
            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: _whatsappCtrl,
                  label: 'WhatsApp Destek Hattı *',
                  hint: 'Örn: 05xx xxx xx xx',
                  icon: CupertinoIcons.chat_bubble_fill,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInput(
                  controller: _supportCtrl,
                  label: 'Doğrudan Arama Numarası',
                  hint: 'Örn: 05xx xxx xx xx',
                  icon: CupertinoIcons.phone_fill,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: _instagramCtrl,
                  label: 'Resmi Instagram Kullanıcı Adı',
                  hint: 'pazarcikportal',
                  icon: CupertinoIcons.camera_fill,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInput(
                  controller: _vatCtrl,
                  label: 'KDV Oranı (%)',
                  hint: '18',
                  icon: CupertinoIcons.percent,
                  keyboard: TextInputType.number,
                ),
              ),
            ],
          ),
          const Divider(height: 32),

          Text(
            'Dönemsel Paket İndirim Oranları (%):',
            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            'Esnaf 3 aylık, 6 aylık veya yıllık satın alım seçtiğinde uygulanacak yüzde indirimler.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: _discount3Ctrl,
                  label: '3 Aylık İndirim (%)',
                  hint: '15',
                  icon: CupertinoIcons.percent,
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInput(
                  controller: _discount6Ctrl,
                  label: '6 Aylık İndirim (%)',
                  hint: '25',
                  icon: CupertinoIcons.percent,
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInput(
                  controller: _discount12Ctrl,
                  label: '1 Yıllık İndirim (%)',
                  hint: '35',
                  icon: CupertinoIcons.percent,
                  keyboard: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSavingSettings ? null : _saveGeneralSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: _isSavingSettings
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.checkmark_alt, size: 16),
              label: Text(
                _isSavingSettings ? 'Kaydediliyor...' : 'Tüm Ayarları Kaydet',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SEKME 5: GELEN REKLAM BAŞVURULARI & TALEPLER
  // ─────────────────────────────────────────────────────────
  Widget _buildApplicationsTab() {
    Query query = FirebaseFirestore.instance.collection('ad_package_requests').orderBy('createdAt', descending: true);
    if (_selectedStatusFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedStatusFilter);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gelen Esnaf Reklam Talepleri 📢',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                ),
                Text(
                  'Web ve uygulamadan başvuran işletmelerin form kayıtları.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            DropdownButton<String>(
              value: _selectedStatusFilter,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Tümü')),
                DropdownMenuItem(value: 'pending', child: Text('Bekleyenler')),
                DropdownMenuItem(value: 'contacted', child: Text('Görüşüldü')),
                DropdownMenuItem(value: 'approved', child: Text('Onaylandı / Yayında')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedStatusFilter = val);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(32), child: CupertinoActivityIndicator()));
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(CupertinoIcons.doc_text_search, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz reklam başvurusu bulunmuyor',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Web sitesi veya uygulamadan yapılan başvurular anında buraya yansıyacaktır.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildRequestCard(doc.id, data);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequestCard(String docId, Map<String, dynamic> data) {
    final businessName = data['businessName'] ?? 'İsimsiz İşletme';
    final contactName = data['contactName'] ?? 'İsimsiz Yetkili';
    final phone = data['phone'] ?? '';
    final itemName = data['itemName'] ?? 'Paket';
    final periodLabel = data['periodLabel'] ?? '';
    final totalPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
    final totalWithVat = (data['totalWithVat'] as num?)?.toDouble() ?? (totalPrice * 1.18);
    final status = data['status'] ?? 'pending';
    final note = data['note'] ?? '';
    final taxNo = data['taxNo'] ?? '';

    DateTime? createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    }

    Color statusColor;
    String statusText;
    switch (status) {
      case 'contacted':
        statusColor = const Color(0xFF0284C7);
        statusText = 'İletişime Geçildi';
        break;
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusText = 'Onaylandı / Yayında';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'İptal Edildi';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'Yeni Başvuru (Bekliyor)';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  businessName,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Yetkili: $contactName • $phone',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Talep: $itemName ($periodLabel)',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Net: ${totalPrice.toInt()} ₺ | +%18 KDV Dahil: ${totalWithVat.toInt()} ₺',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '📜 Sözleşme Onaylı',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF059669)),
                  ),
                ),
              ],
            ),
          ),
          if (taxNo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Fatura / Vergi No: $taxNo',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600),
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Not: "$note"',
              style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 8),
          if (createdAt != null)
            Text(
              'Tarih: ${DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(createdAt)}',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
            ),
          const Divider(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _openWhatsApp(phone, businessName, itemName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(CupertinoIcons.chat_bubble_fill, size: 14),
                label: Text('WhatsApp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _makeCall(phone),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(CupertinoIcons.phone_fill, size: 14),
                label: Text('Ara', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: const Icon(CupertinoIcons.ellipsis_circle, color: Color(0xFF64748B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (action) {
                  if (action == 'delete') {
                    _deleteRequest(docId);
                  } else {
                    _updateRequestStatus(docId, action);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'contacted', child: Text('Görüşüldü Yap')),
                  const PopupMenuItem(value: 'approved', child: Text('Onaylandı / Yayında')),
                  const PopupMenuItem(value: 'pending', child: Text('Bekliyor Yap')),
                  const PopupMenuItem(value: 'rejected', child: Text('İptal Et')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // MODALLAR VE DÜZENLEME PENCERELERİ
  // ─────────────────────────────────────────────────────────

  /// Esnaf Paketi Düzenleme ve Yeni Paket Oluşturma Modalı
  void _openPackageEditModal(BuildContext context, AdPackageModel? existing) {
    final isNew = existing == null;

    final idCtrl = TextEditingController(text: existing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    final badgeCtrl = TextEditingController(text: existing?.badge ?? 'ÖZEL PAKET ⭐');
    final priceCtrl = TextEditingController(text: existing?.baseMonthlyPrice.toInt().toString() ?? '1000');
    final storiesCtrl = TextEditingController(text: existing?.dailyStories.toString() ?? '1');
    final postsCtrl = TextEditingController(text: existing?.weeklyPosts.toString() ?? '2');
    final pushCtrl = TextEditingController(text: existing?.pushNotifications.toString() ?? '1');
    final recommendedCtrl = TextEditingController(text: existing?.recommendedFor ?? '');

    bool isPopular = existing?.isPopular ?? false;
    bool appStoriesVisible = existing?.appStoriesVisible ?? true;
    bool splashBannerDiscount = existing?.splashBannerDiscount ?? false;
    bool instagramPinDiscount = existing?.instagramPinDiscount ?? false;

    // Maddeler listesi kopyası
    final perksList = List<String>.from(existing?.perks ?? [
      'Pazarcık Portal Instagram’da Günde 1 Hikaye (Ayda 30 Hikaye)',
      'Haftalık 1 Adet Sabit Akış Gönderisi (Ayda 4 Gönderi)',
      '💥 Esnek Kota: Günlük haklarınızı biriktirip kampanya günlerinde toplu yayınlatabilme imkanı',
      'Mobil Uygulama & Web "Hikayeler Vitrini"nde 1 Ay Sabit Görünüm',
      'Matbaa ve reklam işlerinde anlaşmalı kurumlarda %20 indirim',
      'Adınıza / Firmanıza Resmi Faturalı Hizmet (+%18 KDV)',
    ]);

    final newPerkCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(isNew ? Icons.add_box_rounded : Icons.edit_note_rounded, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    isNew ? 'Yeni Paket Oluştur' : 'Paketi & Maddeleri Düzenle',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNew) ...[
                        _buildInput(controller: idCtrl, label: 'Paket ID (Benzersiz Kod)', hint: 'ozel_paket', icon: Icons.vpn_key_rounded),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildInput(controller: nameCtrl, label: 'Paket Adı *', hint: 'Örn: Ramazan Özel Paketi', icon: Icons.label_rounded),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInput(controller: badgeCtrl, label: 'Rozet Metni', hint: 'EN ÇOK TERCİH EDİLEN 🔥', icon: Icons.bookmark_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInput(controller: subtitleCtrl, label: 'Kısa Açıklama', hint: 'Bu paketin hedeflediği avantaj nedir?', icon: Icons.description_rounded),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput(
                              controller: priceCtrl,
                              label: 'Aylık Fiyat (TL) *',
                              hint: '1000',
                              icon: Icons.payments_rounded,
                              keyboard: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInput(
                              controller: storiesCtrl,
                              label: 'Günde Hikaye',
                              hint: '1',
                              icon: Icons.auto_stories_rounded,
                              keyboard: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInput(
                              controller: postsCtrl,
                              label: 'Haftada Gönderi',
                              hint: '2',
                              icon: Icons.grid_on_rounded,
                              keyboard: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInput(
                              controller: pushCtrl,
                              label: 'Bildirim Adedi',
                              hint: '1',
                              icon: Icons.notifications_rounded,
                              keyboard: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInput(controller: recommendedCtrl, label: 'Kimler İçin Uygun?', hint: 'Restoranlar, kafeler, butikler...', icon: Icons.people_rounded),
                      const SizedBox(height: 14),

                      // Seçenek Switch'leri
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildSwitchItem('Popüler Rozeti', isPopular, (val) => setModalState(() => isPopular = val)),
                          _buildSwitchItem('Uygulama Hikaye Vitrini', appStoriesVisible, (val) => setModalState(() => appStoriesVisible = val)),
                          _buildSwitchItem('%50 Açılış Ekranı İndirimi', splashBannerDiscount, (val) => setModalState(() => splashBannerDiscount = val)),
                          _buildSwitchItem('%50 Başa Tutturma İndirimi', instagramPinDiscount, (val) => setModalState(() => instagramPinDiscount = val)),
                        ],
                      ),
                      const Divider(height: 28),

                      // Maddeler (Perks) Yönetimi
                      Text(
                        'Paket Maddeleri / Avantajları (${perksList.length} Madde):',
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),

                      // Yeni Madde Ekleme Alanı
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newPerkCtrl,
                              style: GoogleFonts.inter(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Yeni madde yazın (örn: Sarı Onay Rozeti, Matbaa indirimi vb.)...',
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  setModalState(() {
                                    perksList.add(val.trim());
                                    newPerkCtrl.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (newPerkCtrl.text.trim().isNotEmpty) {
                                setModalState(() {
                                  perksList.add(newPerkCtrl.text.trim());
                                  newPerkCtrl.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Ekle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Maddeler Listesi
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: perksList.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, pIdx) {
                            final perk = perksList[pIdx];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                              title: Text(perk, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B))),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                tooltip: 'Maddeyi Sil',
                                onPressed: () {
                                  setModalState(() => perksList.removeAt(pIdx));
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Vazgeç', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen paket adını girin.')));
                      return;
                    }

                    final updatedPackage = AdPackageModel(
                      id: idCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
                      name: nameCtrl.text.trim(),
                      subtitle: subtitleCtrl.text.trim(),
                      badge: badgeCtrl.text.trim(),
                      isPopular: isPopular,
                      baseMonthlyPrice: double.tryParse(priceCtrl.text.trim()) ?? 1000.0,
                      dailyStories: int.tryParse(storiesCtrl.text.trim()) ?? 1,
                      weeklyPosts: int.tryParse(postsCtrl.text.trim()) ?? 1,
                      pushNotifications: int.tryParse(pushCtrl.text.trim()) ?? 1,
                      appStoriesVisible: appStoriesVisible,
                      splashBannerDiscount: splashBannerDiscount,
                      instagramPinDiscount: instagramPinDiscount,
                      perks: perksList,
                      recommendedFor: recommendedCtrl.text.trim(),
                    );

                    Navigator.pop(dialogCtx);
                    try {
                      await MerchantAdService.instance.savePackage(updatedPackage);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ "${updatedPackage.name}" başarıyla kaydedildi!'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isNew ? 'Paketi Oluştur' : 'Değişiklikleri Kaydet', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Restoran & Kafe Paketi Düzenleme Modalı
  void _openRestaurantEditModal(BuildContext context, RestaurantPackageModel current) {
    final nameCtrl = TextEditingController(text: current.name);
    final subtitleCtrl = TextEditingController(text: current.subtitle);
    final badgeCtrl = TextEditingController(text: current.badge);
    final priceCtrl = TextEditingController(text: current.yearlyPrice.toInt().toString());
    final perksList = List<String>.from(current.perks);
    final newPerkCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Text(
                    'Restoran & Kafe Paketini Düzenle',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInput(controller: nameCtrl, label: 'Paket Adı *', hint: 'Restoran Paketi', icon: Icons.label_rounded),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildInput(controller: badgeCtrl, label: 'Rozet Metni', hint: 'YILLIK TEK PAKET ⭐ %0 KOMİSYON', icon: Icons.bookmark_rounded),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInput(
                              controller: priceCtrl,
                              label: 'Yıllık Fiyat (TL) *',
                              hint: '5950',
                              icon: Icons.payments_rounded,
                              keyboard: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInput(controller: subtitleCtrl, label: 'Açıklama', hint: 'Paket hakkında özet bilgi', icon: Icons.description_rounded),
                      const Divider(height: 28),

                      Text(
                        'Paket Maddeleri (${perksList.length} Madde):',
                        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newPerkCtrl,
                              style: GoogleFonts.inter(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Yeni restoran avantajı ekleyin...',
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  setModalState(() {
                                    perksList.add(val.trim());
                                    newPerkCtrl.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (newPerkCtrl.text.trim().isNotEmpty) {
                                setModalState(() {
                                  perksList.add(newPerkCtrl.text.trim());
                                  newPerkCtrl.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Ekle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: perksList.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, pIdx) {
                            final perk = perksList[pIdx];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF0D9488)),
                              title: Text(perk, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E293B))),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                tooltip: 'Maddeyi Sil',
                                onPressed: () {
                                  setModalState(() => perksList.removeAt(pIdx));
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Vazgeç', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final updated = RestaurantPackageModel(
                      id: current.id,
                      name: nameCtrl.text.trim(),
                      subtitle: subtitleCtrl.text.trim(),
                      badge: badgeCtrl.text.trim(),
                      yearlyPrice: double.tryParse(priceCtrl.text.trim()) ?? 5950.0,
                      perks: perksList,
                    );

                    Navigator.pop(dialogCtx);
                    try {
                      await MerchantAdService.instance.saveRestaurantPackage(updated);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Restoran paketi başarıyla güncellendi!'), backgroundColor: Color(0xFF0D9488)),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Kaydet', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Tekil Reklam Hizmeti Düzenleme ve Ekleme Modalı
  void _openSingleServiceEditModal(BuildContext context, SingleServiceModel? existing) {
    final isNew = existing == null;

    final idCtrl = TextEditingController(text: existing?.id ?? 'service_${DateTime.now().millisecondsSinceEpoch}');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'Adet');
    final priceCtrl = TextEditingController(text: existing?.price.toInt().toString() ?? '100');
    final badgeCtrl = TextEditingController(text: existing?.badge ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final highlightCtrl = TextEditingController(text: existing?.highlight ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isNew ? 'Yeni Tekil Reklam Hizmeti Ekle' : 'Hizmeti Düzenle',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (isNew) ...[
                    _buildInput(controller: idCtrl, label: 'Hizmet ID (Kod)', hint: 'service_kod', icon: Icons.vpn_key_rounded),
                    const SizedBox(height: 12),
                  ],
                  _buildInput(controller: titleCtrl, label: 'Hizmet Başlığı *', hint: 'Örn: Instagram Hikaye Paylaşımı', icon: Icons.title_rounded),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInput(controller: unitCtrl, label: 'Birim *', hint: 'Günlük / 1 Hikaye', icon: Icons.access_time_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInput(
                          controller: priceCtrl,
                          label: 'Fiyat (TL) *',
                          hint: '100',
                          icon: Icons.payments_rounded,
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInput(controller: badgeCtrl, label: 'Rozet Metni', hint: 'HIZLI DÖNÜŞ', icon: Icons.bookmark_rounded),
                  const SizedBox(height: 12),
                  _buildInput(controller: descCtrl, label: 'Detaylı Açıklama', hint: 'Hizmetin kapsamı nedir?', icon: Icons.description_rounded),
                  const SizedBox(height: 12),
                  _buildInput(controller: highlightCtrl, label: 'Vurgu / Avantaj Notu', hint: 'Anlık duyuru ve indirimler için ideal.', icon: Icons.star_rounded),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Vazgeç', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;

                final updated = SingleServiceModel(
                  id: idCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
                  title: titleCtrl.text.trim(),
                  unit: unitCtrl.text.trim(),
                  price: double.tryParse(priceCtrl.text.trim()) ?? 100.0,
                  iconName: existing?.iconName ?? 'star',
                  badge: badgeCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  highlight: highlightCtrl.text.trim(),
                );

                Navigator.pop(dialogCtx);
                try {
                  await MerchantAdService.instance.saveSingleService(updated);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ "${updated.title}" kaydedildi!'), backgroundColor: const Color(0xFF10B981)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  /// Paket Silme Onay Penceresi
  Future<void> _confirmDeletePackage(AdPackageModel pkg) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('"${pkg.name}" Paketini Sil'),
        content: const Text('Bu paketi tamamen silmek istediğinizden emin misiniz? Esnaf web ve uygulamada artık bu paketi göremeyecektir.'),
        actions: [
          CupertinoDialogAction(child: const Text('Vazgeç'), onPressed: () => Navigator.pop(ctx, false)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await MerchantAdService.instance.deletePackage(pkg.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🗑️ "${pkg.name}" paketi silindi.'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // YARDIMCI BİLEŞENLER
  // ─────────────────────────────────────────────────────────
  Widget _buildSwitchItem(String title, bool val, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoSwitch(value: val, activeTrackColor: const Color(0xFF6366F1), onChanged: onChanged),
        const SizedBox(width: 6),
        Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 16, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Future<void> _openWhatsApp(String phone, String businessName, String itemName) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final fullPhone = clean.startsWith('90')
        ? clean
        : clean.startsWith('0')
            ? '9$clean'
            : '90$clean';

    final text = 'Merhaba $businessName yetkilisi,\n'
        'Pazarcık Portal üzerinden iletmiş olduğunuz "$itemName" reklam başvurunuzu aldık. Kampanya detayları ve yayın takvimini planlamak için görüşebiliriz.';
    final url = Uri.parse('https://wa.me/$fullPhone?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makeCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('tel:$clean');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _updateRequestStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('ad_package_requests').doc(docId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteRequest(String docId) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Başvuruyu Sil'),
        content: const Text('Bu reklam talebini kalıcı olarak silmek istediğinizden emin misiniz?'),
        actions: [
          CupertinoDialogAction(child: const Text('Vazgeç'), onPressed: () => Navigator.pop(ctx, false)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sil'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FirebaseFirestore.instance.collection('ad_package_requests').doc(docId).delete();
    }
  }

  Widget _buildRouteChip(String route, String label) {
    return InkWell(
      onTap: () => setState(() => _splashLinkUrlCtrl.text = route),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // SEKME: 4K VİDEO & GÖRSEL AÇILIŞ / KARŞILAMA EKRANI YÖNETİMİ
  // ─────────────────────────────────────────────────────────
  Widget _buildSplashScreenManagerTab() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smart_display_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '4K Video & Görsel Açılış Ekranı (Sponsorluk) 🎬',
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Kullanıcılar uygulamayı veya webi açtığında çıkan 4K video / afiş, butonlar ve yönlendirme bağlantıları.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _previewSplash,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF38BDF8), size: 18),
                label: Text('Canlı Önizle', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const Divider(height: 28),

          // Aktif / Pasif Durum Anahtarı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _splashActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _splashActive ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _splashActive ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                      color: _splashActive ? const Color(0xFF16A34A) : Colors.red,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _splashActive ? 'Açılış Ekranı ŞU AN YAYINDA (Aktif)' : 'Açılış Ekranı KAPALI (Pasif)',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _splashActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                        Text(
                          _splashActive
                              ? 'Kullanıcılar uygulamayı açtığında karşılama ekranını görecekler.'
                              : 'Kullanıcılar doğrudan ana sayfaya yönlendirilir, açılış ekranı gösterilmez.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                CupertinoSwitch(
                  value: _splashActive,
                  activeTrackColor: const Color(0xFF16A34A),
                  onChanged: (val) => setState(() => _splashActive = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Medya Türü Seçimi
          Text(
            'Medya Formatı Seçimi (4K Destekli):',
            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _splashMediaType = 'video'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _splashMediaType == 'video' ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _splashMediaType == 'video' ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                        width: _splashMediaType == 'video' ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_rounded, color: _splashMediaType == 'video' ? const Color(0xFF6366F1) : Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '📹 4K Video Oynatıcı',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _splashMediaType == 'video' ? const Color(0xFF4338CA) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _splashMediaType = 'image'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _splashMediaType == 'image' ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _splashMediaType == 'image' ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                        width: _splashMediaType == 'image' ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_rounded, color: _splashMediaType == 'image' ? const Color(0xFF6366F1) : Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '🖼️ 4K Ultra Net Görsel / Afiş',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _splashMediaType == 'image' ? const Color(0xFF4338CA) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── CİHAZDAN DOĞRUDAN YÜKLEME KUTUSU & URL ALANI ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _splashMediaType == 'video'
                          ? '4K Video Yükleme (Galeriden / Bilgisayardan):'
                          : '4K Görsel Yükleme (Galeriden / Bilgisayardan):',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                    ),
                    if (_splashMediaUrlCtrl.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '✓ Medya Hazır',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Büyük ve Kullanışlı Yükleme Butonu
                InkWell(
                  onTap: _isUploadingMedia ? null : _pickAndUploadMedia,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isUploadingMedia ? const Color(0xFF6366F1) : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_isUploadingMedia) ...[
                          const CupertinoActivityIndicator(radius: 14),
                          const SizedBox(height: 10),
                          Text(
                            _uploadStatusText ?? 'Yükleniyor...',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF4F46E5)),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _uploadProgress,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _splashMediaType == 'video' ? Icons.video_file_rounded : Icons.add_photo_alternate_rounded,
                              size: 28,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _splashMediaType == 'video'
                                ? '📁 Cihazdan / Galeriden Video Seç & Yükle'
                                : '🖼️ Cihazdan / Galeriden Görsel Seç & Yükle',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fotoğraf veya videolarınızdan seçin; Firebase sunucusuna doğrudan yüklenip otomatik ayarlanır.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Alternatif URL Alanı (Link Yapıştırmak İsteyenler İçin)
                Row(
                  children: [
                    Text('Veya Doğrudan Bağlantı (URL) Yapıştırın:', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 4),
                _buildInput(
                  controller: _splashMediaUrlCtrl,
                  label: '',
                  hint: _splashMediaType == 'video' ? 'https://.../video.mp4' : 'https://.../banner.jpg',
                  icon: _splashMediaType == 'video' ? Icons.link_rounded : Icons.image_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Hızlı Demo Doldurma Butonları
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Text('Hızlı Şablonlar:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
              InkWell(
                onTap: () {
                  setState(() {
                    _splashMediaType = 'video';
                    _splashMediaUrlCtrl.text = 'https://assets.mixkit.co/videos/preview/mixkit-serving-dinner-to-a-table-in-a-restaurant-41484-large.mp4';
                    _splashTitleCtrl.text = "Saray Sofrası'nda %20 Açılış İndirimi!";
                    _splashBodyCtrl.text = "Pazarcık'ın en sevilen lezzetleri ve fırın yemekleri portal üzerinden anında kapınızda.";
                    _splashBadgeCtrl.text = "💎 GÜNÜN SPONSORU";
                    _splashButtonTextCtrl.text = "Menüyü İncele & Sipariş Ver ➔";
                    _splashLinkUrlCtrl.text = "/reklam-paketleri";
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                  child: Text('Örnek 4K Restoran Videosu', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _splashMediaType = 'image';
                    _splashMediaUrlCtrl.text = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=1600&auto=format&fit=crop';
                    _splashTitleCtrl.text = "Pazarcık Esnafına Özel Reklam Paketleri";
                    _splashBodyCtrl.text = "İşletmenizi binlerce hemşehrimize tanıtın, satışlarınızı hızla katlayın.";
                    _splashBadgeCtrl.text = "🔥 ÖZEL ESNAF FIRSATI";
                    _splashButtonTextCtrl.text = "Paketleri İncele ➔";
                    _splashLinkUrlCtrl.text = "/esnaf-paketleri";
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6)),
                  child: Text('Örnek 4K Afiş', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const Divider(height: 28),

          // Başlık, Rozet ve Açıklama
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInput(
                  controller: _splashTitleCtrl,
                  label: 'Ana Başlık *',
                  hint: "Örn: Saray Sofrası'nda %20 Açılış İndirimi",
                  icon: Icons.title_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInput(
                  controller: _splashBadgeCtrl,
                  label: 'Üst Rozet Metni',
                  hint: '💎 GÜNÜN SPONSORU',
                  icon: Icons.verified_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInput(
            controller: _splashBodyCtrl,
            label: 'Açıklama / Tanıtım Metni',
            hint: 'İşletme veya duyuru hakkında kısa, etkileyici bir metin yazın...',
            icon: Icons.description_rounded,
          ),
          const Divider(height: 28),

          // Buton ve Yönlendirme Ayarları
          Text(
            'İnsan Eli Tasarımı Eylem Butonu (CTA) ve Yönlendirme:',
            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: _splashButtonTextCtrl,
                  label: 'Buton Üzerindeki Metin *',
                  hint: 'Fırsatı İncele ➔',
                  icon: Icons.smart_button_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildInput(
                  controller: _splashLinkUrlCtrl,
                  label: 'Tıklanınca Açılacak Rota veya Dış Bağlantı *',
                  hint: 'Örn: /esnaf-paketleri veya https://instagram.com/pazarcikportal',
                  icon: Icons.navigation_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Hızlı Rota Seçici Butonları
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Text('Hızlı İç Rotalar:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
              _buildRouteChip('/esnaf-paketleri', 'Esnaf Paketleri'),
              _buildRouteChip('/reklam-paketleri', 'Reklam & Sponsorluk'),
              _buildRouteChip('/firsatlar', 'Fırsatlar'),
              _buildRouteChip('/nobetci-eczane', 'Nöbetçi Eczaneler'),
              _buildRouteChip('/ilanlar', 'İlanlar'),
            ],
          ),
          const Divider(height: 28),

          // Geri Sayım, Sayaç ve Gösterim Sıklığı
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Otomatik Kapanma Sayacı (Saniye):', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _splashAutoCloseSeconds,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5 Saniye (Hızlı)')),
                        DropdownMenuItem(value: 6, child: Text('6 Saniye (İdeal)')),
                        DropdownMenuItem(value: 8, child: Text('8 Saniye (Detaylı)')),
                        DropdownMenuItem(value: 10, child: Text('10 Saniye')),
                        DropdownMenuItem(value: 0, child: Text('0 - Otomatik Kapanmasın (Manuel Atla)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _splashAutoCloseSeconds = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gösterim Sıklığı Politikası:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _splashFrequency,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'always', child: Text('Her Açılışta Göster (Sponsorluk Modu)')),
                        DropdownMenuItem(value: 'once_daily', child: Text('Günde 1 Kez Göster (Dengeli)')),
                        DropdownMenuItem(value: 'once_per_update', child: Text('Sadece Yeni Güncellemelerde Göster')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _splashFrequency = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSwitchItem('Kullanıcı Dilediğinde Atlayabilsin ("Atla / Kapat" Butonu Aktif)', _splashAllowSkip, (val) => setState(() => _splashAllowSkip = val)),
          const Divider(height: 32),

          // Aksiyon Butonları (Önizle & Kaydet)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _previewSplash,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF818CF8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
                label: Text('Canlıda Nasıl Görünüyor? (Önizle)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSavingSplash ? null : _saveSplashData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: _isSavingSplash
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Icon(CupertinoIcons.checkmark_alt, size: 18),
                label: Text(
                  _isSavingSplash ? 'Kaydediliyor...' : 'Açılış Ekranını Canlıya Al',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
