// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CommentManagementPage extends StatefulWidget {
  const CommentManagementPage({Key? key}) : super(key: key);

  @override
  State<CommentManagementPage> createState() => _CommentManagementPageState();
}

class AdminCommentItem {
  final String id;
  final DocumentReference reference;
  final String text;
  final String authorName;
  final String authorId;
  final String authorAvatar;
  final DateTime? createdAt;
  final double? rating;
  final String category; // 'all', 'meydan', 'business', 'public', 'community', 'restaurant', 'classified'
  final String categoryLabel;
  final Color categoryColor;
  final IconData categoryIcon;
  final String targetId;
  final bool isSuspicious;
  final List<String> detectedWords;

  AdminCommentItem({
    required this.id,
    required this.reference,
    required this.text,
    required this.authorName,
    required this.authorId,
    required this.authorAvatar,
    required this.createdAt,
    required this.rating,
    required this.category,
    required this.categoryLabel,
    required this.categoryColor,
    required this.categoryIcon,
    required this.targetId,
    required this.isSuspicious,
    required this.detectedWords,
  });
}

class _CommentManagementPageState extends State<CommentManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, suspicious, meydan, business, restaurant, classified, public
  bool _onlySuspicious = false;

  StreamSubscription? _subComments;
  StreamSubscription? _subReviews;
  StreamSubscription? _subSellerReviews;

  List<AdminCommentItem> _allComments = [];
  bool _isLoading = true;

  // ── Argo & Küfür Tespit Radarı ──
  static final List<String> _profanityList = [
    'amk', 'aq', 'orospu', 'oç', 'piç', 'siktir', 'sik', 'yarrak', 'yarak',
    'amına', 'amın', 'göt', 'götlek', 'kahpe', 'pezevenk', 'ibne', 'puşt',
    'şerefsiz', 'haysiyetsiz', 'namussuz', 'köpek', 'dangalak', 'gerizekalı',
    'aptal', 'salak', 'ahmak', 'bok', 'ananı', 'bacını', 'sokayım', 'sikim',
    'siktim', 'it oğlu', 'kahbe', 'yavşak', 'kaşar', 'fahişe', 'kerhane',
    'dalyarak', 'gavat', 'kavat', 'şerefsizler', 'mallar'
  ];

  @override
  void initState() {
    super.initState();
    _listenToAllComments();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subComments?.cancel();
    _subReviews?.cancel();
    _subSellerReviews?.cancel();
    super.dispose();
  }

  // ── Tüm Yorum Kaynaklarını Eş Zamanlı Dinle ──
  void _listenToAllComments() {
    Map<String, AdminCommentItem> commentMap = {};

    void refreshList() {
      if (!mounted) return;
      final list = commentMap.values.toList();
      list.sort((a, b) {
        final dateA = a.createdAt ?? DateTime(2000);
        final dateB = b.createdAt ?? DateTime(2000);
        return dateB.compareTo(dateA); // En yeniden en eskiye
      });
      setState(() {
        _allComments = list;
        _isLoading = false;
      });
    }

    // 1. collectionGroup('comments') -> Meydan, İşletmeler, Kamu, Dernekler
    _subComments = FirebaseFirestore.instance
        .collectionGroup('comments')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final item = _parseComment(doc.id, doc.reference, data);
        commentMap[doc.reference.path] = item;
      }
      refreshList();
    }, onError: (e) {
      debugPrint("Comments stream hatası: $e");
      setState(() => _isLoading = false);
    });

    // 2. collection('reviews') -> Restoran & Yemek Siparişi
    _subReviews = FirebaseFirestore.instance
        .collection('reviews')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final item = _parseReview(doc.id, doc.reference, data);
        commentMap[doc.reference.path] = item;
      }
      refreshList();
    }, onError: (e) {
      debugPrint("Reviews stream hatası: $e");
    });

    // 3. collection('seller_reviews') -> İkinci El / Sahibinden Satıcı Yorumları
    _subSellerReviews = FirebaseFirestore.instance
        .collection('seller_reviews')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final item = _parseSellerReview(doc.id, doc.reference, data);
        commentMap[doc.reference.path] = item;
      }
      refreshList();
    }, onError: (e) {
      debugPrint("Seller reviews stream hatası: $e");
    });
  }

  // ── Ayrıştırma Fonksiyonları ──
  AdminCommentItem _parseComment(
      String id, DocumentReference ref, Map<String, dynamic> data) {
    final path = ref.path;
    String category = 'other';
    String categoryLabel = 'Genel Yorum';
    Color categoryColor = Colors.grey;
    IconData categoryIcon = Icons.chat_bubble_outline_rounded;
    String targetId = '';

    if (path.contains('group_posts')) {
      category = 'meydan';
      categoryLabel = 'Meydan Gönderisi';
      categoryColor = const Color(0xFFFF5E62);
      categoryIcon = Icons.forum_rounded;
      targetId = ref.parent.parent?.id ?? '';
    } else if (path.contains('businesses')) {
      category = 'business';
      categoryLabel = 'İşletme Rehberi';
      categoryColor = const Color(0xFF0284C7);
      categoryIcon = Icons.storefront_rounded;
      targetId = ref.parent.parent?.id ?? '';
    } else if (path.contains('public_places')) {
      category = 'public';
      categoryLabel = 'Kamu & Gezi';
      categoryColor = const Color(0xFF10B981);
      categoryIcon = Icons.account_balance_rounded;
      targetId = ref.parent.parent?.id ?? '';
    } else if (path.contains('communities')) {
      category = 'community';
      categoryLabel = 'Topluluk & Dernek';
      categoryColor = const Color(0xFF8B5CF6);
      categoryIcon = Icons.groups_rounded;
      targetId = ref.parent.parent?.id ?? '';
    }

    final text = (data['text'] ?? data['comment'] ?? data['content'] ?? '')
        .toString()
        .trim();
    final authorName = (data['authorName'] ??
            data['userName'] ??
            data['name'] ??
            data['fullname'] ??
            'Anonim')
        .toString();
    final authorId =
        (data['authorId'] ?? data['userId'] ?? data['uid'] ?? '').toString();
    final authorAvatar = (data['authorAvatar'] ??
            data['userImage'] ??
            data['userPhoto'] ??
            '')
        .toString();

    DateTime? createdAt;
    final rawDate = data['createdAt'] ?? data['timestamp'] ?? data['date'];
    if (rawDate is Timestamp) {
      createdAt = rawDate.toDate();
    } else if (rawDate is DateTime) {
      createdAt = rawDate;
    } else if (rawDate is String) {
      createdAt = DateTime.tryParse(rawDate);
    }

    double? rating;
    final rawRating = data['rating'] ?? data['puan'];
    if (rawRating is num) {
      rating = rawRating.toDouble();
    }

    final detected = _detectProfanity(text);

    return AdminCommentItem(
      id: id,
      reference: ref,
      text: text,
      authorName: authorName,
      authorId: authorId,
      authorAvatar: authorAvatar,
      createdAt: createdAt,
      rating: rating,
      category: category,
      categoryLabel: categoryLabel,
      categoryColor: categoryColor,
      categoryIcon: categoryIcon,
      targetId: targetId,
      isSuspicious: detected.isNotEmpty,
      detectedWords: detected,
    );
  }

  AdminCommentItem _parseReview(
      String id, DocumentReference ref, Map<String, dynamic> data) {
    final text = (data['comment'] ?? data['review'] ?? data['text'] ?? '')
        .toString()
        .trim();
    final authorName = (data['userName'] ??
            data['customerName'] ??
            data['name'] ??
            data['authorName'] ??
            'Müşteri')
        .toString();
    final authorId =
        (data['userId'] ?? data['customerId'] ?? data['uid'] ?? '').toString();
    final authorAvatar = (data['userImage'] ?? data['avatar'] ?? '').toString();

    DateTime? createdAt;
    final rawDate = data['createdAt'] ?? data['date'];
    if (rawDate is Timestamp) {
      createdAt = rawDate.toDate();
    }

    double? rating;
    final rawRating = data['rating'];
    if (rawRating is num) rating = rawRating.toDouble();

    final targetId = (data['storeName'] ?? data['storeId'] ?? '').toString();
    final detected = _detectProfanity(text);

    return AdminCommentItem(
      id: id,
      reference: ref,
      text: text,
      authorName: authorName,
      authorId: authorId,
      authorAvatar: authorAvatar,
      createdAt: createdAt,
      rating: rating,
      category: 'restaurant',
      categoryLabel: 'Restoran & Yemek',
      categoryColor: const Color(0xFFF97316),
      categoryIcon: Icons.restaurant_rounded,
      targetId: targetId,
      isSuspicious: detected.isNotEmpty,
      detectedWords: detected,
    );
  }

  AdminCommentItem _parseSellerReview(
      String id, DocumentReference ref, Map<String, dynamic> data) {
    final text = (data['comment'] ?? data['text'] ?? data['review'] ?? '')
        .toString()
        .trim();
    final authorName = (data['reviewerName'] ??
            data['userName'] ??
            data['name'] ??
            'Alıcı')
        .toString();
    final authorId = (data['reviewerId'] ?? data['userId'] ?? '').toString();
    final authorAvatar = (data['reviewerAvatar'] ?? '').toString();

    DateTime? createdAt;
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) createdAt = rawDate.toDate();

    double? rating;
    final rawRating = data['rating'];
    if (rawRating is num) rating = rawRating.toDouble();

    final targetId = (data['sellerId'] ?? '').toString();
    final detected = _detectProfanity(text);

    return AdminCommentItem(
      id: id,
      reference: ref,
      text: text,
      authorName: authorName,
      authorId: authorId,
      authorAvatar: authorAvatar,
      createdAt: createdAt,
      rating: rating,
      category: 'classified',
      categoryLabel: 'İkinci El & Satıcı',
      categoryColor: const Color(0xFFF59E0B),
      categoryIcon: Icons.shopping_bag_rounded,
      targetId: targetId,
      isSuspicious: detected.isNotEmpty,
      detectedWords: detected,
    );
  }

  List<String> _detectProfanity(String text) {
    if (text.isEmpty) return [];
    final lower = text.toLowerCase();
    List<String> found = [];
    for (final badWord in _profanityList) {
      if (lower.contains(badWord)) {
        found.add(badWord);
      }
    }
    return found;
  }

  // ── Yorumu Kalıcı Silme ──
  Future<void> _deleteComment(AdminCommentItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text("Yorumu Sil", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bu yorumu kalıcı olarak silmek istediğinize emin misiniz?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.text.isNotEmpty ? item.text : "Boş metin",
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Evet, Sil"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await item.reference.delete();

      // Meydan gönderisi ise yorum sayısını 1 düşür
      if (item.category == 'meydan' && item.targetId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('group_posts')
            .doc(item.targetId)
            .update({'commentCount': FieldValue.increment(-1)})
            .catchError((_) {});
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yorum kalıcı olarak silindi 🗑️"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Yorum silinemedi: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Kullanıcıyı Sil / İncele ──
  Future<void> _deleteUser(String userId, String userName) async {
    if (userId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Kullanıcı Kaydını Sil"),
        content: Text(
          "'$userName' isimli kullanıcının profil kaydını tamamen silmek istediğinize emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Kullanıcıyı Sil"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(userId)
            .delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kullanıcı kaydı silindi ❌"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Kullanıcı silinemedi: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Arama ve Filtreleme ──
  List<AdminCommentItem> _getFilteredComments() {
    final query = _searchController.text.trim().toLowerCase();

    return _allComments.where((item) {
      // Şüpheli butonu aktifse sadece şüphelileri göster
      if (_onlySuspicious && !item.isSuspicious) return false;

      // Kategori filtresi
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'suspicious' && !item.isSuspicious) return false;
        if (_selectedFilter != 'suspicious' && item.category != _selectedFilter) {
          return false;
        }
      }

      // Metin araması
      if (query.isNotEmpty) {
        final matchText = item.text.toLowerCase().contains(query);
        final matchAuthor = item.authorName.toLowerCase().contains(query);
        final matchAuthorId = item.authorId.toLowerCase().contains(query);
        final matchCategory = item.categoryLabel.toLowerCase().contains(query);
        if (!matchText && !matchAuthor && !matchAuthorId && !matchCategory) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _getFilteredComments();
    final suspiciousCount = _allComments.where((c) => c.isSuspicious).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141F) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tüm Yorumlar & Denetim",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              "${_allComments.length} Yorum • $suspiciousCount Şüpheli/Argo",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF161E2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          // Şüpheli Yorum Radar Butonu
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              avatar: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: _onlySuspicious ? Colors.white : Colors.red,
              ),
              label: Text(
                "Argo Radarı ($suspiciousCount)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _onlySuspicious ? Colors.white : Colors.red,
                ),
              ),
              selected: _onlySuspicious,
              selectedColor: Colors.red,
              backgroundColor: Colors.red.withOpacity(0.1),
              onSelected: (val) => setState(() => _onlySuspicious = val),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama & Filtreleme Üst Çubuğu
          _buildSearchAndFilters(isDark, suspiciousCount),

          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : filtered.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildCommentCard(filtered[index], isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark, int suspiciousCount) {
    return Container(
      color: isDark ? const Color(0xFF161E2E) : Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        children: [
          // Arama Kutusu
          TextField(
            controller: _searchController,
            style: TextStyle(
                fontSize: 14, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Yorumlarda, yazarda veya kullanıcı ID'sinde ara...",
              hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                  fontSize: 13),
              prefixIcon: const Icon(CupertinoIcons.search, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF0F141F) : const Color(0xFFF1F5F9),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Kategori Filtre Hapları (Yatay Kaydırma)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCategoryPill(
                  id: 'all',
                  label: "Tümü (${_allComments.length})",
                  icon: Icons.all_inclusive_rounded,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  id: 'meydan',
                  label: "Meydan",
                  icon: Icons.forum_rounded,
                  color: const Color(0xFFFF5E62),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  id: 'business',
                  label: "İşletmeler",
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  id: 'restaurant',
                  label: "Restoran & Yemek",
                  icon: Icons.restaurant_rounded,
                  color: const Color(0xFFF97316),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  id: 'classified',
                  label: "İkinci El / Satıcı",
                  icon: Icons.shopping_bag_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  id: 'public',
                  label: "Kamu & Gezi",
                  icon: Icons.account_balance_rounded,
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String id,
    required String label,
    required IconData icon,
    Color? color,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == id;
    final pillColor = color ?? const Color(0xFF6366F1);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? pillColor
              : (isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Yorum Kartı ──
  Widget _buildCommentCard(AdminCommentItem item, bool isDark) {
    String dateStr = "";
    if (item.createdAt != null) {
      dateStr = DateFormat("d MMM yyyy, HH:mm", "tr_TR").format(item.createdAt!);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isSuspicious
              ? Colors.red.withOpacity(0.6)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
          width: item.isSuspicious ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: item.isSuspicious
                ? Colors.red.withOpacity(0.08)
                : Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Bölüm: Kategori Rozeti + Tarih + Sil Butonu
            Row(
              children: [
                // Kategori Rozeti
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.categoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.categoryIcon, size: 12, color: item.categoryColor),
                      const SizedBox(width: 4),
                      Text(
                        item.categoryLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.categoryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Puan (Eğer varsa)
                if (item.rating != null && item.rating! > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          item.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Spacer(),

                // Tarih
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),

                const SizedBox(width: 6),

                // Yorumu Sil Butonu
                IconButton(
                  icon: const Icon(CupertinoIcons.trash, color: Colors.red, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: "Yorumu Sil",
                  onPressed: () => _deleteComment(item),
                ),
              ],
            ),

            // Şüpheli / Argo Uyarısı
            if (item.isSuspicious) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Olası Argo / Küfür Algılandı: ${item.detectedWords.join(', ')}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Yorum Metni
            SelectableText(
              item.text.isNotEmpty ? item.text : "(Metin bulunamadı)",
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.grey.shade100,
            ),
            const SizedBox(height: 10),

            // Alt Bilgi: Yazar + Kullanıcı ID + Üyeliği Sil
            Row(
              children: [
                // Yazar Avatarı
                CircleAvatar(
                  radius: 14,
                  backgroundColor: item.categoryColor.withOpacity(0.2),
                  backgroundImage: item.authorAvatar.isNotEmpty
                      ? NetworkImage(item.authorAvatar)
                      : null,
                  child: item.authorAvatar.isEmpty
                      ? Text(
                          item.authorName.isNotEmpty
                              ? item.authorName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: item.categoryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),

                // Yazar Adı & ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.authorName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.authorId.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: item.authorId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Kullanıcı ID kopyalandı 📋"),
                                duration: Duration(milliseconds: 900),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Text(
                            "ID: ${item.authorId.length > 12 ? item.authorId.substring(0, 12) : item.authorId}...",
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Kullanıcıyı Sil / Ceza Butonu
                if (item.authorId.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.red.shade400,
                    ),
                    icon: const Icon(Icons.person_remove_rounded, size: 14),
                    label: const Text(
                      "Kullanıcıyı Sil",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _deleteUser(item.authorId, item.authorName),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _onlySuspicious
                ? Icons.verified_user_rounded
                : CupertinoIcons.chat_bubble_2,
            size: 56,
            color: _onlySuspicious ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            _onlySuspicious
                ? "Harika! Hiç şüpheli veya argo yorum bulunamadı."
                : "Filtrelere uygun yorum bulunamadı.",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _onlySuspicious
                ? "Tüm topluluk yorumları temiz görünüyor."
                : "Arama teriminizi veya kategori filtresini değiştirin.",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
