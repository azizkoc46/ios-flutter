import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class InteractivePollDialog extends StatelessWidget {
  final String question;
  final List<String> options;
  final String pollId;
  final String collectionName; // 'app_notifications' veya 'group_posts'

  const InteractivePollDialog({
    Key? key,
    required this.question,
    required this.options,
    required this.pollId,
    this.collectionName = 'app_notifications',
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required String question,
    required List<String> options,
    required String pollId,
    String collectionName = 'app_notifications',
  }) {
    showDialog(
      context: context,
      builder: (ctx) => InteractivePollDialog(
        question: question,
        options: options,
        pollId: pollId,
        collectionName: collectionName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final votesStream = FirebaseFirestore.instance
        .collection(collectionName)
        .doc(pollId)
        .collection('votes')
        .snapshots();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık & İkon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.poll_rounded,
                      color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Kamuoyu Anketi",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        question,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Oylar ve Seçenekler (Canlı Dinleme)
            StreamBuilder<QuerySnapshot>(
              stream: votesStream,
              builder: (context, snapshot) {
                final voteDocs = snapshot.data?.docs ?? [];
                final totalVotes = voteDocs.length;

                // Kullanıcının daha önce oy kullanıp kullanmadığını kontrol et
                String? userChoice;
                final Map<String, int> voteCounts = {};
                for (final opt in options) {
                  voteCounts[opt] = 0;
                }

                for (final doc in voteDocs) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final choice = (data['choice'] ?? '').toString();
                  final uid = (data['uid'] ?? doc.id).toString();

                  if (voteCounts.containsKey(choice)) {
                    voteCounts[choice] = (voteCounts[choice] ?? 0) + 1;
                  }

                  if (uid == currentUserId && currentUserId.isNotEmpty) {
                    userChoice = choice;
                  }
                }

                final bool hasVoted = userChoice != null;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...options.map((opt) {
                      final count = voteCounts[opt] ?? 0;
                      final percentage =
                          totalVotes > 0 ? (count / totalVotes) : 0.0;
                      final isSelected = userChoice == opt;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: hasVoted
                                ? null
                                : () async {
                                    if (currentUserId.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              "Oy kullanmak için giriş yapmalısınız."),
                                        ),
                                      );
                                      return;
                                    }

                                    // TEK SEFER OY KULLANMA: doc(currentUserId) olarak kaydedilir
                                    await FirebaseFirestore.instance
                                        .collection(collectionName)
                                        .doc(pollId)
                                        .collection('votes')
                                        .doc(currentUserId)
                                        .set({
                                      'uid': currentUserId,
                                      'choice': opt,
                                      'date': FieldValue.serverTimestamp(),
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 50,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.orange
                                      : Colors.transparent,
                                  width: 1.8,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Canlı Yüzde Çubuğu
                                  if (hasVoted && percentage > 0)
                                    FractionallySizedBox(
                                      widthFactor: percentage,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.orange.withOpacity(0.35)
                                              : (isDark
                                                  ? Colors.white12
                                                  : Colors.black12),
                                          borderRadius:
                                              BorderRadius.circular(13),
                                        ),
                                      ),
                                    ),

                                  // Seçenek Metni ve Yüzdesi
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                if (isSelected) ...[
                                                  const Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.orange,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    opt,
                                                    style: TextStyle(
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.w600,
                                                      fontSize: 14,
                                                      color: isSelected
                                                          ? Colors.orange
                                                          : (isDark
                                                              ? Colors.white
                                                              : Colors
                                                                  .black87),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (hasVoted)
                                            Text(
                                              "%${(percentage * 100).toStringAsFixed(0)} ($count)",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.orange
                                                    : Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 10),

                    // Alt Bilgilendirme
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$totalVotes kişi oy kullandı",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        if (hasVoted)
                          const Row(
                            children: [
                              Icon(Icons.lock_outline,
                                  size: 12, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                "Oyunuz kaydedildi",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            // Kapat Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Kapat",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
