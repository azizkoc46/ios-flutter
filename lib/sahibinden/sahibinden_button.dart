// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SahibindenMagicBottomBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const SahibindenMagicBottomBar({
    Key? key,
    required this.selectedIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color sahibindenYellow = Color(0xFFFFE800);
    const Color sahibindenDark = Color(0xFF1C1C1E); // iOS Koyu Gri/Siyah

    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // --- Arka Plan Bulanıklığı (Glassmorphism) ---
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  border: Border(
                      top: BorderSide(color: Colors.black.withOpacity(0.05))),
                ),
              ),
            ),
          ),

          // --- Butonlar Dizilimi ---
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(0, CupertinoIcons.square_grid_2x2_fill, "Vitrin",
                    selectedIndex == 0, onTap),
                _buildTabItem(1, CupertinoIcons.chart_bar_alt_fill, "Yönetim",
                    selectedIndex == 1, onTap),

                // --- Ortadaki "Pazarcık Portal" Magic Buton ---
                _buildCenterPortalButton(
                    context, sahibindenYellow, sahibindenDark),

                _buildTabItem(3, CupertinoIcons.add_circled_solid, "İlan Ver",
                    selectedIndex == 3, onTap),

                // 🔥 PROFİL BUTONU: sprofil.dart içindeki SahibindenProfileView'u açar
                _buildTabItem(4, CupertinoIcons.person_crop_circle_fill,
                    "Profil", selectedIndex == 4, onTap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Normal Sekme Tasarımı ---
  Widget _buildTabItem(int index, IconData icon, String label, bool isActive,
      Function(int) callback) {
    return GestureDetector(
      onTap: () => callback(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? const Color(0xFF1C1C1E)
                  : Colors.grey.withOpacity(0.6),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF1C1C1E)
                    : Colors.grey.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Ortadaki Özel Portal Butonu ---
  Widget _buildCenterPortalButton(
      BuildContext context, Color yellow, Color dark) {
    return GestureDetector(
      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      child: Container(
        transform:
            Matrix4.translationValues(0, -15, 0), // Yukarı taşır (Magic efekt)
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: dark.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: yellow, width: 2),
        ),
        child: Icon(
          CupertinoIcons.house_fill,
          color: yellow,
          size: 30,
        ),
      ),
    );
  }
}
