// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'admin_notification_service.dart';

/// Kullanıcı şikayet / talep gönderdiğinde admine FCM bildirimi gider.
class RequestComplaintPage extends StatefulWidget {
  const RequestComplaintPage({Key? key}) : super(key: key);

  @override
  State<RequestComplaintPage> createState() => _RequestComplaintPageState();
}

class _RequestComplaintPageState extends State<RequestComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  String _category = 'Şikayet';
  bool _isLoading = false;

  final List<String> _categories = [
    'Şikayet',
    'Talep',
    'Öneri',
    'Teknik Sorun',
    'Diğer',
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      final docRef =
          await FirebaseFirestore.instance.collection('complaints').add({
        'uid': uid,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'category': _category,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ── Admin'e bildirim gönder ────────────────────────────────────────────
      await AdminNotificationService.instance.notifyAdmin(
        title:
            '${AdminNotifType.emoji(AdminNotifType.complaint)} Yeni $_category',
        body: _subjectController.text.trim(),
        type: AdminNotifType.complaint,
        docId: docRef.id,
        extra: {'category': _category},
      );
      // ──────────────────────────────────────────────────────────────────────

      if (!mounted) return;

      _subjectController.clear();
      _messageController.clear();

      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Gönderildi ✅'),
          content:
              const Text('Talebiniz alındı. En kısa sürede size dönülecektir.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Tamam'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Şikayet / Talep',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: const CupertinoNavigationBarBackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Kategori'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _label('Konu'),
              const SizedBox(height: 8),
              _field(_subjectController, 'Konuyu kısaca belirtin'),
              const SizedBox(height: 16),
              _label('Mesajınız'),
              const SizedBox(height: 8),
              _field(_messageController, 'Detaylı açıklayın...', maxLines: 6),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                          'GÖNDER',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
    );
  }

  Widget _field(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Bu alan zorunludur' : null,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );
  }
}
