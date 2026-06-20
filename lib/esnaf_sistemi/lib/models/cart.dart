class CartItem {
  final String id;
  final dynamic docId;
  final String sellerId;
  final String userId;
  final String prodId;
  final String prodName;
  final String prodImgUrl;
  final double prodPrice;
  final bool isMonthlyDeal;
  double totalPrice;
  int quantity;

  CartItem({
    required this.id,
    required this.docId,
    required this.sellerId,
    required this.userId,
    required this.prodId,
    required this.prodName,
    required this.prodPrice,
    required this.prodImgUrl,
    this.isMonthlyDeal = false,
    this.quantity = 1,
    required this.totalPrice,
  });

  // 🔥 Miktarı Artır
  void incrementQuantity() {
    quantity += 1;
    totalPrice = prodPrice * quantity;
  }

  // 🔥 Miktarı Azalt (1'den aşağı düşmesini engeller)
  void decrementQuantity() {
    if (quantity > 1) {
      quantity -= 1;
      totalPrice = prodPrice * quantity;
    }
  }

  // 🔥 JSON Formatına Dönüştür (Shared Preferences / Yerel Hafıza İçin)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'docId': docId,
      'sellerId': sellerId,
      'userId': userId,
      'prodId': prodId,
      'prodName': prodName,
      'prodImgUrl': prodImgUrl,
      'prodPrice': prodPrice,
      'isMonthlyDeal': isMonthlyDeal,
      'totalPrice': totalPrice,
      'quantity': quantity,
    };
  }

  // 🔥 JSON'dan Objeye Dönüştür (Shared Preferences / Yerel Hafıza İçin)
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? '',
      docId: json['docId'] ?? '',
      sellerId: json['sellerId'] ?? '',
      userId: json['userId'] ?? '',
      prodId: json['prodId'] ?? '',
      prodName: json['prodName'] ?? '',
      prodPrice: (json['prodPrice'] ?? 0).toDouble(),
      prodImgUrl: json['prodImgUrl'] ?? '',
      isMonthlyDeal: json['isMonthlyDeal'] == true,
      quantity: json['quantity'] ?? 1,
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
    );
  }

  // 🔥 Firestore'a Sipariş Gönderirken Lazım Olacak (Map'e Dönüştür)
  // Not: JSON metodlarıyla aynı işi yapar ama isim standardı için tutuyoruz.
  Map<String, dynamic> toMap() => toJson();

  // 🔥 Firestore'dan Veri Okurken Lazım Olacak (Objeye Dönüştür)
  factory CartItem.fromMap(Map<String, dynamic> map) => CartItem.fromJson(map);
}
