import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'merchant_ad_service.dart';

/// Pazarcık Portal Esnaf Reklam & Tanıtım Paketleri Sayfası
class MerchantAdPackagesPage extends StatefulWidget {
  const MerchantAdPackagesPage({super.key});

  @override
  State<MerchantAdPackagesPage> createState() => _MerchantAdPackagesPageState();
}

class _MerchantAdPackagesPageState extends State<MerchantAdPackagesPage> {
  AdPeriod _selectedPeriod = AdPeriod.oneMonth;
  final MerchantAdService _service = MerchantAdService.instance;

  @override
  void initState() {
    super.initState();
    // İlk açılışta Firestore'da ayar yoksa varsayılanları sessizce hazırla
    _service.initializeDefaultConfigInFirestore();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_left,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Esnaf Reklam Paketleri',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Hızlı WhatsApp Destek',
            icon: const Icon(CupertinoIcons.chat_bubble_2_fill, color: Color(0xFF25D366)),
            onPressed: () => _openGeneralWhatsApp(),
          ),
        ],
      ),
      body: StreamBuilder<AdConfigModel>(
        stream: _service.streamConfig(),
        builder: (context, snapshot) {
          final config = snapshot.data ?? _service.streamConfig().first as dynamic;
          // Eğer akış henüz ilk veriyi üretmediyse güvenle varsayılanı kullan
          final safeConfig = config is AdConfigModel
              ? config
              : const AdConfigModel(
                  whatsappPhone: '0546 466 4646',
                  supportPhone: '0546 466 4646',
                  instagramUsername: 'pazarcikportal',
                  periodDiscounts: {1: 0, 3: 15, 6: 25, 12: 35},
                  packages: MerchantAdService.defaultPackages,
                  singleServices: MerchantAdService.defaultSingleServices,
                  policyTitle: 'Adil, Şeffaf ve İnsanları Sıkmayan Reklam Politikamız',
                  policyText: 'Pazarcık Portal olarak esnafımızın büyümesini desteklerken, hemşehrilerimizin kullanıcı deneyimini en üst seviyede tutuyoruz.',
                );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final horizontalPadding = isWide ? (constraints.maxWidth - 900) / 2 + 24 : 16.0;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. HERO BAŞLIK & TANITIM KARTI
                    _buildHeroBanner(isDark),
                    const SizedBox(height: 20),

                    // 2. ADİL & ŞEFFAF REKLAM POLİTİKASI GÜVENCESİ
                    _buildPolicyCard(safeConfig, isDark),
                    const SizedBox(height: 24),

                    // 3. DÖNEM SEÇİCİ (1 Ay / 3 Ay / 6 Ay / 1 Yıl)
                    _buildPeriodSelector(safeConfig, isDark),
                    const SizedBox(height: 24),

                    // 4. DÖNEMSEL PAKETLER LİSTESİ (Responsive Grid / Column)
                    _buildSectionHeader(
                      title: 'Dönemsel Esnaf Paketleri',
                      subtitle: 'İşletmenizin ölçeğine ve hedefinize uygun ana tanıtım paketini seçin.',
                      icon: CupertinoIcons.sparkles,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildPackagesSection(safeConfig, isWide, isDark),
                    const SizedBox(height: 36),

                    // 5. TEKİL / MODÜLER REKLAM HİZMETLERİ
                    _buildSectionHeader(
                      title: 'Tekil & Modüler Reklam Hizmetleri',
                      subtitle: 'İhtiyacınıza göre tek tek seçin veya mevcut paketinize ekletin.',
                      icon: CupertinoIcons.cube_box_fill,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 14),
                    _buildSingleServicesSection(safeConfig, isWide, isDark),
                    const SizedBox(height: 36),

                    // 6. SIKÇA SORULAN SORULAR
                    _buildFaqSection(isDark),
                    const SizedBox(height: 24),

                    // 7. ALT İLETİŞİM & WHATSAPP ÇAĞRI KARTI
                    _buildBottomContactCard(safeConfig, isDark),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── 1. Hero Başlık Kartı ──
  Widget _buildHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      'PAZARCIK PORTAL RESMİ ESNAF AĞI',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'İşletmenizi Tüm Pazarcık’a Duyurun, Satışlarınızı Büyütün! 🚀',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'İlçemizin en çok kullanılan yerel mobil uygulaması ve resmi Instagram sayfamızda işletmeniz her gün binlerce aktif hemşehrimizin gözünün önünde olsun.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroStatChip(CupertinoIcons.device_phone_portrait, '15.000+ Aktif İndirme'),
              _buildHeroStatChip(CupertinoIcons.bell_fill, 'Anında Cebine Bildirim'),
              _buildHeroStatChip(CupertinoIcons.camera_fill, 'Instagram & Web Vitrini'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Adil Reklam Politikası Kartı ──
  Widget _buildPolicyCard(AdConfigModel config, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(isDark ? 0.25 : 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.shield_lefthalf_fill, color: Color(0xFF10B981), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.policyTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  config.policyText,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Dönem Seçici (Tabs) ──
  Widget _buildPeriodSelector(AdConfigModel config, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: AdPeriod.values.map((period) {
          final isSelected = _selectedPeriod == period;
          final badge = period.badge;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0284C7)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      period.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 4. Dönemsel Paketler Bölümü ──
  Widget _buildPackagesSection(AdConfigModel config, bool isWide, bool isDark) {
    final discount = config.getDiscount(_selectedPeriod);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: config.packages.map((pkg) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildPackageCard(pkg, discount, isDark),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: config.packages.map((pkg) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildPackageCard(pkg, discount, isDark),
        );
      }).toList(),
    );
  }

  Widget _buildPackageCard(AdPackageModel pkg, int discount, bool isDark) {
    final monthlyPrice = pkg.getMonthlyPrice(discount);
    final totalPrice = pkg.getTotalPrice(_selectedPeriod, discount);
    final isPopular = pkg.isPopular;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPopular
              ? const Color(0xFF0284C7)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPopular
                ? const Color(0xFF0284C7).withOpacity(0.18)
                : Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: isPopular ? 16 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ÜST ŞERİT & ROZET
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Center(
                child: Text(
                  pkg.badge,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isPopular)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pkg.badge,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                Text(
                  pkg.name,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pkg.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // FİYAT ALANI
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${monthlyPrice.toInt()} ₺',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ ay',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                if (_selectedPeriod != AdPeriod.oneMonth) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedPeriod.label} Toplam: ${totalPrice.toInt()} ₺ (%$discount indirimle)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Divider(height: 1, thickness: 0.8),
                const SizedBox(height: 16),

                // ÖZELLİKLER LİSTESİ
                Text(
                  'PAKET İÇERİĞİ:',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                ...pkg.perks.map((perk) => _buildPerkItem(perk, isDark)),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.info_circle_fill, size: 14, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Öneri: ${pkg.recommendedFor}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // AKSİYON BUTONLARI
                ElevatedButton.icon(
                  onPressed: () => _openRequestModal(
                    requestType: 'package',
                    itemName: pkg.name,
                    periodLabel: _selectedPeriod.label,
                    totalPrice: totalPrice,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(CupertinoIcons.checkmark_circle_fill, size: 16),
                  label: Text(
                    'Paketi Seç & Başvur',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openPackageWhatsApp(pkg, totalPrice),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(CupertinoIcons.chat_bubble_2_fill, size: 15),
                  label: Text(
                    'WhatsApp’tan Bilgi Al',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerkItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 10, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Tekil / Modüler Reklam Hizmetleri Bölümü ──
  Widget _buildSingleServicesSection(AdConfigModel config, bool isWide, bool isDark) {
    if (isWide) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: config.singleServices.map((svc) {
          return SizedBox(
            width: 420,
            child: _buildSingleServiceCard(svc, isDark),
          );
        }).toList(),
      );
    }

    return Column(
      children: config.singleServices.map((svc) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildSingleServiceCard(svc, isDark),
        );
      }).toList(),
    );
  }

  Widget _buildSingleServiceCard(SingleServiceModel svc, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIconForService(svc.iconName), color: const Color(0xFF0284C7), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            svc.title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        svc.badge,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${svc.price.toInt()} ₺',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  Text(
                    svc.unit,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            svc.description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '💡 ${svc.highlight}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openRequestModal(
                    requestType: 'single',
                    itemName: svc.title,
                    periodLabel: svc.unit,
                    totalPrice: svc.price,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    'Talep Oluştur',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openSingleServiceWhatsApp(svc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(CupertinoIcons.chat_bubble_fill, size: 13),
                label: Text(
                  'WhatsApp',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForService(String name) {
    switch (name) {
      case 'instagram':
        return CupertinoIcons.camera_fill;
      case 'photo_camera':
        return CupertinoIcons.photo_fill_on_rectangle_fill;
      case 'smartphone':
        return CupertinoIcons.device_phone_portrait;
      case 'push_pin':
        return CupertinoIcons.pin_fill;
      case 'notifications_active':
        return CupertinoIcons.bell_fill;
      case 'star':
        return CupertinoIcons.star_fill;
      default:
        return CupertinoIcons.cube_box_fill;
    }
  }

  // ── 6. SSS Bölümü ──
  Widget _buildFaqSection(bool isDark) {
    final faqs = [
      {
        'q': 'Reklamım veya hikayem ne zaman yayına girer?',
        'a': 'Başvurunuz ve içerikleriniz onaylandıktan sonra dilediğiniz gün ve saat planlaması yapılarak 24 saat içerisinde yayına alınır.'
      },
      {
        'q': 'Görselleri ve videoları ben mi hazırlayacağım?',
        'a': 'Elinizdeki mevcut fotoğraf, video veya afişleri kullanabiliriz. Ayrıca ekibimiz profesyonel metin ve görsel boyutlandırma desteği sağlamaktadır.'
      },
      {
        'q': 'Toplu bildirimler ne zaman ve nasıl gönderilir?',
        'a': 'Bildirimler kullanıcıları sıkmayacak şekilde, ilçede en yüksek aktiflik saatlerinde (genellikle 12:00-14:00 veya 18:00-20:30) indirim ve fırsat bülteni formatında gönderilir.'
      },
      {
        'q': 'Fatura ve ödeme nasıl gerçekleşiyor?',
        'a': 'Havale/EFT ve resmi faturalandırma ile çalışmaktayız. Dilerseniz Pazarcık merkez ofisimizde yüz yüze görüşme de sağlayabiliriz.'
      },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.question_circle_fill, color: Color(0xFF0284C7), size: 20),
              const SizedBox(width: 8),
              Text(
                'Sıkça Sorulan Sorular',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...faqs.map((faq) {
            return ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: Text(
                faq['q']!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              children: [
                Text(
                  faq['a']!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── 7. Alt WhatsApp İletişim Kartı ──
  Widget _buildBottomContactCard(AdConfigModel config, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
              : [const Color(0xFF10B981), const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          Text(
            'Özel Bir Projeniz veya Sorunuz mu Var?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İşletmenize özel tanıtım stratejisi belirlemek ve yerel kitleye en doğru şekilde ulaşmak için reklam danışmanımızla doğrudan WhatsApp üzerinden görüşebilirsiniz.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: Colors.white.withOpacity(0.9),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _openGeneralWhatsApp(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF065F46),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(CupertinoIcons.phone_fill, size: 16),
            label: Text(
              'WhatsApp ile Hemen Görüşün (${config.whatsappPhone})',
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF0284C7), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Başvuru Modalı ──
  void _openRequestModal({
    required String requestType,
    required String itemName,
    required String periodLabel,
    required double totalPrice,
  }) {
    final businessCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Oturum açıksa kullanıcı bilgilerini doldur
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
      contactCtrl.text = currentUser.displayName!;
    }
    if (currentUser?.phoneNumber != null && currentUser!.phoneNumber!.isNotEmpty) {
      phoneCtrl.text = currentUser.phoneNumber!;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Reklam Talebi Oluştur 📝',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Seçilen: $itemName ($periodLabel) • ${totalPrice.toInt()} ₺',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(businessCtrl, 'İşletme Adınız *', 'Örn: Şahinler Butik', isDark),
                      const SizedBox(height: 12),
                      _buildTextField(contactCtrl, 'Yetkili Adı Soyadı *', 'Örn: Ahmet Yılmaz', isDark),
                      const SizedBox(height: 12),
                      _buildTextField(phoneCtrl, 'İletişim Telefonu *', 'Örn: 05xx xxx xx xx', isDark, keyboard: TextInputType.phone),
                      const SizedBox(height: 12),
                      _buildTextField(noteCtrl, 'Ek Not veya İstekleriniz', 'Kampanya detayı, indirim oranı vb.', isDark, maxLines: 2),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final bName = businessCtrl.text.trim();
                                final cName = contactCtrl.text.trim();
                                final pNumber = phoneCtrl.text.trim();

                                if (bName.isEmpty || cName.isEmpty || pNumber.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Lütfen işletme adı, yetkili adı ve telefon numarasını doldurun.'),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                try {
                                  await _service.submitAdRequest(
                                    businessName: bName,
                                    contactName: cName,
                                    phone: pNumber,
                                    requestType: requestType,
                                    itemName: itemName,
                                    periodLabel: periodLabel,
                                    totalPrice: totalPrice,
                                    note: noteCtrl.text.trim(),
                                  );

                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    _showSuccessDialog(bName, itemName, periodLabel, totalPrice);
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : Text(
                                'Talebi İlet & Başvuruyu Tamamla',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    bool isDark, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey.shade400),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        ),
      ),
    );
  }

  void _showSuccessDialog(String bName, String itemName, String periodLabel, double totalPrice) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('Talebiniz Alındı! 🎉'),
          content: Text(
            '$bName işletmeniz için "$itemName ($periodLabel)" başvurusu başarıyla iletildi.\n\nEkibimiz en kısa sürede sizinle iletişime geçecektir. Dilerseniz hemen WhatsApp üzerinden detayları görüşebilirsiniz.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Kapat'),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('WhatsApp’tan Yaz'),
              onPressed: () {
                Navigator.pop(ctx);
                _service.openWhatsApp(
                  context: context,
                  whatsappNumber: '0546 466 4646',
                  message: 'Merhaba Pazarcık Portal, $bName işletmem için $itemName ($periodLabel - ${totalPrice.toInt()} ₺) reklam başvurusu yaptım. Detayları görüşmek istiyorum.',
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ── WhatsApp Yönlendirmeleri ──
  void _openGeneralWhatsApp() {
    _service.openWhatsApp(
      context: context,
      whatsappNumber: '0546 466 4646',
      message: 'Merhaba Pazarcık Portal, işletmem için esnaf reklam ve tanıtım paketleri hakkında bilgi almak istiyorum.',
    );
  }

  void _openPackageWhatsApp(AdPackageModel pkg, double totalPrice) {
    _service.openWhatsApp(
      context: context,
      whatsappNumber: '0546 466 4646',
      message: 'Merhaba Pazarcık Portal, "${pkg.name}" (${_selectedPeriod.label} - ${totalPrice.toInt()} ₺) reklam paketiyle ilgileniyorum. İşletmemi tanıtmak istiyorum, bilgi alabilir miyim?',
    );
  }

  void _openSingleServiceWhatsApp(SingleServiceModel svc) {
    _service.openWhatsApp(
      context: context,
      whatsappNumber: '0546 466 4646',
      message: 'Merhaba Pazarcık Portal, "${svc.title}" (${svc.unit} - ${svc.price.toInt()} ₺) tekil reklam hizmeti almak istiyorum. Detayları görüşebilir miyiz?',
    );
  }
}
