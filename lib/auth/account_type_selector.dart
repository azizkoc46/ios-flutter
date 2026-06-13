import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pazarcik_portal/auth/auth.dart';
import 'package:pazarcik_portal/core/constants.dart';

class AccountTypeSelector extends StatefulWidget {
  static const routeName = '/account-type-selector';

  const AccountTypeSelector({Key? key}) : super(key: key);

  @override
  State<AccountTypeSelector> createState() => _AccountTypeSelectorState();
}

class _AccountTypeSelectorState extends State<AccountTypeSelector> {
  var typeIndex = 0;
  var accountType = ['Vatandaş Hesabı', 'Esnaf Hesabı'];

  Widget kContainer(int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          typeIndex = index;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: typeIndex == index
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              width: 2,
              color: typeIndex == index ? Colors.white : Colors.white24,
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 8.0),
            child: Column(
              children: [
                Icon(
                  index == 0
                      ? Icons.person_pin_rounded
                      : Icons.store_mall_directory_rounded,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 10),
                Text(
                  accountType[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _navigateToSection() {
    // 🔥 HATA BURADAYDI: isSellerReg parametresini sildik.
    // Artık sadece Auth() sayfasına gidiyor.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const Auth(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Pazarcık Portal",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Lütfen hesap türünüzü seçerek devam edin",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      kContainer(0),
                      const SizedBox(width: 20),
                      kContainer(1),
                    ],
                  ),
                  const SizedBox(height: 60),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                      onPressed: () => _navigateToSection(),
                      child: const Text(
                        'Devam Et',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
