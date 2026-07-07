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
    int index = _cartItems.indexWhere((item) =>
        item.prodId == cart.prodId &&
        _sameOptions(item.removedIngredients, cart.removedIngredients) &&
        _sameOptions(item.addedIngredients, cart.addedIngredients));

    if (index != -1) {
      // Varsa miktarını artır
      _cartItems[index].quantity += cart.quantity;
      _cartItems[index].totalPrice += cart.totalPrice;
    } else {
      final lineId = _lineIdFor(cart);
      // Yoksa yeni ekle. Satır ID'si özellikle ekstralarda çakışmamalı.
      _cartItems.add(CartItem(
        id: lineId,
        userId: cart.userId,
        docId: cart.docId,
        prodId: cart.prodId,
        sellerId: cart.sellerId,
        prodName: cart.prodName,
        prodPrice: cart.prodPrice,
        prodImgUrl: cart.prodImgUrl,
        isMonthlyDeal: cart.isMonthlyDeal,
        removedIngredients: cart.removedIngredients,
        addedIngredients: cart.addedIngredients,
        estimatedCalories: cart.estimatedCalories,
        quantity: cart.quantity,
        totalPrice: cart.totalPrice,
      ));
    }

    _saveCartToPrefs();
    notifyListeners();
  }

  String _lineIdFor(CartItem cart) {
    final suppliedId = cart.id.trim();
    if (suppliedId.startsWith('extra_')) return suppliedId;

    final optionParts = <String>[
      ...cart.removedIngredients.map((item) => 'remove:$item'),
      ...cart.addedIngredients.map((item) => 'add:$item'),
    ]..sort();

    final baseId = optionParts.isEmpty
        ? cart.prodId
        : '${cart.prodId}_${optionParts.join('|')}';

    if (_cartItems.every((item) => item.id != baseId)) return baseId;

    return '${baseId}_${DateTime.now().microsecondsSinceEpoch}';
  }

  bool _sameOptions(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    final sortedLeft = [...left]..sort();
    final sortedRight = [...right]..sort();
    for (var index = 0; index < sortedLeft.length; index++) {
      if (sortedLeft[index] != sortedRight[index]) return false;
    }
    return true;
  }

  int _indexByLineOrProduct(String id) {
    final lineIndex = _cartItems.indexWhere((element) => element.id == id);
    if (lineIndex != -1) return lineIndex;
    return _cartItems.indexWhere((element) => element.prodId == id);
  }

  void removeFromCart(String id) {
    final lineIndex = _cartItems.indexWhere((item) => item.id == id);
    final productIndex = _cartItems.indexWhere((item) => item.prodId == id);
    final index = lineIndex != -1 ? lineIndex : productIndex;
    if (index == -1) return;
    _cartItems.removeAt(index);
    _saveCartToPrefs();
    notifyListeners();
  }

  void removeLineAt(int index) {
    if (index < 0 || index >= _cartItems.length) return;
    _cartItems.removeAt(index);
    _saveCartToPrefs();
    notifyListeners();
  }

  void incrementLineAt(int index) {
    if (index < 0 || index >= _cartItems.length) return;
    _cartItems[index].quantity++;
    _cartItems[index].totalPrice += _cartItems[index].prodPrice;
    _saveCartToPrefs();
    notifyListeners();
  }

  void decrementLineAt(int index) {
    if (index < 0 || index >= _cartItems.length) return;
    if (_cartItems[index].quantity > 1) {
      _cartItems[index].quantity--;
      _cartItems[index].totalPrice -= _cartItems[index].prodPrice;
    } else {
      _cartItems.removeAt(index);
    }
    _saveCartToPrefs();
    notifyListeners();
  }

  void incrementProductQuantity(String id) {
    final index = _indexByLineOrProduct(id);
    if (index != -1) {
      _cartItems[index].quantity++;
      _cartItems[index].totalPrice += _cartItems[index].prodPrice;
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  void decrementProductQuantity(String id) {
    final index = _indexByLineOrProduct(id);
    if (index != -1 && _cartItems[index].quantity > 1) {
      _cartItems[index].quantity--;
      _cartItems[index].totalPrice -= _cartItems[index].prodPrice;
      _saveCartToPrefs();
      notifyListeners();
    } else if (index != -1 && _cartItems[index].quantity == 1) {
      // Miktar 1 iken azaltılırsa ürünü sepetten çıkar (Modern UX)
      removeFromCart(id);
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
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  List<CartItem> get cartItems => [..._cartItems];
}
