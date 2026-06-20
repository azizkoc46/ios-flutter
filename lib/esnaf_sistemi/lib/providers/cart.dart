import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pazarcik_portal/esnaf_sistemi/lib/models/cart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartData extends ChangeNotifier {
  List<CartItem> _cartItems = <CartItem>[];

  // Hafıza anahtarı - Tutarlılık için sabit tanımlandı
  static const String _storageKey = 'pazarcik_user_cart';

  CartData() {
    _loadCartFromPrefs();
  }

  // --- HAFIZA İŞLEMLERİ (Persistence) ---

  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = json.encode(
        _cartItems.map((item) => item.toJson()).toList(),
      );
      await prefs.setString(_storageKey, encodedData);
    } catch (e) {
      debugPrint("Sepet kaydetme hatası: $e");
    }
  }

  Future<void> _loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_storageKey)) return;

      final String? encodedData = prefs.getString(_storageKey);
      if (encodedData != null && encodedData.isNotEmpty) {
        final List<dynamic> decodedData = json.decode(encodedData);
        _cartItems =
            decodedData.map((item) => CartItem.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Sepet yükleme hatası: $e");
      // Veri bozuksa sepeti temizle ki uygulama çökmesin
      _cartItems = [];
    }
  }

  // --- SEPET AKSİYONLARI ---

  void addToCart(CartItem cart) {
    // Ürün zaten sepette var mı kontrol et
    int index = _cartItems.indexWhere((item) => item.prodId == cart.prodId);

    if (index != -1) {
      // Varsa miktarını artır
      _cartItems[index].quantity += cart.quantity;
      _cartItems[index].totalPrice =
          _cartItems[index].prodPrice * _cartItems[index].quantity;
    } else {
      // Yoksa yeni ekle (ID olarak benzersiz timestamp atıyoruz)
      _cartItems.add(CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: cart.userId,
        docId: cart.docId,
        prodId: cart.prodId,
        sellerId: cart.sellerId,
        prodName: cart.prodName,
        prodPrice: cart.prodPrice,
        prodImgUrl: cart.prodImgUrl,
        isMonthlyDeal: cart.isMonthlyDeal,
        quantity: cart.quantity,
        totalPrice: cart.prodPrice * cart.quantity,
      ));
    }

    _saveCartToPrefs();
    notifyListeners();
  }

  void removeFromCart(String prodId) {
    _cartItems.removeWhere((item) => item.prodId == prodId);
    _saveCartToPrefs();
    notifyListeners();
  }

  void incrementProductQuantity(String productId) {
    final index =
        _cartItems.indexWhere((element) => element.prodId == productId);
    if (index != -1) {
      _cartItems[index].quantity++;
      _cartItems[index].totalPrice =
          _cartItems[index].prodPrice * _cartItems[index].quantity;
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  void decrementProductQuantity(String productId) {
    final index =
        _cartItems.indexWhere((element) => element.prodId == productId);
    if (index != -1 && _cartItems[index].quantity > 1) {
      _cartItems[index].quantity--;
      _cartItems[index].totalPrice =
          _cartItems[index].prodPrice * _cartItems[index].quantity;
      _saveCartToPrefs();
      notifyListeners();
    } else if (index != -1 && _cartItems[index].quantity == 1) {
      // Miktar 1 iken azaltılırsa ürünü sepetten çıkar (Modern UX)
      removeFromCart(productId);
    }
  }

  void clearCart() {
    _cartItems.clear();
    _saveCartToPrefs();
    notifyListeners();
  }

  // --- GETTERLAR (Bilgi Çekme) ---

  bool isItemOnCart(String prodId) =>
      _cartItems.any((item) => item.prodId == prodId);

  int get cartItemCount => _cartItems.length;

  // Sepetteki toplam ürün adedi (Örn: 2 elma + 3 armut = 5 ürün)
  int get totalQuantity {
    return _cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  double get cartTotalPrice {
    return _cartItems.fold(
        0.0, (sum, item) => sum + (item.prodPrice * item.quantity));
  }

  List<CartItem> get cartItems => [..._cartItems];
}
