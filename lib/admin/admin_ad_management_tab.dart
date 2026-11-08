import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../business/merchant_ad_service.dart';

/// Yönetim Merkezi - Esnaf Reklam & Tanıtım Paketleri ve Başvuru Takip Sekmesi
class AdminAdManagementTab extends StatefulWidget {
  const AdminAdManagementTab({Key? key}) : super(key: key);

  @override
  State<AdminAdManagementTab> createState() => _AdminAdManagementTabState();
}

class _AdminAdManagementTabState extends State<AdminAdManagementTab> {
  final _whatsappCtrl = TextEditingController();
  final _supportCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _vatCtrl = TextEditingController(text: '18');

  final _starterPriceCtrl = TextEditingController(text: '1950');
  final _growthPriceCtrl = TextEditingController(text: '2950');
  final _premiumPriceCtrl = TextEditingController(text: '4950');

  bool _isSavingSettings = false;
  bool _initialized = false;
  String _selectedStatusFilter = 'all';

  @override
  void dispose() {
    _whatsappCtrl.dispose();
    _supportCtrl.dispose();
    _instagramCtrl.dispose();
    _vatCtrl.dispose();
    _starterPriceCtrl.dispose();
    _growthPriceCtrl.dispose();
    _premiumPriceCtrl.dispose();
    super.dispose();
  }

  void _populateFromConfig(AdConfigModel config) {
    if (_initialized) return;
    _whatsappCtrl.text = config.whatsappPhone;
    _supportCtrl.text = config.supportPhone;
    _instagramCtrl.text = config.instagramUsername;
    _vatCtrl.text = config.vatRate.toString();

    for (final pkg in config.packages) {
      if (pkg.id == 'starter') {
        _starterPriceCtrl.text = pkg.baseMonthlyPrice.toInt().toString();
      } else if (pkg.id == 'growth') {
        _growthPriceCtrl.text = pkg.baseMonthlyPrice.toInt().toString();
      } else if (pkg.id == 'premium') {
        _premiumPriceCtrl.text = pkg.baseMonthlyPrice.toInt().toString();
      }
    }
    _initialized = true;
  }

  Future<void> _saveSettings() async {
    setState(() => _isSavingSettings = true);
    try {
      final sPrice = double.tryParse(_starterPriceCtrl.text.trim()) ?? 1950;
      final gPrice = double.tryParse(_growthPriceCtrl.text.trim()) ?? 2950;
      final pPrice = double.tryParse(_premiumPriceCtrl.text.trim()) ?? 4950;
      final vat = int.tryParse(_vatCtrl.text.trim()) ?? 18;

      await MerchantAdService.instance.updateAdSettings(
        whatsappPhone: _whatsappCtrl.text.trim(),
        supportPhone: _supportCtrl.text.trim(),
        instagramUsername: _instagramCtrl.text.trim(),
        vatRate: vat,
        packagePrices: {
          'starter': sPrice,
          'growth': gPrice,
          'premium': pPrice,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reklam ve WhatsApp iletişim ayarları başarıyla güncellendi!'),
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
          CupertinoDialogAction(
            child: const Text('Vazgeç'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdConfigModel>(
      stream: MerchantAdService.instance.streamConfig(),
      builder: (context, configSnap) {
        if (configSnap.hasData) {
          _populateFromConfig(configSnap.data!);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingsCard(),
                const SizedBox(height: 24),
                _buildRequestsHeader(),
                const SizedBox(height: 12),
                _buildRequestsList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.phone_badge_plus, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reklam İletişim & WhatsApp Ayarları',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
                    ),
                    Text(
                      'Sitede esnafa gösterilen WhatsApp numarası ve reklam fiyatları burada düzenlenir.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: _whatsappCtrl,
                  label: 'WhatsApp Destek Numarası *',
                  hint: 'Örn: 05xx xxx xx xx',
                  icon: CupertinoIcons.chat_bubble_fill,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInput(
                  controller: _supportCtrl,
                  label: 'Sabit / Arama Telefonu',
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
                  label: 'Instagram Hesabı',
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
          const SizedBox(height: 16),
          Text(
            'Aylık Liste Fiyatları (TL - KDV Hariç):',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildInput(
                  controller: _starterPriceCtrl,
                  label: 'Başlangıç (TL)',
                  hint: '1950',
                  icon: CupertinoIcons.tag_fill,
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInput(
                  controller: _growthPriceCtrl,
                  label: 'Büyüme/Orta (TL)',
                  hint: '2950',
                  icon: CupertinoIcons.flame_fill,
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInput(
                  controller: _premiumPriceCtrl,
                  label: 'VIP Prestij (TL)',
                  hint: '4950',
                  icon: CupertinoIcons.star_fill,
                  keyboard: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isSavingSettings ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: _isSavingSettings
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(CupertinoIcons.checkmark_alt, size: 16),
              label: Text(
                _isSavingSettings ? 'Kaydediliyor...' : 'Numara ve Ayarları Güncelle',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
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
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF4B5563))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 16, color: const Color(0xFF6B7280)),
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gelen Esnaf Reklam Talepleri 📢',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF111827)),
            ),
            Text(
              'Web ve uygulamadan başvuran işletmeler anlık olarak burada listelenir.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
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
            DropdownMenuItem(value: 'approved', child: Text('Onaylandı')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedStatusFilter = val);
          },
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    Query query = FirebaseFirestore.instance.collection('ad_package_requests').orderBy('createdAt', descending: true);
    if (_selectedStatusFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedStatusFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CupertinoActivityIndicator()));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  'Web sitesi veya uygulamadan yapılan başvurular doğrudan buraya düşecektir.',
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
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF111827)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Yetkili: $contactName • $phone',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4B5563)),
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
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '📜 Sözleşme Onaylı',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
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
              style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFF6B7280)),
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
}
