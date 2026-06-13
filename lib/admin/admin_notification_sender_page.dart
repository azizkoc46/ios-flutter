// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AdminNotificationSenderPage extends StatefulWidget {
  const AdminNotificationSenderPage({Key? key}) : super(key: key);

  @override
  State<AdminNotificationSenderPage> createState() =>
      _AdminNotificationSenderPageState();
}

class _AdminNotificationSenderPageState
    extends State<AdminNotificationSenderPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _linkController = TextEditingController();

  final _targetIdController = TextEditingController();
  final _targetLabelController = TextEditingController();
  final _targetExtraIdController = TextEditingController();

  final List<TextEditingController> _pollControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  String _selectedType = 'Duyuru';
  String _selectedTargetType = 'none';

  File? _selectedImage;
  bool _isLoading = false;

  final Color adminColor = const Color(0xFF0056D2);
  final Color bgGrey = const Color(0xFFF2F2F7);
  static const String _projectId = 'pazarcik-portal-7faf2';

  final Map<String, String> _targetLabels = const {
    'none': 'Yönlendirme Yok',
    'ad': 'Sahibinden İlanı',
    'seller': 'Sahibinden Satıcı / Mağaza',
    'business': 'İşletme',
    'job': 'İş İlanı',
    'meydan_post': 'Meydan Gönderisi',
    'group': 'Grup',
    'food_store': 'Yemek Mağazası',
    'food_product': 'Yemek Ürünü',
    'profile': 'Profil Sayfası',
    'notifications': 'Bildirim Merkezi',
  };

  @override
  void initState() {
    super.initState();
    assert(() {
      _sendPushMessageToTopic;
      return true;
    }());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _linkController.dispose();
    _targetIdController.dispose();
    _targetLabelController.dispose();
    _targetExtraIdController.dispose();

    for (final c in _pollControllers) {
      c.dispose();
    }

    super.dispose();
  }

  String _normalizeUrl(String raw) {
    String url = raw.trim();

    if (url.isEmpty) return "";

    if (url.startsWith("@")) {
      final username = url.replaceFirst("@", "");
      return "https://instagram.com/$username";
    }

    if (url.startsWith("instagram.com/") || url.startsWith("www.")) {
      return "https://$url";
    }

    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      return "https://$url";
    }

    return url;
  }

  bool _needsPicker(String type) {
    return [
      'ad',
      'seller',
      'business',
      'job',
      'meydan_post',
      'group',
      'food_store',
      'food_product',
    ].contains(type);
  }

  String _targetCollectionForType(String type) {
    switch (type) {
      case 'ad':
        return 'classified_ads';
      case 'seller':
        return 'customers';
      case 'business':
        return 'businesses';
      case 'job':
        return 'job_ads';
      case 'meydan_post':
        return 'meydan_posts';
      case 'group':
        return 'groups';
      case 'food_store':
        return 'customers';
      case 'food_product':
        return 'products';
      default:
        return '';
    }
  }

  String _effectiveTargetType(String linkUrl) {
    if (_selectedTargetType != 'none') return _selectedTargetType;
    if (linkUrl.isNotEmpty) return 'url';
    return 'none';
  }

  _TargetPickerConfig? _pickerConfig(String type) {
    switch (type) {
      case 'ad':
        return const _TargetPickerConfig(
          collection: 'classified_ads',
          titleFields: ['title'],
          subtitleFields: ['category', 'subCategory', 'price'],
          filters: {'status': 'active'},
        );
      case 'seller':
        return const _TargetPickerConfig(
          collection: 'customers',
          titleFields: ['businessName', 'storeName', 'fullName', 'name'],
          subtitleFields: ['phone', 'phoneNumber'],
          filters: {'corporateSellerApproved': true},
        );
      case 'business':
        return const _TargetPickerConfig(
          collection: 'businesses',
          titleFields: ['name', 'businessName', 'title'],
          subtitleFields: ['category', 'address'],
        );
      case 'job':
        return const _TargetPickerConfig(
          collection: 'job_ads',
          titleFields: ['title'],
          subtitleFields: ['companyName', 'location'],
        );
      case 'meydan_post':
        return const _TargetPickerConfig(
          collection: 'meydan_posts',
          titleFields: ['title', 'content', 'body'],
          subtitleFields: ['authorName', 'category'],
        );
      case 'group':
        return const _TargetPickerConfig(
          collection: 'groups',
          titleFields: ['name', 'title'],
          subtitleFields: ['description'],
        );
      case 'food_store':
        return const _TargetPickerConfig(
          collection: 'sellers',
          titleFields: [
            'storeName',
            'businessName',
            'shopName',
            'companyName',
            'name',
            'fullName',
            'fullname',
          ],
          subtitleFields: [
            'phone',
            'phoneNumber',
            'address',
            'businessAddress',
            'category',
          ],
        );
      case 'food_product':
        return const _TargetPickerConfig(
          collection: 'products',
          titleFields: ['name', 'title'],
          subtitleFields: ['storeName', 'category', 'price'],
        );
      default:
        return null;
    }
  }

  Future<String> _getAccessToken() async {
    throw UnsupportedError(
        'Push gonderimi Firebase Functions kuyruğuna taşındı.');
  }

  Future<void> _sendPushMessageToTopic({
    required String notificationId,
    required String title,
    required String body,
    required String type,
    required String targetType,
    required String targetId,
    required String targetLabel,
    required String targetExtraId,
    required String targetCollection,
    required String linkUrl,
    required String imageUrl,
  }) async {
    final token = await _getAccessToken();

    final response = await http.post(
      Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'message': {
          'topic': 'pazarcik_duyuru',
          'notification': {
            'title': title,
            'body': body,
            if (imageUrl.isNotEmpty) 'image': imageUrl,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'notificationId': notificationId,
            'type': type,
            'targetType': targetType,
            'targetId': targetId,
            'targetLabel': targetLabel,
            'targetExtraId': targetExtraId,
            'targetCollection': targetCollection,
            'linkUrl': linkUrl,
            'imageUrl': imageUrl,
          },
          'android': {
            'priority': 'high',
            'notification': {
              'sound': 'default',
              if (imageUrl.isNotEmpty) 'image': imageUrl,
            },
          },
          'apns': {
            'payload': {
              'aps': {'sound': 'default', 'badge': 1},
            },
          },
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("FCM gönderim hatası: ${response.body}");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
    );

    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _openTargetPicker() {
    final config = _pickerConfig(_selectedTargetType);
    if (config == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _TargetPickerSheet(
          title: _targetLabels[_selectedTargetType] ?? "Kayıt Seç",
          collection: config.collection,
          titleFields: config.titleFields,
          subtitleFields: config.subtitleFields,
          filters: config.filters,
          onSelected: (id, label, extraId) {
            setState(() {
              _targetIdController.text = id;
              _targetLabelController.text = label;
              _targetExtraIdController.text = extraId ?? '';
            });
          },
        );
      },
    );
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == 'Anket') {
      final options = _pollControllers
          .map((c) => c.text.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (options.length < 2) {
        _showToast("Anket için en az 2 seçenek girmelisiniz.", Colors.red);
        return;
      }
    }

    if (_needsPicker(_selectedTargetType) &&
        _targetIdController.text.trim().isEmpty) {
      _showToast("Lütfen yönlendirilecek kaydı seçin.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = "";

      if (_selectedImage != null) {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance
            .ref()
            .child('notifications/images/$fileName.jpg');

        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      final linkUrl = _normalizeUrl(_linkController.text);
      final targetType = _effectiveTargetType(linkUrl);
      final targetCollection = _targetCollectionForType(targetType);

      final pollOptions = _selectedType == 'Anket'
          ? _pollControllers
              .map((c) => c.text.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];

      final docRef =
          await FirebaseFirestore.instance.collection('app_notifications').add({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'type': _selectedType,
        'imageUrl': imageUrl,
        'linkUrl': linkUrl,
        'targetType': targetType,
        'targetId': _targetIdController.text.trim(),
        'targetLabel': _targetLabelController.text.trim(),
        'targetExtraId': _targetExtraIdController.text.trim(),
        'targetCollection': targetCollection,
        'pollOptions': pollOptions,
        'senderId': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'pushStatus': 'queued',
      });

      await FirebaseFirestore.instance
          .collection('notification_send_requests')
          .add({
        'notificationId': docRef.id,
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'type': _selectedType,
        'targetType': targetType,
        'targetId': _targetIdController.text.trim(),
        'targetLabel': _targetLabelController.text.trim(),
        'targetExtraId': _targetExtraIdController.text.trim(),
        'targetCollection': targetCollection,
        'linkUrl': linkUrl,
        'imageUrl': imageUrl,
        'pollOptions': pollOptions,
        'topic': 'pazarcik_duyuru',
        'requestedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'queued',
      });

      if (!mounted) return;

      _showSuccessDialog();
      _clearForm();
    } catch (e) {
      _showToast("Hata oluştu: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _bodyController.clear();
    _linkController.clear();
    _targetIdController.clear();
    _targetLabelController.clear();
    _targetExtraIdController.clear();

    for (final c in _pollControllers) {
      c.clear();
    }

    setState(() {
      _selectedImage = null;
      _selectedType = 'Duyuru';
      _selectedTargetType = 'none';
    });
  }

  Future<void> _toggleNotificationStatus(String docId, bool current) async {
    await FirebaseFirestore.instance
        .collection('app_notifications')
        .doc(docId)
        .update({
      'isActive': !current,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteNotification(String docId) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Bildirimi Sil"),
        content:
            const Text("Bu bildirimi kalıcı olarak silmek istiyor musunuz?"),
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

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('app_notifications')
        .doc(docId)
        .delete();
  }

  void _showReadUsers(String notificationId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminBottomSheet(
        title: "Okuyan Kullanıcılar",
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('app_notifications')
              .doc(notificationId)
              .collection('reads')
              .orderBy('readAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(child: Text("Henüz okuyan yok."));
            }

            return ListView.builder(
              itemCount: docs.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final Timestamp? readAt = data['readAt'];

                return ListTile(
                  leading: const Icon(CupertinoIcons.person_fill),
                  title: Text(data['userName'] ?? data['uid'] ?? 'Kullanıcı'),
                  subtitle: Text(
                    readAt == null
                        ? data['uid'] ?? ''
                        : "${data['uid'] ?? ''}\n${readAt.toDate()}",
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showPollResults(String notificationId, List pollOptions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminBottomSheet(
        title: "Anket Sonuçları",
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('app_notifications')
              .doc(notificationId)
              .collection('votes')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final docs = snapshot.data!.docs;
            final Map<String, int> counts = {
              for (final option in pollOptions) option.toString(): 0,
            };

            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final choice = (data['choice'] ?? '').toString();

              if (counts.containsKey(choice)) {
                counts[choice] = counts[choice]! + 1;
              }
            }

            final total = docs.length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  "Toplam oy: $total",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ...counts.entries.map((entry) {
                  final percent =
                      total == 0 ? 0.0 : (entry.value / total).clamp(0.0, 1.0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              "${entry.value} oy",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: percent,
                            minHeight: 8,
                            backgroundColor: Colors.black12,
                            color: adminColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showNotificationActions(String docId, bool isActive) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text("Bildirim İşlemleri"),
        actions: [
          CupertinoActionSheetAction(
            child: Text(isActive ? "Pasife Al" : "Aktif Et"),
            onPressed: () {
              Navigator.pop(context);
              _toggleNotificationStatus(docId, isActive);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text("Sil"),
            onPressed: () {
              Navigator.pop(context);
              _deleteNotification(docId);
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
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Bildirim Yönetimi",
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.left_chevron, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 15))
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: const TabBar(
                      labelColor: Color(0xFF0056D2),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFF0056D2),
                      tabs: [
                        Tab(text: "Yeni Gönder"),
                        Tab(text: "Gönderilenler"),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCreateForm(),
                        _buildSentNotifications(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("BİLDİRİM TÜRÜ"),
            _buildTypeSelector(),
            const SizedBox(height: 22),
            _buildSectionTitle("İÇERİK"),
            _buildTextField(
              _titleController,
              "Bildirim başlığı",
              CupertinoIcons.textbox,
            ),
            _buildTextField(
              _bodyController,
              "Açıklama / mesaj detayı",
              CupertinoIcons.text_alignleft,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            _buildSectionTitle("DIŞ BAĞLANTI"),
            _buildOptionalTextField(
              _linkController,
              "Instagram profili, web sitesi veya dış bağlantı",
              CupertinoIcons.link,
            ),
            const SizedBox(height: 10),
            _buildSectionTitle("UYGULAMA İÇİ YÖNLENDİRME"),
            _buildTargetSelector(),
            if (_needsPicker(_selectedTargetType)) _buildTargetPickButton(),
            if (_selectedTargetType == 'profile' ||
                _selectedTargetType == 'notifications')
              _buildStaticTargetInfo(),
            if (_selectedType == 'Anket') _buildPollOptions(),
            const SizedBox(height: 22),
            _buildSectionTitle("GÖRSEL"),
            _buildImageUploader(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSentNotifications() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("Henüz bildirim gönderilmedi."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final title = (data['title'] ?? '').toString();
            final body = (data['body'] ?? '').toString();
            final type = (data['type'] ?? 'Duyuru').toString();
            final linkUrl = (data['linkUrl'] ?? '').toString();
            final targetType = (data['targetType'] ?? 'none').toString();
            final targetLabel = (data['targetLabel'] ?? '').toString();
            final pushStatus = (data['pushStatus'] ?? '').toString();
            final isActive = data['isActive'] == true;
            final pollOptions = data['pollOptions'] as List? ?? [];

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
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _miniBadge(type, adminColor),
                      _miniBadge(
                        isActive ? "Aktif" : "Pasif",
                        isActive ? Colors.green : Colors.orange,
                      ),
                      if (pushStatus.isNotEmpty)
                        _miniBadge(
                          pushStatus,
                          pushStatus == 'sent' ? Colors.green : Colors.blueGrey,
                        ),
                      if (linkUrl.isNotEmpty)
                        _miniBadge("Dış Link", Colors.purple),
                      if (targetType != 'none' && targetType != 'url')
                        _miniBadge(
                          targetLabel.isNotEmpty
                              ? targetLabel
                              : (_targetLabels[targetType] ?? targetType),
                          Colors.deepPurple,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showReadUsers(doc.id),
                          icon: const Icon(CupertinoIcons.eye),
                          label: const Text("Okuyanlar"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (type == 'Anket')
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showPollResults(doc.id, pollOptions),
                            icon: const Icon(Icons.poll_outlined),
                            label: const Text("Sonuçlar"),
                          ),
                        ),
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.ellipsis_vertical),
                        onPressed: () => _showNotificationActions(
                          doc.id,
                          isActive,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTargetSelector() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTargetType,
          isExpanded: true,
          items: _targetLabels.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(
                entry.value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedTargetType = value;
              _targetIdController.clear();
              _targetLabelController.clear();
              _targetExtraIdController.clear();
            });
          },
        ),
      ),
    );
  }

  Widget _buildTargetPickButton() {
    final hasSelection = _targetIdController.text.trim().isNotEmpty;
    final label = _targetLabelController.text.trim();

    return GestureDetector(
      onTap: _openTargetPicker,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(
              hasSelection
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.search,
              color: hasSelection ? Colors.green : adminColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasSelection ? "Seçildi: $label" : "Kayıt seç",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: hasSelection ? Colors.green : Colors.black87,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticTargetInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Text(
        "Bu hedef için kayıt seçmeye gerek yok.",
        style: TextStyle(
          color: adminColor,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildPollOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: _buildSectionTitle("ANKET SEÇENEKLERİ")),
            if (_pollControllers.length < 5)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _pollControllers.add(TextEditingController());
                  });
                },
                icon: Icon(
                  CupertinoIcons.add_circled_solid,
                  color: adminColor,
                  size: 16,
                ),
                label: Text(
                  "Seçenek Ekle",
                  style: TextStyle(color: adminColor, fontSize: 12),
                ),
              ),
          ],
        ),
        ...List.generate(_pollControllers.length, (index) {
          return Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _pollControllers[index],
                  "${index + 1}. seçenek",
                  CupertinoIcons.list_bullet,
                ),
              ),
              if (_pollControllers.length > 2)
                IconButton(
                  icon: const Icon(
                    CupertinoIcons.minus_circle_fill,
                    color: Colors.red,
                  ),
                  onPressed: () {
                    setState(() {
                      _pollControllers[index].dispose();
                      _pollControllers.removeAt(index);
                    });
                  },
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: CupertinoSegmentedControl<String>(
        padding: const EdgeInsets.all(5),
        groupValue: _selectedType,
        selectedColor: adminColor,
        borderColor: Colors.transparent,
        pressedColor: adminColor.withOpacity(0.16),
        children: {
          'Duyuru': _segmentText("Duyuru"),
          'Anket': _segmentText("Anket"),
        },
        onValueChanged: (val) => setState(() => _selectedType = val),
      ),
    );
  }

  Widget _segmentText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.black45,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (v) => v!.trim().isEmpty ? "Bu alan zorunludur" : null,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: maxLines == 1
              ? Icon(icon, color: adminColor.withOpacity(0.65), size: 20)
              : null,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildOptionalTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        validator: (_) => null,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: adminColor.withOpacity(0.65), size: 20),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildImageUploader() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 158,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: adminColor.withOpacity(0.25), width: 1.4),
        ),
        child: _selectedImage != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: Colors.red,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.photo_on_rectangle,
                    color: adminColor.withOpacity(0.5),
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Galeriden görsel seçin",
                    style: TextStyle(
                      color: adminColor.withOpacity(0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: adminColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: _sendNotification,
        icon: const Icon(CupertinoIcons.paperplane_fill, color: Colors.white),
        label: Text(
          "KULLANICILARA GÖNDER",
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  void _showToast(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Başarıyla Gönderildi"),
        content: const Text(
          "Bildirim sisteme kaydedildi ve kullanıcılara push olarak gönderildi.",
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Tamam"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _AdminBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _AdminBottomSheet({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _TargetPickerConfig {
  final String collection;
  final List<String> titleFields;
  final List<String> subtitleFields;
  final Map<String, dynamic> filters;

  const _TargetPickerConfig({
    required this.collection,
    required this.titleFields,
    required this.subtitleFields,
    this.filters = const {},
  });
}

class _TargetPickerSheet extends StatefulWidget {
  final String title;
  final String collection;
  final List<String> titleFields;
  final List<String> subtitleFields;
  final Map<String, dynamic> filters;
  final void Function(String id, String label, String? extraId) onSelected;

  const _TargetPickerSheet({
    required this.title,
    required this.collection,
    required this.titleFields,
    required this.subtitleFields,
    required this.filters,
    required this.onSelected,
  });

  @override
  State<_TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends State<_TargetPickerSheet> {
  String search = "";

  String _firstValue(Map<String, dynamic> data, List<String> fields) {
    for (final field in fields) {
      final value = data[field];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection(widget.collection);

    widget.filters.forEach((key, value) {
      query = query.where(key, isEqualTo: value);
    });

    query = query.limit(80);

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                placeholder: "Ara",
                onChanged: (v) => setState(() => search = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  var docs = snapshot.data!.docs;

                  if (search.isNotEmpty) {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final title =
                          _firstValue(data, widget.titleFields).toLowerCase();
                      final subtitle = _firstValue(data, widget.subtitleFields)
                          .toLowerCase();
                      return title.contains(search) ||
                          subtitle.contains(search);
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(child: Text("Kayıt bulunamadı."));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final rawLabel = _firstValue(data, widget.titleFields);
                      final label = rawLabel.isEmpty ? "Başlıksız" : rawLabel;
                      final subtitle = _firstValue(data, widget.subtitleFields);

                      final extraId = (data['storeId'] ??
                              data['sellerId'] ??
                              data['ownerId'] ??
                              '')
                          .toString();

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(CupertinoIcons.link),
                        ),
                        title: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: subtitle.isEmpty
                            ? null
                            : Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: const Icon(CupertinoIcons.chevron_right),
                        onTap: () {
                          widget.onSelected(doc.id, label, extraId);
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
