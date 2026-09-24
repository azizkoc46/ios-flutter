// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class MuhtarliklarPage extends StatefulWidget {
  const MuhtarliklarPage({Key? key}) : super(key: key);

  @override
  State<MuhtarliklarPage> createState() => _MuhtarliklarPageState();
}

class _MuhtarliklarPageState extends State<MuhtarliklarPage> {
  String _searchQuery = "";

  Future<void> _makeCall(String rawPhone) async {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String rawPhone, String mahalle) async {
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '9$cleanPhone';
    } else if (!cleanPhone.startsWith('90')) {
      cleanPhone = '90$cleanPhone';
    }

    final message = Uri.encodeComponent(
      "Merhaba Sayın $mahalle Muhtarım, Pazarcık Portal üzerinden ulaşıyorum.",
    );
    final url = "https://wa.me/$cleanPhone?text=$message";
    final uri = Uri.parse(url);

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "Pazarcık Muhtarlıkları",
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // 🔎 Arama Çubuğu & Bilgilendirme
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                CupertinoSearchTextField(
                  placeholder: "Mahalle veya muhtar adı ara...",
                  style: const TextStyle(fontSize: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  borderRadius: BorderRadius.circular(12),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.privacy_tip_outlined, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Muhtarlarımızın güvenliği için numaralar açıkça yazılmaz. Doğrudan arama veya WhatsApp butonunu kullanabilirsiniz.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 📋 Muhtar Listesi
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('muhtarliklar')
                  .orderBy('neighborhood')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Muhtarlıklar yüklenirken hata oluştu.",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final docs = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final neighborhood = (data['neighborhood'] ?? '').toString().toLowerCase();
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  if (_searchQuery.isEmpty) return true;
                  return neighborhood.contains(_searchQuery) || name.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.person_2_square_stack, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 14),
                          Text(
                            _searchQuery.isNotEmpty
                                ? "Aradığınız kriterde muhtarlık bulunamadı."
                                : "Henüz muhtarlık kaydı eklenmemiş.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final neighborhood = data['neighborhood'] ?? 'Mahalle';
                    final name = data['name'] ?? 'Muhtar';
                    final phone = (data['phone'] ?? '').toString();
                    final hasWhatsapp = data['hasWhatsapp'] ?? true;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.account_balance,
                                  color: Color(0xFF7C3AED),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      neighborhood,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "Muhtar: $name",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: const [
                                        Icon(Icons.shield_outlined, size: 12, color: Color(0xFF16A34A)),
                                        SizedBox(width: 4),
                                        Text(
                                          "Numara Gizli • Doğrudan Bağlantı",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // 📞 Ara Butonu
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0056D2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: phone.isNotEmpty ? () => _makeCall(phone) : null,
                                  icon: const Icon(Icons.phone, size: 18),
                                  label: const Text(
                                    "Muhtarı Ara",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                              if (hasWhatsapp && phone.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                // 💬 WhatsApp Butonu
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _openWhatsApp(phone, neighborhood),
                                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                    label: const Text(
                                      "WhatsApp",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
