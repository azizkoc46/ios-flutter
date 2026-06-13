// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdminModerationTab extends StatefulWidget {
  const AdminModerationTab({Key? key}) : super(key: key);

  @override
  State<AdminModerationTab> createState() => _AdminModerationTabState();
}

class _AdminModerationTabState extends State<AdminModerationTab> {
  String _collection = 'reports';

  final Map<String, String> _collections = const {
    'reports': 'Şikayetler',
    'complaints': 'Talepler',
    'comments': 'Yorumlar',
    'meydan_posts': 'Meydan',
  };

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance.collection(_collection).doc(docId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteDoc(String docId) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Sil"),
        content: const Text("Bu kayıt kalıcı olarak silinsin mi?"),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(docId)
          .delete();
    }
  }

  void _openActions(String docId, Map<String, dynamic> data) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text("Moderasyon İşlemi"),
        actions: [
          CupertinoActionSheetAction(
            child: const Text("İncelendi Yap"),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(docId, 'reviewed');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text("Çözüldü Yap"),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(docId, 'resolved');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text("Gizle / Pasif Yap"),
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(docId, 'hidden');
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () {
              Navigator.pop(context);
              _deleteDoc(docId);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text("İptal"),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection(_collection).limit(200);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _collections.entries.map((entry) {
                final selected = _collection == entry.key;
                return GestureDetector(
                  onTap: () => setState(() => _collection = entry.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, top: 10, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF6366F1) : Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Center(
                      child: Text(entry.value,
                          style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("Kayıt bulunamadı."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _moderationCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _moderationCard(String docId, Map<String, dynamic> data) {
    final title =
        _first(data, ['title', 'subject', 'reason', 'userName'], 'Kayıt');
    final body =
        _first(data, ['body', 'description', 'content', 'message'], '');
    final status = (data['status'] ?? 'pending').toString();
    final image = _first(data, ['imageUrl', 'photoUrl', 'image'], '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge(status, _statusColor(status)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _openActions(docId, data),
              child: const Icon(CupertinoIcons.ellipsis_vertical),
            ),
          ]),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54)),
          ],
          if (image.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                image,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _first(Map<String, dynamic> data, List<String> keys, String fallback) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'reviewed':
        return Colors.blue;
      case 'hidden':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}
