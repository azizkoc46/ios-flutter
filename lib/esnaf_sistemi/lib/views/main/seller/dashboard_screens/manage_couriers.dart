// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/services/courier_service.dart';

const Color _trendyolOrange = Color(0xFFF27A1A);
const Color _iosBg = Color(0xFFF2F2F7);

class ManageCouriersScreen extends StatefulWidget {
  const ManageCouriersScreen({Key? key}) : super(key: key);

  @override
  State<ManageCouriersScreen> createState() => _ManageCouriersScreenState();
}

class _ManageCouriersScreenState extends State<ManageCouriersScreen> {
  final String _sellerId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _storeName = 'Restoranım';
  final CourierService _courierService = CourierService();

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    if (_sellerId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('sellers').doc(_sellerId).get();
      if (doc.exists && mounted) {
        setState(() {
          _storeName = (doc.data()?['storeName'] ?? doc.data()?['restaurantName'] ?? 'Restoranım').toString();
        });
      }
    } catch (_) {}
  }

  void _showAddCourierModal() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedVehicle = 'Motosiklet';
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 16,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _trendyolOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(CupertinoIcons.person_badge_plus_fill,
                            color: _trendyolOrange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Yeni Kurye Ekle",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            "Kuryeniz sisteme sadece kendi telefonuyla erişir",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // İsim Soyisim
                  Text("Kurye Adı & Soyadı",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: "Örn: Ahmet Yılmaz",
                      prefixIcon: const Icon(CupertinoIcons.person, size: 18),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Telefon
                  Text("Telefon Numarası (Sisteme Giriş Yapacağı Numara)",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: "Örn: 0555 123 45 67",
                      prefixIcon: const Icon(CupertinoIcons.phone, size: 18),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Araç Türü
                  Text("Teslimat Aracı",
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _vehicleChip('🛵 Motosiklet', 'Motosiklet', selectedVehicle, (v) {
                        setModalState(() => selectedVehicle = v);
                      }),
                      _vehicleChip('🚗 Araba', 'Araba', selectedVehicle, (v) {
                        setModalState(() => selectedVehicle = v);
                      }),
                      _vehicleChip('🚲 Bisiklet', 'Bisiklet', selectedVehicle, (v) {
                        setModalState(() => selectedVehicle = v);
                      }),
                      _vehicleChip('🚶 Yaya', 'Yaya', selectedVehicle, (v) {
                        setModalState(() => selectedVehicle = v);
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Kaydet Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _trendyolOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();
                              if (name.isEmpty || phone.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Lütfen tüm alanları doldurun."),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              setModalState(() => isLoading = true);
                              try {
                                await _courierService.addCourier(
                                  sellerId: _sellerId,
                                  storeName: _storeName,
                                  name: name,
                                  phone: phone,
                                  vehicleType: selectedVehicle,
                                );
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("✅ Kurye başarıyla eklendi: $name"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Hata: $e"),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                      child: isLoading
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                              "Kuryeyi Kaydet & Yetkilendir",
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _vehicleChip(String label, String value, String current, Function(String) onSelect) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: _trendyolOrange.withOpacity(0.18),
      labelStyle: TextStyle(
        color: isSelected ? _trendyolOrange : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onSelect(value),
    );
  }

  Future<void> _callCourier(String rawPhone) async {
    final clean = CourierService.normalizePhone(rawPhone);
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : _iosBg,
      appBar: AppBar(
        title: Text(
          "Kurye Yönetimi",
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        elevation: 0.5,
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: _trendyolOrange),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.plus_circle_fill, color: _trendyolOrange, size: 26),
            tooltip: "Yeni Kurye Ekle",
            onPressed: _showAddCourierModal,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('couriers')
            .where('sellerId', isEqualTo: _sellerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CupertinoActivityIndicator(radius: 14));
          }

          final docs = snapshot.data?.docs ?? [];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    children: [
                      // Bilgilendirme Bannerı
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0284C7).withOpacity(0.08),
                              const Color(0xFF0369A1).withOpacity(0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF0284C7).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0284C7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.info, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Kurye Sistemi Nasıl İşler?",
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: const Color(0xFF0369A1),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Eklediğiniz telefon numarasına sahip kuryeler kendi uygulamalarına giriş yaptıklarında SADECE sizin restoranınızın siparişlerini görür. Siparişi alıp yola çıktıklarında zorunlu GPS konumu başlar ve teslimatta gizlilik için konum yayını tamamen kesilir.",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // İstatistik Kartı
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: "Toplam Kurye",
                              count: docs.length.toString(),
                              icon: CupertinoIcons.person_2_fill,
                              color: const Color(0xFF6366F1),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: "Aktif Kuryeler",
                              count: docs
                                  .where((d) => (d.data() as Map<String, dynamic>)['isActive'] == true)
                                  .length
                                  .toString(),
                              icon: CupertinoIcons.checkmark_shield_fill,
                              color: const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Kayıtlı Kuryelerim (${docs.length})",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showAddCourierModal,
                            icon: const Icon(CupertinoIcons.add, size: 16, color: _trendyolOrange),
                            label: const Text("Kurye Ekle",
                                style: TextStyle(
                                    color: _trendyolOrange, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (docs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _trendyolOrange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.person_badge_plus,
                                size: 48, color: _trendyolOrange),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Henüz Bir Kurye Eklenmemiş",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Kendi siparişlerinizi teslim edecek kuryelerinizi buradan ekleyebilirsiniz.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _trendyolOrange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: _showAddCourierModal,
                            icon: const Icon(CupertinoIcons.plus, color: Colors.white, size: 18),
                            label: const Text("İlk Kuryeni Ekle",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] ?? 'İsimsiz Kurye';
                        final phone = data['phone'] ?? '';
                        final vehicle = data['vehicleType'] ?? 'Motosiklet';
                        final bool isActive = data['isActive'] == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131B2E) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
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
                            children: [
                              // Avatar / Araç ikonu
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isActive
                                        ? [_trendyolOrange, const Color(0xFFFF9500)]
                                        : [Colors.grey.shade500, Colors.grey.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Center(
                                  child: Text(
                                    vehicle.contains('Araba')
                                        ? '🚗'
                                        : vehicle.contains('Bisiklet')
                                            ? '🚲'
                                            : vehicle.contains('Yaya')
                                                ? '🚶'
                                                : '🛵',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // İsim, Telefon ve Araç Bilgisi
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? Colors.green.withOpacity(0.15)
                                                : Colors.grey.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isActive ? "Aktif" : "Pasif",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isActive ? Colors.green.shade700 : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "$vehicle  •  $phone",
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Arama Butonu
                              IconButton(
                                icon: const Icon(CupertinoIcons.phone_fill,
                                    color: Colors.green, size: 20),
                                tooltip: "Kuryeyi Ara",
                                onPressed: () => _callCourier(phone),
                              ),

                              // Menü (Aktif Yap / Sil)
                              PopupMenuButton<String>(
                                icon: Icon(CupertinoIcons.ellipsis_vertical,
                                    size: 18, color: Colors.grey.shade500),
                                onSelected: (val) async {
                                  if (val == 'toggle') {
                                    await _courierService.toggleCourierActive(doc.id, isActive);
                                  } else if (val == 'delete') {
                                    final confirm = await showCupertinoDialog<bool>(
                                      context: context,
                                      builder: (c) => CupertinoAlertDialog(
                                        title: const Text("Kuryeyi Sil"),
                                        content: Text("$name adlı kuryeyi silmek istediğinize emin misiniz? Artık siparişlerinizi göremez."),
                                        actions: [
                                          CupertinoDialogAction(
                                            child: const Text("Vazgeç"),
                                            onPressed: () => Navigator.pop(c, false),
                                          ),
                                          CupertinoDialogAction(
                                            isDestructiveAction: true,
                                            child: const Text("Sil"),
                                            onPressed: () => Navigator.pop(c, true),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _courierService.deleteCourier(doc.id);
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isActive ? CupertinoIcons.pause_circle : CupertinoIcons.play_circle,
                                          size: 18,
                                          color: isActive ? Colors.orange : Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(isActive ? "Pasife Al" : "Aktife Al"),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(CupertinoIcons.trash, size: 18, color: Colors.redAccent),
                                        const SizedBox(width: 8),
                                        Text("Kuryeyi Sil", style: TextStyle(color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: docs.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
