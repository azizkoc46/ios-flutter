import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

enum PrivacyChoice {
  fullName,
  initials,
  anonymous,
}

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
    if (data['isAnonymous'] == true || data['namePrivacy'] == 'anonymous') {
      return "Pazarcık Sakini";
    }
    final rawName = rawFullName(data, nameFields: nameFields);
    if (data['isNameHidden'] == true || data['namePrivacy'] == 'initials') {
      return initialsOnly(rawName);
    }
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

  static Future<bool?> askHideName(BuildContext context) async {
    final choice = await askPrivacyChoice(context);
    if (choice == null) return null;
    return choice != PrivacyChoice.fullName;
  }

  static Future<PrivacyChoice?> askPrivacyChoice(BuildContext context,
      {String? namePreview}) async {
    String name = namePreview ?? await currentUserFullName();
    final initials = initialsOnly(name);

    return showCupertinoDialog<PrivacyChoice>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("İsminiz Nasıl Görünsün?"),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "Yorum veya yanıtınızda adınızın görünürlüğünü seçebilirsiniz:\n\n"
            "• Tam Adım: $name\n"
            "• Baş Harfler: $initials\n"
            "• Gizli: Pazarcık Sakini",
            textAlign: TextAlign.left,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text("Tam Adım ($name)"),
            onPressed: () => Navigator.pop(context, PrivacyChoice.fullName),
          ),
          CupertinoDialogAction(
            child: Text("Baş Harfler ($initials)"),
            onPressed: () => Navigator.pop(context, PrivacyChoice.initials),
          ),
          CupertinoDialogAction(
            child: const Text("Gizli (Pazarcık Sakini)"),
            onPressed: () => Navigator.pop(context, PrivacyChoice.anonymous),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> authorFieldsWithMode({
    required String fullName,
    required PrivacyChoice choice,
  }) {
    String displayName;
    bool isHidden;
    bool isAnon;
    String privacyMode;

    switch (choice) {
      case PrivacyChoice.fullName:
        displayName = fullName;
        isHidden = false;
        isAnon = false;
        privacyMode = 'full';
        break;
      case PrivacyChoice.initials:
        displayName = initialsOnly(fullName);
        isHidden = true;
        isAnon = false;
        privacyMode = 'initials';
        break;
      case PrivacyChoice.anonymous:
        displayName = "Pazarcık Sakini";
        isHidden = true;
        isAnon = true;
        privacyMode = 'anonymous';
        break;
    }

    return {
      'authorFullName': fullName,
      'authorDisplayName': displayName,
      'isNameHidden': isHidden,
      'isAnonymous': isAnon,
      'namePrivacy': privacyMode,
    };
  }

  static Map<String, dynamic> authorFields({
    required String fullName,
    required bool hideName,
  }) {
    return authorFieldsWithMode(
      fullName: fullName,
      choice: hideName ? PrivacyChoice.initials : PrivacyChoice.fullName,
    );
  }
}
