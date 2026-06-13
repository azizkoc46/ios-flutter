class BusinessModel {
  String? id;
  String businessName;
  String category;
  String contact;
  String description;
  String editorId;
  List<String> imageUrls;
  double rating;
  List<String> regions;
  int reviewCount;
  Map<String, String> socialMedia;
  String status;

  BusinessModel({
    this.id,
    required this.businessName,
    required this.category,
    required this.contact,
    required this.description,
    required this.editorId,
    required this.imageUrls,
    required this.rating,
    required this.regions,
    required this.reviewCount,
    required this.socialMedia,
    required this.status,
  });

  // Firebase'den veri okumak için
  factory BusinessModel.fromMap(Map<String, dynamic> map, String docId) {
    return BusinessModel(
      id: docId,
      businessName: map['businessName'] ?? '',
      category: map['category'] ?? '',
      contact: map['contact'] ?? '',
      description: map['description'] ?? '',
      editorId: map['editorId'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      rating: (map['rating'] ?? 0.0).toDouble(),
      regions: List<String>.from(map['regions'] ?? []),
      reviewCount: map['reviewCount'] ?? 0,
      socialMedia: Map<String, String>.from(map['socialMedia'] ?? {}),
      status: map['status'] ?? 'pending',
    );
  }

  // Firebase'e veri göndermek için
  Map<String, dynamic> toMap() {
    return {
      'businessName': businessName,
      'category': category,
      'contact': contact,
      'description': description,
      'editorId': editorId,
      'imageUrls': imageUrls,
      'rating': rating,
      'regions': regions,
      'reviewCount': reviewCount,
      'socialMedia': socialMedia,
      'status': status,
    };
  }
}
