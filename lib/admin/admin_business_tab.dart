// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AdminBusinessTab extends StatelessWidget {
  final String type;
  // type:
  // 'emlakci', 'corporate', 'private', 'public', 'vendor', 'community', 'claims'

  const AdminBusinessTab({
    Key? key,
    required this.type,
  }) : super(key: key);

  bool get _isBusinessList => type == 'private' || type == 'public';
  bool get _isCommunityList => type == 'community';
  bool get _isCorporateApplications => type == 'corporate';
  bool get _isUserApproval => type == 'emlakci' || type == 'vendor';
  bool get _isOwnershipClaims => type == 'claims';

  String get _mainCollection {
    if (_isBusinessList) return 'businesses';
    if (_isCommunityList) return 'dernekler';
    if (_isCorporateApplications) return 'corporate_seller_applications';
    if (_isOwnershipClaims) return 'business_claims';
    return 'customers';
  }

  Query _buildQuery() {
    if (type == 'private' || type == 'public') {
      return FirebaseFirestore.instance
          .collection('businesses')
          .where('type', isEqualTo: type);
    }

    if (type == 'community') {
      return FirebaseFirestore.instance.collection('dernekler');
    }

    if (type == 'corporate') {
      return FirebaseFirestore.instance
          .collection('corporate_seller_applications')
          .orderBy('createdAt', descending: true);
    }

    if (type == 'claims') {
      return FirebaseFirestore.instance
          .collection('business_claims')
          .orderBy('timestamp', descending: true);
    }

    if (type == 'emlakci') {
      return FirebaseFirestore.instance
          .collection('customers')
          .where('role', whereIn: [
        'emlakci',
        'emlakci_pending',
        'kurumsal_satici',
        'kurumsal_satici_pending',
      ]);
    }

    return FirebaseFirestore.instance
        .collection('customers')
        .where('role', whereIn: [
      'satici',
      'vendor_pending',
      'seller',
      'seller_pending',
    ]);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    bool destructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text("Vazgeç"),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            isDefaultAction: !destructive,
            child: Text(destructive ? "Sil / Reddet" : "Onayla"),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _approveBusiness(
    BuildContext context,
    String docId,
    String collection,
  ) async {
    await FirebaseFirestore.instance.collection(collection).doc(docId).update({
      'status': 'approved',
      'isActive': true,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteDocument(
    BuildContext context,
    String docId,
    String collection,
  ) async {
    await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
  }

  Future<void> _approveLegacyUser(
    BuildContext context,
    String userId,
    Map<String, dynamic> data,
  ) async {
    final bool isEmlak = type == 'emlakci';

    if (isEmlak) {
      await FirebaseFirestore.instance.collection('customers').doc(userId).set({
        'role': 'emlakci',
        'isApproved': true,
        'sellerApproved': true,
        'corporateSellerApproved': true,
        'sellerStatus': 'approved',
        'corporateSellerStatus': 'approved',
        'allowedCorporateCategories': ['Emlak'],
        'approvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await FirebaseFirestore.instance.collection('customers').doc(userId).set({
      'role': 'satici',
      'isSeller': true,
      'isApproved': true,
      'sellerApproved': true,
      'sellerStatus': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _rejectLegacyUser(
    BuildContext context,
    String userId,
  ) async {
    await FirebaseFirestore.instance.collection('customers').doc(userId).set({
      'role': 'customer',
      'isApproved': false,
      'isSeller': false,
      'sellerApproved': false,
      'corporateSellerApproved': false,
      'sellerStatus': 'rejected',
      'corporateSellerStatus': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _approveCorporateApplication(
    BuildContext context,
    String applicationId,
    Map<String, dynamic> data,
  ) async {
    final String userId = (data['userId'] ?? '').toString();

    if (userId.isEmpty) {
      throw Exception("Başvuruda userId bulunamadı.");
    }

    final requestedRaw =
        data['requestedCategories'] ?? data['allowedCategories'] ?? [];

    final List<String> allowedCategories = requestedRaw is List
        ? requestedRaw.map((e) => e.toString()).toList()
        : <String>['Emlak', 'Sıfır Ürün'];

    final String businessName = (data['businessName'] ?? '').toString();
    final String taxId = (data['taxId'] ?? '').toString();
    final String officePhone = (data['officePhone'] ?? '').toString();
    final String businessAddress = (data['businessAddress'] ?? '').toString();

    final batch = FirebaseFirestore.instance.batch();

    final appRef = FirebaseFirestore.instance
        .collection('corporate_seller_applications')
        .doc(applicationId);

    final userRef =
        FirebaseFirestore.instance.collection('customers').doc(userId);

    batch.set(
      appRef,
      {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      userRef,
      {
        if (businessName.isNotEmpty) 'businessName': businessName,
        if (businessName.isNotEmpty) 'storeName': businessName,
        if (taxId.isNotEmpty) 'taxId': taxId,
        if (officePhone.isNotEmpty) 'officePhone': officePhone,
        if (businessAddress.isNotEmpty) 'businessAddress': businessAddress,
        'role': 'kurumsal_satici',
        'isSeller': true,
        'isApproved': true,
        'sellerApproved': true,
        'corporateSellerApproved': true,
        'sellerStatus': 'approved',
        'corporateSellerStatus': 'approved',
        'allowedCorporateCategories': allowedCategories,
        'corporateApplicationId': applicationId,
        'approvedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> _rejectCorporateApplication(
    BuildContext context,
    String applicationId,
    Map<String, dynamic> data,
  ) async {
    final String userId = (data['userId'] ?? '').toString();

    final batch = FirebaseFirestore.instance.batch();

    final appRef = FirebaseFirestore.instance
        .collection('corporate_seller_applications')
        .doc(applicationId);

    batch.set(
      appRef,
      {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (userId.isNotEmpty) {
      final userRef =
          FirebaseFirestore.instance.collection('customers').doc(userId);

      batch.set(
        userRef,
        {
          'role': 'customer',
          'sellerApproved': false,
          'corporateSellerApproved': false,
          'sellerStatus': 'rejected',
          'corporateSellerStatus': 'rejected',
          'allowedCorporateCategories': [],
          'rejectedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> _approveOwnershipClaim(
    BuildContext context,
    String claimId,
    Map<String, dynamic> data,
  ) async {
    final String businessId = (data['businessId'] ?? '').toString();
    final String userId = (data['userId'] ?? '').toString();

    if (businessId.isEmpty || userId.isEmpty) {
      throw Exception("Başvuruda businessId veya userId bulunamadı.");
    }

    final batch = FirebaseFirestore.instance.batch();
    final claimRef =
        FirebaseFirestore.instance.collection('business_claims').doc(claimId);
    final businessRef =
        FirebaseFirestore.instance.collection('businesses').doc(businessId);
    final userRef =
        FirebaseFirestore.instance.collection('customers').doc(userId);

    batch.set(
      claimRef,
      {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      businessRef,
      {
        'ownerId': userId,
        'editorId': userId,
        'claimedBy': userId,
        'claimId': claimId,
        'claimStatus': 'approved',
        'status': 'approved',
        'isActive': true,
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      userRef,
      {
        'managedBusinessIds': FieldValue.arrayUnion([businessId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> _rejectOwnershipClaim(
    BuildContext context,
    String claimId,
    Map<String, dynamic> data,
  ) async {
    await FirebaseFirestore.instance
        .collection('business_claims')
        .doc(claimId)
        .set({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _handleApprove(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final ok = await _confirm(
      context,
      title: "Onayla",
      message: "Bu kaydı onaylamak istiyor musunuz?",
    );

    if (!ok) return;

    try {
      if (_isBusinessList || _isCommunityList) {
        await _approveBusiness(context, docId, _mainCollection);
      } else if (_isCorporateApplications) {
        await _approveCorporateApplication(context, docId, data);
      } else if (_isOwnershipClaims) {
        await _approveOwnershipClaim(context, docId, data);
      } else if (_isUserApproval) {
        await _approveLegacyUser(context, docId, data);
      }

      if (!context.mounted) return;
      _showSnack(context, "İşlem başarılı.", Colors.green);
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, "Hata oluştu: $e", Colors.red);
    }
  }

  Future<void> _handleRejectOrDelete(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final ok = await _confirm(
      context,
      title: _isBusinessList || _isCommunityList ? "Sil" : "Reddet",
      message: _isBusinessList || _isCommunityList
          ? "Bu kaydı kalıcı olarak silmek istiyor musunuz?"
          : "Bu başvuruyu reddetmek istiyor musunuz?",
      destructive: true,
    );

    if (!ok) return;

    try {
      if (_isBusinessList || _isCommunityList) {
        await _deleteDocument(context, docId, _mainCollection);
      } else if (_isCorporateApplications) {
        await _rejectCorporateApplication(context, docId, data);
      } else if (_isOwnershipClaims) {
        await _rejectOwnershipClaim(context, docId, data);
      } else if (_isUserApproval) {
        await _rejectLegacyUser(context, docId);
      }

      if (!context.mounted) return;
      _showSnack(context, "İşlem başarılı.", Colors.green);
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, "Hata oluştu: $e", Colors.red);
    }
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
      ),
    );
  }

  String _title(Map<String, dynamic> data) {
    return (data['businessName'] ??
            data['storeName'] ??
            data['fullname'] ??
            data['fullName'] ??
            data['name'] ??
            data['dernekName'] ??
            data['applicantName'] ??
            "İsimsiz")
        .toString();
  }

  String _subtitle(Map<String, dynamic> data) {
    return (data['category'] ??
            data['phone'] ??
            data['phoneNumber'] ??
            data['officePhone'] ??
            data['businessAddress'] ??
            data['address'] ??
            "")
        .toString();
  }

  String _status(Map<String, dynamic> data) {
    return (data['status'] ??
            data['corporateSellerStatus'] ??
            data['sellerStatus'] ??
            "")
        .toString();
  }

  bool _isPending(Map<String, dynamic> data) {
    final status = _status(data);
    final role = (data['role'] ?? '').toString();

    return status == 'pending' ||
        role.contains('pending') ||
        data['isApproved'] == false;
  }

  bool _isApproved(Map<String, dynamic> data) {
    final status = _status(data);
    final role = (data['role'] ?? '').toString();

    return status == 'approved' ||
        role == 'emlakci' ||
        role == 'satici' ||
        role == 'kurumsal_satici' ||
        data['isApproved'] == true ||
        data['sellerApproved'] == true ||
        data['corporateSellerApproved'] == true;
  }

  List<String> _categories(Map<String, dynamic> data) {
    final raw = data['requestedCategories'] ??
        data['allowedCategories'] ??
        data['allowedCorporateCategories'] ??
        [];

    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }

    return [];
  }

  Color _statusColor(Map<String, dynamic> data) {
    if (_isApproved(data)) return Colors.green;
    if (_isPending(data)) return Colors.orange;
    if (_status(data) == 'rejected') return Colors.red;
    return Colors.blueGrey;
  }

  String _statusText(Map<String, dynamic> data) {
    if (_isApproved(data)) return "Onaylı";
    if (_isPending(data)) return "Beklemede";
    if (_status(data) == 'rejected') return "Reddedildi";
    return "Kayıt";
  }

  IconData _typeIcon() {
    switch (type) {
      case 'emlakci':
        return CupertinoIcons.house_fill;
      case 'corporate':
        return CupertinoIcons.building_2_fill;
      case 'claims':
        return CupertinoIcons.checkmark_seal_fill;
      case 'vendor':
        return CupertinoIcons.cart_fill;
      case 'community':
        return CupertinoIcons.person_3_fill;
      case 'public':
        return CupertinoIcons.building_2_fill;
      default:
        return CupertinoIcons.briefcase_fill;
    }
  }

  String _emptyText() {
    switch (type) {
      case 'emlakci':
        return "Emlakçı başvurusu bulunamadı.";
      case 'corporate':
        return "Kurumsal satıcı başvurusu bulunamadı.";
      case 'claims':
        return "Sahiplik basvurusu bulunamadi.";
      case 'vendor':
        return "Satıcı başvurusu bulunamadı.";
      case 'community':
        return "Dernek kaydı bulunamadı.";
      case 'public':
        return "Kamu kaydı bulunamadı.";
      default:
        return "Kayıt bulunamadı.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _buildQuery();

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }

        var docs = snapshot.data!.docs;

        if (_isCorporateApplications) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] != 'archived';
          }).toList();
        }

        if (_isOwnershipClaims) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['status'] ?? 'pending') != 'archived';
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Text(
              _emptyText(),
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;

            return _buildCard(context, docId, data);
          },
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final pending = _isPending(data);
    final statusColor = _statusColor(data);
    final categories = _categories(data);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: statusColor.withOpacity(0.12),
                child: Icon(_typeIcon(), color: statusColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(data),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_subtitle(data).isNotEmpty)
                      Text(
                        _subtitle(data),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              _badge(_statusText(data), statusColor),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: categories
                    .map((e) => _badge(e, const Color(0xFF0056D2)))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _details(data),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleRejectOrDelete(context, docId, data),
                  icon: Icon(
                    _isBusinessList || _isCommunityList
                        ? CupertinoIcons.delete
                        : CupertinoIcons.xmark_circle,
                    size: 17,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  label: Text(
                    _isBusinessList || _isCommunityList ? "Sil" : "Reddet",
                  ),
                ),
              ),
              if (pending || !_isApproved(data)) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(context, docId, data),
                    icon: const Icon(CupertinoIcons.checkmark_circle, size: 17),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    label: const Text("Onayla"),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _details(Map<String, dynamic> data) {
    final fields = <MapEntry<String, String>>[
      MapEntry("Vergi No", (data['taxId'] ?? '').toString()),
      MapEntry("Vergi / TC No", (data['taxNumber'] ?? '').toString()),
      MapEntry(
          "Telefon", (data['officePhone'] ?? data['phone'] ?? '').toString()),
      MapEntry("Adres",
          (data['businessAddress'] ?? data['address'] ?? '').toString()),
      MapEntry("Not", (data['note'] ?? '').toString()),
      MapEntry("Basvuran", (data['applicantName'] ?? '').toString()),
      MapEntry("Isletme ID", (data['businessId'] ?? '').toString()),
      MapEntry("Kullanıcı ID", (data['userId'] ?? '').toString()),
    ].where((e) => e.value.trim().isNotEmpty).toList();

    if (fields.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: fields.map((field) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 86,
                  child: Text(
                    field.key,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    field.value,
                    maxLines:
                        field.key == "Not" || field.key == "Adres" ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
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
}
