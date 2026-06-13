// ignore_for_file: deprecated_member_use

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';
import 'story_viewer_page.dart';

class HomeHeaderSection extends StatelessWidget {
  final bool isDark;
  final Widget? weatherWidget;
  final Widget namazWidget;
  final VoidCallback onNotificationTap;
  final int unreadNotificationCount;

  const HomeHeaderSection({
    Key? key,
    required this.isDark,
    this.weatherWidget,
    required this.namazWidget,
    required this.onNotificationTap,
    this.unreadNotificationCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHero(context),
          const SizedBox(height: 18),
          _buildStoriesSection(),
          const SizedBox(height: 18),
          _buildPrayerCardWrapper(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTopHero(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF172554),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFE0F2FE),
                  const Color(0xFFFFFFFF),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.22)
                : const Color(0xFF0284C7).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hoş Geldin Pazarcıklı",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Pazarcık Portal",
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (weatherWidget != null) ...[
                SizedBox(
                  height: 46,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: weatherWidget!,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: onNotificationTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.white.withOpacity(0.92),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.bell_fill,
                        size: 20,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    if (unreadNotificationCount > 0)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              unreadNotificationCount > 99
                                  ? "99+"
                                  : unreadNotificationCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Öne Çıkanlar",
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('story_categories')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildStoryMessage("Hikayeler yüklenemedi");
              }

              if (!snapshot.hasData) {
                return const Center(child: CupertinoActivityIndicator());
              }

              final storyDocs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final items = data['items'] as List?;
                return items != null && items.isNotEmpty;
              }).toList();

              if (storyDocs.isEmpty) {
                return _buildStoryMessage("Henüz öne çıkan içerik yok");
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: storyDocs.length,
                itemBuilder: (context, index) {
                  final data = storyDocs[index].data() as Map<String, dynamic>;

                  final allCategories = storyDocs
                      .map((e) => e.data() as Map<String, dynamic>)
                      .toList();

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryViewerPage(
                            allCategories: allCategories,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: _buildStoryCircle(
                      title: data['title'] ?? "",
                      coverImageUrl: data['coverImage'] ?? "",
                      isDark: isDark,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerCardWrapper() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.03),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFFE0F2FE),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.26)
                  : const Color(0xFF0369A1).withOpacity(0.12),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: namazWidget,
        ),
      ),
    );
  }

  Widget _buildStoryMessage(String text) {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }

  Widget _buildStoryCircle({
    required String title,
    required String coverImageUrl,
    required bool isDark,
  }) {
    return SizedBox(
      width: 82,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xFF7C3AED),
                    Color(0xFFEC4899),
                    Color(0xFFF97316),
                    Color(0xFFFACC15),
                    Color(0xFF7C3AED),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Container(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : const Color(0xFFF1F5F9),
                    child: coverImageUrl.isNotEmpty
                        ? PortalNetworkImage(
                            url: coverImageUrl,
                            fit: BoxFit.cover,
                            placeholder: const Center(
                              child: CupertinoActivityIndicator(radius: 9),
                            ),
                            errorWidget: Icon(
                              Icons.image_outlined,
                              color: isDark ? Colors.white38 : Colors.black26,
                            ),
                          )
                        : Icon(
                            Icons.image_outlined,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
