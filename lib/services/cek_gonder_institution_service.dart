import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pazarcik_portal/services/user_notification_service.dart';

class CekGonderInstitution {
  final String id;
  final String name;
  final String category;
  final String description;
  final String phone;
  final List<String> authorizedUids;
  final List<String> authorizedPhones;
  final bool isActive;
  final int order;
  final dynamic createdAt;

  const CekGonderInstitution({
    required this.id,
    required this.name,
    this.category = 'Site / Konut Yönetimi',
    this.description = '',
    this.phone = '',
    this.authorizedUids = const [],
    this.authorizedPhones = const [],
    this.isActive = true,
    this.order = 0,
    this.createdAt,
  });

  factory CekGonderInstitution.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CekGonderInstitution(
      id: doc.id,
      name: (data['name'] ?? 'Kurum').toString(),
      category: (data['category'] ?? 'Site / Konut Yönetimi').toString(),
      description: (data['description'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      authorizedUids: List<String>.from(data['authorizedUids'] ?? []),
      authorizedPhones: List<String>.from(data['authorizedPhones'] ?? []),
      isActive: data['isActive'] ?? true,
      order: (data['order'] is num) ? (data['order'] as num).toInt() : 0,
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'category': category.trim(),
      'description': description.trim(),
      'phone': phone.trim(),
      'authorizedUids': authorizedUids,
      'authorizedPhones': authorizedPhones,
      'isActive': isActive,
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class CekGonderInstitutionService {
  CekGonderInstitutionService._();
  static final instance = CekGonderInstitutionService._();

  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('cek_gonder_institutions');

  /// Telefon numarasını standartlaştırır (örn: 5321234567)
  static String normalizePhone(String raw) {
    String p = raw.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('90') && p.length > 10) {
      p = p.substring(2);
    } else if (p.startsWith('0') && p.length > 10) {
      p = p.substring(1);
    }
    return p;
  }

  /// Aktif kurumların canlı akışı
  Stream<List<CekGonderInstitution>> streamActiveInstitutions() {
    return _collection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => CekGonderInstitution.fromFirestore(doc))
          .toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  /// Tüm kurumların canlı akışı (Admin için)
  Stream<List<CekGonderInstitution>> streamAllInstitutions() {
    return _collection.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => CekGonderInstitution.fromFirestore(doc))
          .toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  /// Koleksiyon boşsa ilk varsayılan kurumları otomatik oluşturur
  Future<void> seedDefaultsIfNeeded() async {
    try {
      final snap = await _collection.limit(1).get();
      if (snap.docs.isNotEmpty) return;

      // 1. Genel Kurum
      await _collection.doc('genel').set({
        'name': 'Genel / Pazarcık Portalı & Belediye',
        'category': 'Belediye & Genel',
        'description': 'İlçe genelindeki her türlü talep ve sorun',
        'phone': '',
        'authorizedUids': [],
        'authorizedPhones': [],
        'isActive': true,
        'order': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. İncirli TOKİ 2. Etap
      await _collection.doc('incirli_toki_2').set({
        'name': 'İncirli TOKİ 2. Etap Yönetimi',
        'category': 'Site / Konut Yönetimi',
        'description': '2. Etap bina içi arızalar, çevre düzeni ve site yönetimi',
        'phone': '',
        'authorizedUids': [],
        'authorizedPhones': [],
        'isActive': true,
        'order': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[CekGonderInstitutions] Varsayılan kurumlar oluşturuldu.');
    } catch (e) {
      debugPrint('[CekGonderInstitutions] Seed hatası: $e');
    }
  }

  /// Kullanıcının yetkili olduğu kurumları döner
  Stream<List<CekGonderInstitution>> streamInstitutionsForUser({
    required String uid,
    required String phone,
  }) {
    final normPhone = normalizePhone(phone);
    return _collection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((d) => CekGonderInstitution.fromFirestore(d))
          .where((inst) {
        if (inst.id == 'genel') return false; // Genel kurum portal adminine aittir
        if (inst.authorizedUids.contains(uid)) return true;
        if (normPhone.isNotEmpty) {
          final matchedPhone = inst.authorizedPhones.any(
            (p) => normalizePhone(p) == normPhone,
          );
          if (matchedPhone) return true;
          if (normalizePhone(inst.phone) == normPhone) return true;
        }
        return false;
      }).toList();
    });
  }

  /// Kurum ekle veya güncelle
  Future<void> saveInstitution({
    String? id,
    required String name,
    required String category,
    required String description,
    required String phone,
    required List<String> authorizedPhones,
    required List<String> authorizedUids,
    bool isActive = true,
    int order = 0,
  }) async {
    final docRef = id != null && id.isNotEmpty ? _collection.doc(id) : _collection.doc();

    final cleanPhones = authorizedPhones
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // Yetkili telefonlardan UID çözme girişimi
    final uids = List<String>.from(authorizedUids);
    for (final p in cleanPhones) {
      final norm = normalizePhone(p);
      if (norm.isEmpty) continue;
      try {
        final custSnap = await FirebaseFirestore.instance
            .collection('customers')
            .where('phone', isEqualTo: norm)
            .limit(1)
            .get();
        if (custSnap.docs.isNotEmpty) {
          final foundUid = custSnap.docs.first.id;
          if (!uids.contains(foundUid)) uids.add(foundUid);
        }
      } catch (_) {}
    }

    await docRef.set({
      'name': name.trim(),
      'category': category.trim(),
      'description': description.trim(),
      'phone': phone.trim(),
      'authorizedPhones': cleanPhones,
      'authorizedUids': uids,
      'isActive': isActive,
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Kurum sil (Genel kurum silinemez)
  Future<void> deleteInstitution(String id) async {
    if (id == 'genel') return;
    await _collection.doc(id).delete();
  }

  /// Yeni bildirim oluşturulduğunda ilgili kuruma ait yetkililere push / in-app bildirim gönderir
  Future<void> notifyInstitutionAuthorities({
    required String institutionId,
    required String institutionName,
    required String reportId,
    required String reportTitle,
    required String senderName,
    required String senderPhone,
  }) async {
    if (institutionId.isEmpty) return;

    try {
      final doc = await _collection.doc(institutionId).get();
      if (!doc.exists) return;

      final inst = CekGonderInstitution.fromFirestore(doc);
      final Set<String> targetUids = Set<String>.from(inst.authorizedUids);

      // Telefon numaraları varsa henüz eklenmemiş UID'leri bul
      for (final p in inst.authorizedPhones) {
        final norm = normalizePhone(p);
        if (norm.isEmpty) continue;
        try {
          final q = await FirebaseFirestore.instance
              .collection('customers')
              .where('phone', isEqualTo: norm)
              .get();
          for (final d in q.docs) {
            targetUids.add(d.id);
          }
        } catch (_) {}
      }

      // Her yetkiliye kişisel bildirim ilet
      for (final uid in targetUids) {
        if (uid.isEmpty) continue;
        await UserNotificationService.instance.sendNotificationToUser(
          targetUid: uid,
          title: '🏢 Yeni $institutionName Bildirimi',
          body: '$senderName: $reportTitle',
          type: 'cek_gonder_institution',
          docId: reportId,
          extraData: {
            'institutionId': institutionId,
            'institutionName': institutionName,
            'reportId': reportId,
            'reportTitle': reportTitle,
            'senderName': senderName,
            'senderPhone': senderPhone,
            'targetType': 'cek_gonder',
          },
        );
      }
    } catch (e) {
      debugPrint('[CekGonderInstitutions] Bildirim iletme hatası: $e');
    }
  }
}
