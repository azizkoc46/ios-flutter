import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class CommentIdentity {
  static String initialsOnly(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return "K...";

    return parts
        .map((part) => "${part.characters.first.toUpperCase()}...")
        .join(" ");
  }

  static String visibleName(Map<String, dynamic> data,
      {List<String> nameFields = const [
        'authorName',
        'authorFullName',
        'reviewerName',
        'userName',
        'sender'
      ]}) {
    final rawName = rawFullName(data, nameFields: nameFields);
    if (data['isNameHidden'] == true) return initialsOnly(rawName);
    return (data['authorDisplayName'] ?? rawName).toString();
  }

  static String rawFullName(Map<String, dynamic> data,
      {List<String> nameFields = const [
        'authorFullName',
        'authorName',
        'reviewerName',
        'userName',
        'sender'
      ]}) {
    for (final field in nameFields) {
      final value = data[field]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value.contains('@') ? value.split('@').first : value;
      }
    }
    return "Kullanıcı";
  }

  static Future<String> currentUserFullName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Kullanıcı";

    try {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final fullname = data?['fullname']?.toString().trim();
      if (fullname != null && fullname.isNotEmpty) return fullname;
    } catch (_) {}

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;

    return "Kullanıcı";
  }

  static Future<bool?> askHideName(BuildContext context) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Adınız nasıl görünsün?"),
        content: const Text(
          "Yorumda tam adınızı gösterebilir veya sadece baş harflerinizi kullanabilirsiniz.",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Tam adım görünsün"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            child: const Text("Baş harflerim görünsün"),
            onPressed: () => Navigator.pop(context, true),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> authorFields({
    required String fullName,
    required bool hideName,
  }) {
    return {
      'authorFullName': fullName,
      'authorDisplayName': hideName ? initialsOnly(fullName) : fullName,
      'isNameHidden': hideName,
    };
  }
}
