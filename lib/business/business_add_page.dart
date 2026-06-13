import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:pazarcik_portal/dernek_sistemi/services/FirebaseStorage_service.dart';
import 'package:pazarcik_portal/admin/admin_notification_service.dart';
import 'package:pazarcik_portal/utils/portal_file_upload.dart';
import 'package:pazarcik_portal/widgets/portal_network_image.dart';

class BusinessAddPage extends StatefulWidget {
  final Map<String, dynamic>? existingBusiness;
  final String? docId;
  final bool isPublic;

  const BusinessAddPage(
      {Key? key, this.existingBusiness, this.docId, this.isPublic = false})
      : super(key: key);

  @override
  State<BusinessAddPage> createState() => _BusinessAddPageState();
}

class _BusinessAddPageState extends State<BusinessAddPage> {
  final Color primaryColor = const Color(0xFF004D40);
  final Color publicColor = const Color(0xFFD32F2F);

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _phoneController;
  late TextEditingController _updateNoteController;
  late TextEditingController _tagController;
  late TextEditingController _webController;
  late TextEditingController _instaController;
  late TextEditingController _faceController;
  late TextEditingController _mapLinkController;
  late TextEditingController _addressDescController;

  File? _selectedImage;
  String? _existingImageUrl;
  bool _isLoading = false;

  String? _selectedMainCategory;
  String? _selectedSubCategory;
  List<String> _selectedRegions = [];
  List<String> _tags = [];

  // 🔥 YENİ EKLENEN: Galeri Değişkenleri
  List<File> _newGalleryImages = [];
  List<String> _existingGalleryUrls = [];
  final int _maxGalleryImages = 5;

  final List<Map<String, dynamic>> categories = [
    // ... Kategorilerin senin verdiğin şekilde aynı (Uzamasın diye burada kısalttım, kendi listeni buraya koyarsın)
    {
      "name": "Restoran & Kafe",
      "sub": [
        "Restoran",
        "Kafe",
        "Fast Food",
        "Dönerci",
        "Kebapçı",
        "Pide & Lahmacun",
        "Pastane",
        "Fırın",
        "Tatlıcı",
        "Dondurmacı",
        "Çay Ocağı",
        "Kahvaltı Salonu",
        "Balık Restoranı"
      ]
    },
    {
      "name": "Tamir & Servis",
      "sub": [
        "Elektrikçi",
        "Su Tesisatçısı",
        "Doğalgaz Ustası",
        "Klima Servisi",
        "Kombi Servisi",
        "Beyaz Eşya Servisi",
        "TV Tamircisi",
        "Telefon Tamircisi",
        "Bilgisayar Teknik Servis",
        "Uyducu",
        "Asansör Servisi"
      ]
    },

    {
      "name": "Emlak & İnşaat",
      "sub": [
        "Emlak Ofisi",
        "Gayrimenkul Danışmanı",
        "Müteahhit",
        "Boyacı",
        "Marangoz",
        "Yapı Malzemeleri"
      ]
    },

    {
      "name": "Market & Alışveriş",
      "sub": [
        "Market",
        "Bakkal",
        "Şarküteri",
        "Kasap",
        "Manav",
        "Kırtasiye",
        "Giyim Mağazası"
      ]
    },

    {
      "name": "Güzellik & Kuaför",
      "sub": [
        "Kuaför (Kadın)",
        "Berber (Erkek)",
        "Güzellik Salonu",
        "Spa & Masaj"
      ]
    },

    {
      "name": "Sağlık",
      "sub": [
        "Hastane",
        "Özel Klinik",
        "Aile Hekimi",
        "Diş Kliniği",
        "Eczane",
        "Psikolog",
        "Veteriner"
            "Diyetisyen"
      ]
    },

    {
      "name": "Otomotiv",
      "sub": [
        "Oto Tamirci",
        "Lastikçi",
        "Oto Yıkama",
        "Oto Galeri",
        "Yedek Parça"
      ]
    },

    {
      "name": "Hizmetler",
      "sub": [
        "Temizlik Firması",
        "Nakliyat",
        "Kargo & Kurye",
        "Fotoğrafçı",
        "Organizasyon"
      ]
    },

    {
      "name": "Eğitim",
      "sub": [
        "Okul",
        "Kurs Merkezi",
        "Özel Ders",
        "Sürücü Kursu",
        "Kreş & Anaokulu"
      ]
    },

    {
      "name": "Kamu & Resmi",
      "sub": [
        "Belediye Hizmetleri",
        "Muhtarlık",
        "Noter",
        "Banka",
        "PTT",
        "Kaymakamlık",
        "Hastane",
        "Sağlık Ocağı",
        "Emniyet",
        "İlçe Müdürlükleri"
      ]
    },

    {
      "name": "Tarım & Hayvancılık",
      "sub": ["Yem Bayii", "Tarım İlaçları", "Zirai Ekipman", "Besi Çiftliği"]
    },

    {
      "name": "Diğer",
      "sub": [
        "Saatçi",
        "Anahtarcı (Çilingir)",
        "İnternet Kafe",
        "Oyun Salonu",
        "Pet Shop"
      ]
    },

    {
      "name": "Ev & Mobilya", // Doğtaş, İstikbal vb. işletmeler buraya girer

      "sub": [
        "Mobilya Mağazası",
        "Beyaz Eşya Mağazası",
        "Züccaciye & Mutfak Eşyaları",
        "Halıcı",
        "Perdeci",
        "Aydınlatma & Avize",
        "Ev Tekstili & Çeyiz",
        "Yapı Market"
      ]
    },

    {
      "name":
          "Giyim & Aksesuar", // Giyim mağazasını Market kategorisinden ayırıp buraya alabilirsiniz

      "sub": [
        "Kadın Giyim",
        "Erkek Giyim",
        "Çocuk & Bebek Giyim",
        "Ayakkabı & Çanta",
        "Kuyumcu",
        "Gözlükçü (Optik)",
        "Bijuteri",
        "Terzi",
        "Kuru Temizleme"
      ]
    },

    {
      "name": "Profesyonel Hizmetler", // Kurumsal veya ofis tarzı işletmeler

      "sub": [
        "Avukat & Hukuk Bürosu",
        "Mali Müşavir & Muhasebe",
        "Sigorta Acentesi",
        "Mimarlık & Mühendislik Ofisi",
        "Tercüme Bürosu",
        "Reklam & Dijital Ajans",
        "Danışmanlık Firması"
      ]
    },

    {
      "name": "Konaklama & Turizm",
      "sub": [
        "Otel",
        "Butik Otel & Pansiyon",
        "Tur Acentesi",
        "Araç Kiralama (Rent a Car)",
        "Kamp & Karavan Tesisi"
      ]
    },

    {
      "name": "Spor & Eğlence",
      "sub": [
        "Spor Salonu (Fitness)",
        "Pilates & Yoga Stüdyosu",
        "Halı Saha",
        "Yüzme Havuzu",
        "Sinema & Tiyatro",
        "Eğlence Merkezi",
        "Dans Kursu"
      ]
    },

    {
      "name": "Teknoloji & Elektronik",
      "sub": [
        "Teknoloji Mağazası (AVM Tipi)",
        "Telefon & Aksesuar Satış",
        "Bilgisayar Satış",
        "Güvenlik Kamerası & Alarm Sistemi",
        "Yazılım Firması"
      ]
    },

    {
      "name":
          "Sanayi & Üretim", // Özellikle sanayi bölgelerindeki işletmeler için

      "sub": [
        "Matbaa & Baskı",
        "Demir Doğrama",
        "Alüminyum & PVC",
        "Mobilya İmalat",
        "Tekstil Atölyesi",
        "Tornacı"
      ]
    }
  ];

  final List<String> regions = ['Pazarcık Merkez', 'Narlı', 'Köyler', 'Online'];

  @override
  void initState() {
    super.initState();
    final data = widget.existingBusiness;

    _nameController = TextEditingController(text: data?['businessName'] ?? "");
    _descController = TextEditingController(text: data?['description'] ?? "");
    _phoneController = TextEditingController(text: data?['contact'] ?? "");
    _updateNoteController = TextEditingController();
    _tagController = TextEditingController();
    _webController =
        TextEditingController(text: data?['socialMedia']?['website'] ?? "");
    _instaController =
        TextEditingController(text: data?['socialMedia']?['instagram'] ?? "");
    _faceController =
        TextEditingController(text: data?['socialMedia']?['facebook'] ?? "");
    _mapLinkController = TextEditingController(text: data?['mapLink'] ?? "");
    _addressDescController =
        TextEditingController(text: data?['addressDesc'] ?? "");

    _selectedMainCategory = data?['mainCategory'];
    _selectedSubCategory = data?['category'];
    _tags = List<String>.from(data?['tags'] ?? []);
    _selectedRegions = List<String>.from(data?['regions'] ?? []);

    if (data?['imageUrls'] != null && (data!['imageUrls'] as List).isNotEmpty) {
      _existingImageUrl = data['imageUrls'][0];
    }

    // 🔥 YENİ EKLENEN: Mevcut galeri resimlerini çekme
    if (data?['galleryUrls'] != null) {
      _existingGalleryUrls = List<String>.from(data!['galleryUrls']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    _updateNoteController.dispose();
    _tagController.dispose();
    _webController.dispose();
    _instaController.dispose();
    _faceController.dispose();
    _mapLinkController.dispose();
    _addressDescController.dispose();
    super.dispose();
  }

  // Profil resmi seçici
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (pickedFile != null)
      setState(() => _selectedImage = File(pickedFile.path));
  }

  // 🔥 YENİ EKLENEN: Çoklu Galeri Resmi Seçici
  Future<void> _pickGalleryImages() async {
    int currentTotal = _existingGalleryUrls.length + _newGalleryImages.length;

    if (currentTotal >= _maxGalleryImages) {
      _showToast(
          "En fazla $_maxGalleryImages resim ekleyebilirsiniz.", Colors.red);
      return;
    }

    final List<XFile> pickedFiles =
        await ImagePicker().pickMultiImage(imageQuality: 60);

    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var xFile in pickedFiles) {
          if (_existingGalleryUrls.length + _newGalleryImages.length <
              _maxGalleryImages) {
            _newGalleryImages.add(File(xFile.path));
          } else {
            _showToast(
                "Sınır aşıldığı için bazı resimler eklenmedi.", Colors.orange);
            break;
          }
        }
      });
    }
  }

  void _addTag(String val) {
    if (val.trim().isNotEmpty && !_tags.contains(val.trim())) {
      setState(() {
        _tags.add(val.trim());
        _tagController.clear();
      });
    }
  }

  Future<void> _saveBusiness() async {
    if (_nameController.text.isEmpty || _selectedSubCategory == null) {
      _showToast("Lütfen isim ve alt kategori seçin.", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String finalImageUrl = _existingImageUrl ?? "";
      List<String> finalGalleryUrls =
          List.from(_existingGalleryUrls); // 🔥 GÜNCELLENDİ

      // Profil resmini yükle
      if (_selectedImage != null) {
        finalImageUrl = await FirebaseStorageService.uploadFile(_selectedImage!,
                folderName:
                    widget.isPublic ? "public_assets" : "business_assets") ??
            "";
      }

      // 🔥 YENİ EKLENEN: Yeni seçilen galeri resimlerini yükle
      for (File file in _newGalleryImages) {
        String? uploadedUrl = await FirebaseStorageService.uploadFile(file,
            folderName:
                widget.isPublic ? "public_gallery" : "business_gallery");
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          finalGalleryUrls.add(uploadedUrl);
        }
      }

      Map<String, dynamic> businessData = {
        'businessName': _nameController.text.trim(),
        'mainCategory': _selectedMainCategory,
        'category': _selectedSubCategory,
        'contact': _phoneController.text.trim(),
        'description': _descController.text.trim(),
        'mapLink': _mapLinkController.text.trim(),
        'addressDesc': _addressDescController.text.trim(),
        'imageUrls': [finalImageUrl], // Ana profil resmi
        'galleryUrls':
            finalGalleryUrls, // 🔥 YENİ EKLENEN: Vitrin Resimleri (Ürün, Menü, Fiyat listesi)
        'regions': _selectedRegions,
        'tags': _tags,
        'type': widget.isPublic ? 'public' : 'private',
        'socialMedia': {
          'website': _webController.text.trim(),
          'instagram': _instaController.text.trim(),
          'facebook': _faceController.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.docId == null || widget.docId!.isEmpty) {
        businessData['status'] = widget.isPublic ? 'approved' : 'pending';
        businessData['createdAt'] = FieldValue.serverTimestamp();
        businessData['editorId'] = FirebaseAuth.instance.currentUser?.uid;

        // 🔥 DEĞİŞİKLİK 1: add işlemini docRef değişkenine atıyoruz ki id'sini alabilelim
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('businesses')
            .add(businessData);

        // 🔥 DEĞİŞİKLİK 2: Senin eklemek istediğin bildirim kodu buraya geliyor
        await AdminNotificationService.instance.notifyAdmin(
          title: '🏢 Yeni İşletme Başvurusu',
          body: _nameController.text
              .trim(), // İşletme adını direkt controller'dan alıyoruz
          type: AdminNotifType.businessApply,
          docId: docRef.id, // Firestore'un oluşturduğu id'yi verdik
        );

        _showToast("Kayıt Başarıyla Eklendi! ✅", Colors.green);
      } else {
        businessData['lastUpdateNote'] = _updateNoteController.text.trim();
        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(widget.docId)
            .update(businessData);
        _showToast("Kayıt Güncellendi! ✅", Colors.blue);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showToast("Hata oluştu: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = widget.isPublic ? publicColor : primaryColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.isPublic ? "Kamu Kurumu Kaydı" : "İşletme Kaydı",
            style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: Icon(CupertinoIcons.xmark, color: themeColor),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageSection(themeColor),
                  const SizedBox(height: 30),
                  _buildSectionTitle("TEMEL BİLGİLER"),
                  _buildTextField("Kurum/İşletme Adı *", _nameController,
                      CupertinoIcons.building_2_fill, themeColor),
                  _buildMainCategoryPicker(),
                  if (_selectedMainCategory != null)
                    _buildSubCategoryPicker(themeColor),
                  _buildTextField("Hakkında / Açıklama", _descController,
                      CupertinoIcons.text_quote, themeColor,
                      maxLines: 3),
                  _buildPhoneField(themeColor),

                  const SizedBox(height: 25),
                  // 🔥 YENİ EKLENEN: GALERİ BÖLÜMÜ
                  _buildSectionTitle("ÜRÜN & VİTRİN GALERİSİ (Max 5 Resim)"),
                  _buildGallerySection(themeColor),

                  const SizedBox(height: 25),
                  _buildSectionTitle("ANAHTAR KELİMELER & HİZMETLER"),
                  _buildTagSystem(themeColor),
                  const SizedBox(height: 25),
                  _buildSectionTitle("KONUM BİLGİLERİ"),
                  _buildTextField("Google Haritalar Linki", _mapLinkController,
                      CupertinoIcons.location_solid, themeColor),
                  _buildTextField("Adres Tarifi", _addressDescController,
                      CupertinoIcons.map_pin_ellipse, themeColor,
                      maxLines: 2),
                  const SizedBox(height: 25),
                  _buildSectionTitle("DİJİTAL KANALLAR"),
                  _buildTextField("Web Sitesi", _webController,
                      CupertinoIcons.globe, themeColor),
                  _buildTextField("Instagram (Kullanıcı Adı)", _instaController,
                      CupertinoIcons.camera, themeColor),
                  const SizedBox(height: 25),
                  _buildSectionTitle("HİZMET BÖLGELERİ"),
                  _buildRegionChips(themeColor),
                  const SizedBox(height: 40),
                  _buildSubmitButton(themeColor),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  // --- 🔥 YENİ EKLENEN: Galeri Widget'ı ---
  Widget _buildGallerySection(Color themeColor) {
    int totalImages = _existingGalleryUrls.length + _newGalleryImages.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Menü, fiyat listesi, ürünler veya vitrin fotoğraflarını buraya ekleyebilirsiniz.",
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Ekleme Butonu (Sınır dolmadıysa göster)
                if (totalImages < _maxGalleryImages)
                  GestureDetector(
                    onTap: _pickGalleryImages,
                    child: Container(
                      height: 90,
                      width: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: themeColor.withOpacity(0.3),
                            style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.camera_on_rectangle,
                              color: themeColor),
                          const SizedBox(height: 5),
                          Text("$totalImages/$_maxGalleryImages",
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: themeColor,
                                  fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ),

                // Zaten Yüklenmiş Olan Resimler
                ..._existingGalleryUrls.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String url = entry.value;
                  return _buildGalleryThumbnail(
                      imageWidget:
                          PortalNetworkImage(url: url, fit: BoxFit.cover),
                      onDelete: () =>
                          setState(() => _existingGalleryUrls.removeAt(idx)));
                }).toList(),

                // Yeni Seçilen Resimler (Henüz yüklenmemiş)
                ..._newGalleryImages.asMap().entries.map((entry) {
                  int idx = entry.key;
                  File file = entry.value;
                  return _buildGalleryThumbnail(
                      imageWidget: portalPickedImage(file, fit: BoxFit.cover),
                      onDelete: () =>
                          setState(() => _newGalleryImages.removeAt(idx)));
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Galeri içindeki küçük fotoğraf kutuları
  Widget _buildGalleryThumbnail(
      {required Widget imageWidget, required VoidCallback onDelete}) {
    return Container(
      height: 90,
      width: 90,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(height: 90, width: 90, child: imageWidget),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(CupertinoIcons.delete,
                    color: Colors.white, size: 14),
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- Alt taraftaki mevcut widget'ların (Profil resmi, inputlar vs) senin kodundaki ile birebir aynı kalabilir ---
  // (Burada kod uzamasın diye senin gönderdiğin diğer yardımcı metodları aynen bırakıyorum, yukarıdaki _buildGallerySection ve Firebase kayıt mantığı yeterli)

  // Geri kalan _buildImageSection, _buildMainCategoryPicker, _buildSubCategoryPicker vb. aynen kalacak...
  Widget _buildImageSection(Color color) {
    return Center(
      child: Stack(
        children: [
          Container(
            height: 130,
            width: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: _selectedImage != null
                  ? portalPickedImage(_selectedImage!, fit: BoxFit.cover)
                  : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty
                      ? PortalNetworkImage(
                          url: _existingImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: const CupertinoActivityIndicator())
                      : Icon(CupertinoIcons.camera_fill,
                          color: color.withOpacity(0.3), size: 40)),
            ),
          ),
          Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                      backgroundColor: color,
                      radius: 20,
                      child: const Icon(CupertinoIcons.pencil,
                          color: Colors.white, size: 18)))),
        ],
      ),
    );
  }

  // ... Diğer tüm _buildTextField vb metotların senin attığın kodla birebir aynıdır.
  Widget _buildTextField(String label, TextEditingController controller,
      IconData icon, Color color,
      {int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
              prefixIcon: Icon(icon, color: color.withOpacity(0.6), size: 20),
              hintText: label,
              hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Colors.black26,
                  fontWeight: FontWeight.normal),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(18))),
    );
  }

  Widget _buildMainCategoryPicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMainCategory,
          isExpanded: true,
          hint: Text("Ana Kategori Seçiniz",
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black45)),
          items: categories
              .map((c) => DropdownMenuItem<String>(
                  value: c['name'],
                  child: Text(c['name'], style: const TextStyle(fontSize: 14))))
              .toList(),
          onChanged: (val) => setState(() {
            _selectedMainCategory = val;
            _selectedSubCategory = null;
          }),
        ),
      ),
    );
  }

  Widget _buildSubCategoryPicker(Color color) {
    List<String> subCats =
        categories.firstWhere((c) => c['name'] == _selectedMainCategory)['sub'];
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSubCategory,
          isExpanded: true,
          hint: Text("Alt Branş Seçiniz",
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black45)),
          items: subCats
              .map((s) => DropdownMenuItem<String>(
                  value: s,
                  child: Text(s, style: const TextStyle(fontSize: 14))))
              .toList(),
          onChanged: (val) => setState(() => _selectedSubCategory = val),
        ),
      ),
    );
  }

  Widget _buildPhoneField(Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11)
          ],
          decoration: InputDecoration(
              prefixIcon: Icon(CupertinoIcons.phone_fill,
                  color: color.withOpacity(0.6), size: 20),
              hintText: "İletişim Numarası (05xx...)",
              hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Colors.black26,
                  fontWeight: FontWeight.normal),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(18))),
    );
  }

  Widget _buildTagSystem(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(15)),
          child: TextField(
            controller: _tagController,
            decoration: InputDecoration(
                hintText: "Hizmet/Ürün yazıp ekleyin...",
                hintStyle: const TextStyle(fontSize: 13, color: Colors.black26),
                suffixIcon: IconButton(
                    icon: Icon(CupertinoIcons.add_circled_solid, color: color),
                    onPressed: () => _addTag(_tagController.text)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15)),
            onSubmitted: (val) => _addTag(val),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags
                .map((tag) => Chip(
                      label: Text(tag,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      deleteIcon: const Icon(CupertinoIcons.xmark_circle_fill,
                          size: 16),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                      backgroundColor: color.withOpacity(0.08),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ))
                .toList()),
      ],
    );
  }

  Widget _buildRegionChips(Color color) {
    return Wrap(
        spacing: 10,
        children: regions.map((r) {
          bool isSelected = _selectedRegions.contains(r);
          return FilterChip(
              label: Text(r,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              onSelected: (val) => setState(() =>
                  val ? _selectedRegions.add(r) : _selectedRegions.remove(r)),
              selectedColor: color.withOpacity(0.2),
              checkmarkColor: color,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: isSelected ? color : Colors.transparent)));
        }).toList());
  }

  Widget _buildSubmitButton(Color color) {
    return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18))),
            onPressed: _isLoading ? null : _saveBusiness,
            child: Text(
                widget.docId != null ? "BİLGİLERİ GÜNCELLE" : "KAYDI TAMAMLA",
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white))));
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 10),
        child: Text(title,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black45,
                letterSpacing: 0.5)));
  }

  void _showToast(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))));
  }
}
