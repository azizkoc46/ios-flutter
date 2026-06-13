// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Aktivite / Olay Akışı Sekmesi
///
/// Tüm koleksiyonlardan gerçek zamanlı olayları gösterir.
/// Firebase'de ayrı bir admin_activity_log koleksiyonu kullanır.
///
/// Olaylar otomatik yazılır — diğer admin dosyalarına şu çağrıyı ekleyin:
///   ActivityLogger.log(type: 'user_blocked', title: '...', body: '...');
class AdminActivityFeedTab extends StatefulWidget {
  const AdminActivityFeedTab({Key? key}) : super(key: key);

  @override
  State<AdminActivityFeedTab> createState() => _AdminActivityFeedTabState();
}

class _AdminActivityFeedTabState extends State<AdminActivityFeedTab> {
  String _typeFilter = 'all';

  final Map<String, _EventType> _eventTypes = {
    'all': _EventType('Tümü', CupertinoIcons.list_bullet, Colors.blueGrey),
    'user': _EventType('Kullanıcı', CupertinoIcons.person_fill, Colors.blue),
    'order': _EventType('Sipariş', CupertinoIcons.bag_fill, Colors.teal),
    'complaint': _EventType(
        'Şikayet', CupertinoIcons.exclamationmark_bubble_fill, Colors.red),
    'announcement':
        _EventType('Duyuru', CupertinoIcons.speaker_2_fill, Colors.purple),
    'phone': _EventType('Tel. Onay', CupertinoIcons.phone_fill, Colors.green),
    'business':
        _EventType('İşletme', CupertinoIcons.building_2_fill, Colors.orange),
    'ad': _EventType('İlan', CupertinoIcons.tag_fill, Colors.indigo),
  };

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('admin_activity_log')
        .orderBy('createdAt', descending: true)
        .limit(150);

    if (_typeFilter != 'all') {
      query = FirebaseFirestore.instance
          .collection('admin_activity_log')
          .where('type', isEqualTo: _typeFilter)
          .orderBy('createdAt', descending: true)
          .limit(150);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Canlı durum çubuğu ───────────────────────────────────────────
          _LiveBar(),
          // ── Filtreler ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _eventTypes.entries.map((e) {
                  final selected = _typeFilter == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _typeFilter = e.key),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: selected ? e.value.color : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border:
                            Border.all(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(e.value.icon,
                              size: 13,
                              color: selected ? Colors.white : e.value.color),
                          const SizedBox(width: 5),
                          Text(e.value.label,
                              style: TextStyle(
                                  color:
                                      selected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // ── Temizle butonu ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(children: [
              const Spacer(),
              TextButton.icon(
                onPressed: _clearOldLogs,
                icon: const Icon(CupertinoIcons.trash, size: 14),
                label: const Text('30 günden eski temizle',
                    style: TextStyle(fontSize: 12)),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.red.shade400),
              ),
            ]),
          ),
          // ── Feed listesi ─────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.clock,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('Henüz aktivite yok.',
                            style: TextStyle(color: Colors.black45)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _ActivityTile(data: data, index: index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearOldLogs() async {
    final threshold = DateTime.now().subtract(const Duration(days: 30));
    final snapshot = await FirebaseFirestore.instance
        .collection('admin_activity_log')
        .where('createdAt', isLessThan: Timestamp.fromDate(threshold))
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Eski aktiviteler temizlendi.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Canlı durum çubuğu — bekleyen toplam işlem sayısı
// ─────────────────────────────────────────────────────────────────────────────
class _LiveBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('phone_verification_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, phoneSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('corporate_seller_applications')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, corpSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, compSnap) {
                final phonePending = phoneSnap.data?.docs.length ?? 0;
                final corpPending = corpSnap.data?.docs.length ?? 0;
                final compPending = compSnap.data?.docs.length ?? 0;
                final total = phonePending + corpPending + compPending;

                if (total == 0) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$total bekleyen işlem var: '
                        '${phonePending > 0 ? '$phonePending tel. onayı  ' : ''}'
                        '${corpPending > 0 ? '$corpPending başvuru  ' : ''}'
                        '${compPending > 0 ? '$compPending şikayet' : ''}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                      ),
                    ),
                  ]),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Aktivite satırı
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;

  const _ActivityTile({required this.data, required this.index});

  static const Map<String, IconData> _icons = {
    'user': CupertinoIcons.person_fill,
    'order': CupertinoIcons.bag_fill,
    'complaint': CupertinoIcons.exclamationmark_bubble_fill,
    'announcement': CupertinoIcons.speaker_2_fill,
    'phone': CupertinoIcons.phone_fill,
    'business': CupertinoIcons.building_2_fill,
    'ad': CupertinoIcons.tag_fill,
    'story': CupertinoIcons.play_circle_fill,
    'moderation': CupertinoIcons.shield_fill,
  };

  static const Map<String, Color> _colors = {
    'user': Colors.blue,
    'order': Colors.teal,
    'complaint': Colors.red,
    'announcement': Colors.purple,
    'phone': Colors.green,
    'business': Colors.orange,
    'ad': Colors.indigo,
    'story': Colors.pink,
    'moderation': Color(0xFF6366F1),
  };

  @override
  Widget build(BuildContext context) {
    final type = (data['type'] ?? 'general').toString();
    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? '').toString();
    final color = _colors[type] ?? Colors.blueGrey;
    final icon = _icons[type] ?? CupertinoIcons.info_circle_fill;

    final Timestamp? ts = data['createdAt'] as Timestamp?;
    final now = DateTime.now();
    final date = ts?.toDate() ?? now;
    final diff = now.difference(date);

    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'Az önce';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes}dk önce';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours}sa önce';
    } else if (diff.inDays < 7) {
      timeAgo = '${diff.inDays}g önce';
    } else {
      timeAgo = '${date.day}.${date.month}.${date.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(timeAgo,
            style: const TextStyle(fontSize: 11, color: Colors.black38)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Statik log yardımcısı — diğer dosyalardan çağırın
// ─────────────────────────────────────────────────────────────────────────────
class ActivityLogger {
  ActivityLogger._();

  static Future<void> log({
    required String type,
    required String title,
    String body = '',
    String? docId,
    Map<String, dynamic>? extra,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('admin_activity_log').add({
        'type': type,
        'title': title,
        'body': body,
        'docId': docId ?? '',
        'extra': extra ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

class _EventType {
  final String label;
  final IconData icon;
  final Color color;
  const _EventType(this.label, this.icon, this.color);
}
