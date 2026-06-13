// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class BildirimKutusuAnaSayfa extends StatefulWidget {
  const BildirimKutusuAnaSayfa({super.key});

  @override
  State<BildirimKutusuAnaSayfa> createState() => _BildirimKutusuAnaSayfaState();
}

class _BildirimKutusuAnaSayfaState extends State<BildirimKutusuAnaSayfa> {
  List<Map<String, dynamic>> allNotifications = [];
  List<Map<String, dynamic>> adminList = [];
  List<Map<String, dynamic>> personalList = [];

  bool isLoading = true;
  StreamSubscription? adminSub;
  StreamSubscription? userSub;

  @override
  void initState() {
    super.initState();
    _fetchLiveNotifications();
  }

  @override
  void dispose() {
    adminSub?.cancel();
    userSub?.cancel();
    super.dispose();
  }

  void _fetchLiveNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    adminSub = FirebaseFirestore.instance
        .collection('app_notifications')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      adminList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        data['isGlobal'] = true;
        return data;
      }).toList();

      _mergeAndSort();
    });

    if (uid != null) {
      userSub = FirebaseFirestore.instance
          .collection('notifications')
          .where('to', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
        personalList = snapshot.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          data['isGlobal'] = false;
          return data;
        }).toList();

        _mergeAndSort();
      });
    }
  }

  void _mergeAndSort() {
    final combined = [...adminList, ...personalList];

    combined.sort((a, b) {
      final Timestamp t1 = a['createdAt'] ?? a['time'] ?? Timestamp.now();
      final Timestamp t2 = b['createdAt'] ?? b['time'] ?? Timestamp.now();
      return t2.compareTo(t1);
    });

    if (!mounted) return;

    setState(() {
      allNotifications = combined;
      isLoading = false;
    });
  }

  Future<void> _handleTap(Map<String, dynamic> notif) async {
    if (notif['isGlobal'] == false && notif['isRead'] == false) {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notif['docId'])
          .update({'isRead': true});
    }

    if (notif['isGlobal'] == true) {
      await _markGlobalNotificationAsRead(notif['docId']);
    }

    if (!mounted) return;
    _showNotificationDetail(notif);
  }

  Future<void> _markGlobalNotificationAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('app_notifications')
        .doc(notificationId)
        .collection('reads')
        .doc(user.uid)
        .set({
      'uid': user.uid,
      'userName': user.displayName ?? user.email ?? 'Kullanıcı',
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showNotificationDetail(Map<String, dynamic> notif) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String title = notif['title'] ?? 'Yeni Bildirim';
    final String body = notif['body'] ?? notif['message'] ?? '';
    final String type = notif['type'] ?? '';
    final Timestamp? time = notif['createdAt'] ?? notif['time'];

    final String imageUrl = (notif['imageUrl'] ??
            notif['image'] ??
            notif['photoUrl'] ??
            notif['thumbnail'] ??
            '')
        .toString();

    IconData icon = Icons.notifications;
    Color color = Colors.blue;

    if (type == 'Anket') {
      icon = Icons.poll_outlined;
      color = Colors.orange;
    } else if (type == 'Link') {
      icon = CupertinoIcons.link;
      color = Colors.purple;
    } else if (type == 'order' || type == 'order_update') {
      icon = CupertinoIcons.cube_box;
      color = Colors.green;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(time),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (imageUrl.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _showFullScreenImage(imageUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: 210,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 210,
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFF1F5F9),
                            child: const Center(
                              child: CupertinoActivityIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 210,
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    body.isEmpty ? "Bildirim içeriği bulunamadı." : body,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if ((notif['linkUrl'] ?? '').toString().isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(notif['linkUrl']);
                          Navigator.pop(context);

                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(CupertinoIcons.link),
                        label: const Text("Bağlantıyı Aç"),
                      ),
                    ),
                  if (type == 'Anket')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          final options =
                              List<String>.from(notif['pollOptions'] ?? []);
                          _showInteractivePoll(title, options, notif['docId']);
                        },
                        icon: const Icon(Icons.poll_outlined),
                        label: const Text("Ankete Katıl"),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) =>
                        const CupertinoActivityIndicator(
                      color: Colors.white,
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markAllAsRead() async {
    for (final notif in personalList) {
      if (notif['isRead'] == false) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notif['docId'])
            .update({'isRead': true});
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Tüm bildirimler okundu olarak işaretlendi."),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showInteractivePoll(
    String question,
    List<String> options,
    String pollId,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(
          "Yeni Anket",
          style: TextStyle(color: Colors.orange),
        ),
        content: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              question,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            ...options.map(
              (opt) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: CupertinoButton(
                  color: Colors.orange.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 15,
                  ),
                  child: Text(
                    opt,
                    style: const TextStyle(color: Colors.orange),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);

                    final user = FirebaseAuth.instance.currentUser;

                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('app_notifications')
                          .doc(pollId)
                          .collection('votes')
                          .add({
                        'uid': user.uid,
                        'choice': opt,
                        'date': FieldValue.serverTimestamp(),
                      });

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Oyunuz başarıyla kaydedildi."),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text(
              "Kapat",
              style: TextStyle(color: Colors.grey),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp? time) {
    if (time == null) return "Şimdi";
    return DateFormat('dd MMM HH:mm', 'tr_TR').format(time.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Bildirim Merkezi",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              "Tümünü Oku",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xfff27a1a),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CupertinoActivityIndicator(radius: 15))
          : allNotifications.isEmpty
              ? const Center(
                  child: Text(
                    "Henüz bir bildiriminiz yok.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: allNotifications.length,
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final notif = allNotifications[index];

                    final bool isGlobal = notif['isGlobal'];
                    final bool isRead =
                        isGlobal ? true : (notif['isRead'] ?? false);
                    final String type = notif['type'] ?? '';
                    final String title = notif['title'] ?? 'Yeni Bildirim';
                    final String body = notif['body'] ?? notif['message'] ?? '';
                    final Timestamp? time = notif['createdAt'] ?? notif['time'];

                    final String imageUrl = (notif['imageUrl'] ??
                            notif['image'] ??
                            notif['photoUrl'] ??
                            notif['thumbnail'] ??
                            '')
                        .toString();

                    IconData icon = Icons.notifications;
                    Color color = Colors.blue;

                    if (type == 'Anket') {
                      icon = Icons.poll_outlined;
                      color = Colors.orange;
                    } else if (type == 'Link') {
                      icon = CupertinoIcons.link;
                      color = Colors.purple;
                    } else if (type == 'order' || type == 'order_update') {
                      icon = CupertinoIcons.cube_box;
                      color = Colors.green;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () => _handleTap(notif),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isRead
                                ? Theme.of(context).cardColor
                                : color.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isRead
                                  ? Colors.transparent
                                  : color.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: color.withOpacity(0.1),
                                  child: Icon(icon, color: color),
                                ),
                                if (imageUrl.isNotEmpty)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E1E1E)
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.photo_fill,
                                        size: 12,
                                        color: color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTime(time),
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
