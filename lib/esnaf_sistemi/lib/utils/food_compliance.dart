class FoodIngredient {
  const FoodIngredient(
    this.name, {
    this.allergens = const [],
    this.meat = false,
    this.calories = 0,
    this.warnings = const [],
  });

  final String name;
  final List<String> allergens;
  final bool meat;
  final int calories;
  final List<String> warnings;
}

class FoodSuggestion {
  const FoodSuggestion({
    required this.name,
    required this.category,
    required this.ingredients,
    this.removableIngredients = const [],
    this.addableIngredients = const [],
    required this.calorieMin,
    required this.calorieMax,
    this.meatOriginRequired = false,
    this.warnings = const [],
  });

  final String name;
  final String category;
  final List<String> ingredients;
  final List<String> removableIngredients;
  final List<String> addableIngredients;
  final int calorieMin;
  final int calorieMax;
  final bool meatOriginRequired;
  final List<String> warnings;

  String get calorieText {
    if (calorieMin == calorieMax) return 'Yaklaşık $calorieMin kcal';
    return 'Yaklaşık $calorieMin-$calorieMax kcal';
  }
}

class FoodComplianceHelper {
  static const List<FoodIngredient> ingredients = [
    FoodIngredient('Buğday unu', allergens: ['Gluten'], calories: 110),
    FoodIngredient('Bulgur', allergens: ['Gluten'], calories: 150),
    FoodIngredient('Ekmek / lavaş', allergens: ['Gluten'], calories: 180),
    FoodIngredient('Tırnak pide',
        allergens: ['Gluten', 'Susam'], calories: 220),
    FoodIngredient('Hamburger ekmeği',
        allergens: ['Gluten', 'Susam'], calories: 210),
    FoodIngredient('Pizza hamuru', allergens: ['Gluten'], calories: 430),
    FoodIngredient('Makarna', allergens: ['Gluten', 'Yumurta'], calories: 320),
    FoodIngredient('Süt', allergens: ['Süt ve laktoz'], calories: 90),
    FoodIngredient('Yoğurt', allergens: ['Süt ve laktoz'], calories: 80),
    FoodIngredient('Tereyağı', allergens: ['Süt ve laktoz'], calories: 90),
    FoodIngredient('Kaşar peyniri',
        allergens: ['Süt ve laktoz'], calories: 110),
    FoodIngredient('Cheddar peyniri',
        allergens: ['Süt ve laktoz'], calories: 120),
    FoodIngredient('Mozzarella', allergens: ['Süt ve laktoz'], calories: 95),
    FoodIngredient('Kaymak', allergens: ['Süt ve laktoz'], calories: 140),
    FoodIngredient('Yumurta', allergens: ['Yumurta'], calories: 70),
    FoodIngredient('Mayonez', allergens: ['Yumurta', 'Hardal'], calories: 90),
    FoodIngredient('Hardal', allergens: ['Hardal'], calories: 15),
    FoodIngredient('Susam', allergens: ['Susam'], calories: 40),
    FoodIngredient('Ceviz', allergens: ['Sert kabuklu yemiş'], calories: 90),
    FoodIngredient('Fındık', allergens: ['Sert kabuklu yemiş'], calories: 85),
    FoodIngredient('Antep fıstığı',
        allergens: ['Sert kabuklu yemiş'], calories: 80),
    FoodIngredient('Yer fıstığı', allergens: ['Yer fıstığı'], calories: 85),
    FoodIngredient('Soya sosu',
        allergens: ['Soya'], calories: 20, warnings: ['Yüksek sodyum içerir.']),
    FoodIngredient('Balık', allergens: ['Balık'], meat: true, calories: 260),
    FoodIngredient('Kabuklu deniz ürünü',
        allergens: ['Kabuklu deniz ürünü'], meat: true, calories: 220),
    FoodIngredient('Dana eti', meat: true, calories: 330),
    FoodIngredient('Kuzu eti', meat: true, calories: 380),
    FoodIngredient('Tavuk eti', meat: true, calories: 260),
    FoodIngredient('Hindi eti', meat: true, calories: 240),
    FoodIngredient('Kıyma', meat: true, calories: 360),
    FoodIngredient('Sucuk', meat: true, calories: 180, warnings: [
      'Yüksek sodyum içerir.',
      'Gebelikte tüketim doktora danışılmalıdır.'
    ]),
    FoodIngredient('Salam', meat: true, calories: 140, warnings: [
      'Yüksek sodyum içerir.',
      'Gebelikte tüketim doktora danışılmalıdır.'
    ]),
    FoodIngredient('Sosis', meat: true, calories: 160, warnings: [
      'Yüksek sodyum içerir.',
      'Gebelikte tüketim doktora danışılmalıdır.'
    ]),
    FoodIngredient('Pastırma',
        meat: true, calories: 150, warnings: ['Yüksek sodyum içerir.']),
    FoodIngredient('Ciğer', meat: true, calories: 250, warnings: [
      'Gebelikte ve kolesterol hassasiyetinde doktora danışılmalıdır.'
    ]),
    FoodIngredient('Pirinç', calories: 180),
    FoodIngredient('Mercimek', calories: 150),
    FoodIngredient('Nohut', calories: 190),
    FoodIngredient('Fasulye', calories: 180),
    FoodIngredient('Patates', calories: 160),
    FoodIngredient('Patates kızartması',
        calories: 320, warnings: ['Kızartma ve yüksek yağ içerir.']),
    FoodIngredient('Domates', calories: 20),
    FoodIngredient('Biber', calories: 20),
    FoodIngredient('Jalapeno', calories: 10, warnings: ['Acı içerir.']),
    FoodIngredient('Soğan', calories: 25),
    FoodIngredient('Sumaklı soğan', calories: 35),
    FoodIngredient('Sarımsak', calories: 15),
    FoodIngredient('Marul', calories: 10),
    FoodIngredient('Turşu', calories: 20, warnings: ['Yüksek sodyum içerir.']),
    FoodIngredient('Mantar', calories: 25),
    FoodIngredient('Mısır', calories: 70),
    FoodIngredient('Zeytin', calories: 70),
    FoodIngredient('Salça', calories: 35),
    FoodIngredient('Ketçap', calories: 35),
    FoodIngredient('Barbekü sos', calories: 45),
    FoodIngredient('Acı sos', calories: 15, warnings: ['Acı içerir.']),
    FoodIngredient('Ranch sos', allergens: ['Süt ve laktoz'], calories: 80),
    FoodIngredient('Baharat', calories: 10),
    FoodIngredient('Zeytinyağı', calories: 90),
    FoodIngredient('Ayçiçek yağı', calories: 90),
    FoodIngredient('Kuyruk yağı',
        calories: 150, warnings: ['Yüksek doymuş yağ içerir.']),
    FoodIngredient('Şeker', calories: 80, warnings: ['Yüksek şeker içerir.']),
    FoodIngredient('Şerbet', calories: 180, warnings: ['Yüksek şeker içerir.']),
    FoodIngredient('Çikolata sosu',
        allergens: ['Süt ve laktoz', 'Soya'], calories: 120),
    FoodIngredient('Dondurma', allergens: ['Süt ve laktoz'], calories: 160),
    FoodIngredient('Buz', calories: 0),
    FoodIngredient('Limon', calories: 5),
    FoodIngredient('Nane', calories: 2),
  ];

  static const List<FoodSuggestion> suggestions = [
    FoodSuggestion(
      name: 'Süzme Mercimek Çorbası',
      category: 'Çorba',
      ingredients: ['Mercimek', 'Soğan', 'Salça', 'Baharat', 'Ayçiçek yağı'],
      addableIngredients: ['Limon', 'Tereyağı', 'Kıtır ekmek'],
      calorieMin: 150,
      calorieMax: 220,
    ),
    FoodSuggestion(
      name: 'Ezogelin Çorbası',
      category: 'Çorba',
      ingredients: ['Mercimek', 'Bulgur', 'Soğan', 'Salça', 'Baharat'],
      addableIngredients: ['Limon', 'Tereyağı', 'Acı sos'],
      calorieMin: 170,
      calorieMax: 250,
    ),
    FoodSuggestion(
      name: 'Yayla Çorbası',
      category: 'Çorba',
      ingredients: ['Yoğurt', 'Pirinç', 'Yumurta', 'Tereyağı', 'Baharat'],
      addableIngredients: ['Nane', 'Tereyağı'],
      calorieMin: 180,
      calorieMax: 260,
    ),
    FoodSuggestion(
      name: 'Kelle Paça',
      category: 'Çorba',
      ingredients: ['Dana eti', 'Sarımsak', 'Baharat'],
      addableIngredients: ['Sarımsak', 'Limon', 'Sirke'],
      calorieMin: 300,
      calorieMax: 450,
      meatOriginRequired: true,
      warnings: [
        'Sakatat içerir. Gebelik ve kolesterol hassasiyetinde dikkat edilmelidir.'
      ],
    ),
    FoodSuggestion(
      name: 'Adana Kebap',
      category: 'Kebap',
      ingredients: ['Kıyma', 'Baharat', 'Ekmek / lavaş', 'Soğan'],
      removableIngredients: ['Soğan', 'Acı sos', 'Kuyruk yağı'],
      addableIngredients: ['Tırnak pide', 'Yoğurt', 'Közlenmiş biber'],
      calorieMin: 550,
      calorieMax: 750,
      meatOriginRequired: true,
      warnings: ['Acı ve doymuş yağ içerebilir.'],
    ),
    FoodSuggestion(
      name: 'Urfa Kebap',
      category: 'Kebap',
      ingredients: ['Kıyma', 'Baharat', 'Ekmek / lavaş', 'Soğan'],
      removableIngredients: ['Soğan', 'Kuyruk yağı'],
      addableIngredients: ['Tırnak pide', 'Yoğurt', 'Közlenmiş biber'],
      calorieMin: 540,
      calorieMax: 730,
      meatOriginRequired: true,
    ),
    FoodSuggestion(
      name: 'İskender Kebap',
      category: 'Kebap',
      ingredients: ['Dana eti', 'Ekmek / lavaş', 'Tereyağı', 'Yoğurt', 'Salça'],
      addableIngredients: ['Tereyağı', 'Yoğurt'],
      calorieMin: 750,
      calorieMax: 1050,
      meatOriginRequired: true,
      warnings: ['Gluten, laktoz ve yüksek yağ içerir.'],
    ),
    FoodSuggestion(
      name: 'Hatay Usulü Tavuk Döner Dürüm',
      category: 'Döner',
      ingredients: [
        'Tavuk eti',
        'Ekmek / lavaş',
        'Patates kızartması',
        'Mayonez',
        'Ketçap',
        'Baharat'
      ],
      removableIngredients: [
        'Patates kızartması',
        'Mayonez',
        'Ketçap',
        'Turşu'
      ],
      addableIngredients: ['Kaşar peyniri', 'Acı sos', 'Barbekü sos'],
      calorieMin: 650,
      calorieMax: 950,
      meatOriginRequired: true,
    ),
    FoodSuggestion(
      name: 'Et Döner Dürüm',
      category: 'Döner',
      ingredients: ['Dana eti', 'Ekmek / lavaş', 'Soğan', 'Domates', 'Baharat'],
      removableIngredients: ['Soğan', 'Domates', 'Turşu'],
      addableIngredients: ['Kaşar peyniri', 'Patates kızartması', 'Acı sos'],
      calorieMin: 620,
      calorieMax: 900,
      meatOriginRequired: true,
    ),
    FoodSuggestion(
      name: 'Lahmacun',
      category: 'Pide ve Lahmacun',
      ingredients: [
        'Buğday unu',
        'Kıyma',
        'Soğan',
        'Domates',
        'Biber',
        'Baharat'
      ],
      removableIngredients: ['Soğan', 'Acı sos'],
      addableIngredients: ['Limon', 'Maydanoz', 'Ayran'],
      calorieMin: 300,
      calorieMax: 450,
      meatOriginRequired: true,
    ),
    FoodSuggestion(
      name: 'Kaşarlı Pide',
      category: 'Pide ve Lahmacun',
      ingredients: ['Buğday unu', 'Kaşar peyniri', 'Tereyağı', 'Yumurta'],
      addableIngredients: ['Sucuk', 'Kavurma', 'Mantar'],
      calorieMin: 650,
      calorieMax: 950,
    ),
    FoodSuggestion(
      name: 'Karışık Pide',
      category: 'Pide ve Lahmacun',
      ingredients: ['Buğday unu', 'Kaşar peyniri', 'Sucuk', 'Kıyma', 'Yumurta'],
      removableIngredients: ['Sucuk', 'Yumurta'],
      addableIngredients: ['Mantar', 'Kavurma'],
      calorieMin: 750,
      calorieMax: 1050,
      meatOriginRequired: true,
    ),
    FoodSuggestion(
      name: 'Klasik Hamburger',
      category: 'Burger',
      ingredients: [
        'Hamburger ekmeği',
        'Dana eti',
        'Marul',
        'Domates',
        'Soğan',
        'Ketçap',
        'Mayonez'
      ],
      removableIngredients: ['Soğan', 'Domates', 'Marul', 'Ketçap', 'Mayonez'],
      addableIngredients: [
        'Cheddar peyniri',
        'Patates kızartması',
        'Barbekü sos'
      ],
      calorieMin: 650,
      calorieMax: 900,
      meatOriginRequired: true,
    ),
    FoodSuggestion(
      name: 'Cheeseburger',
      category: 'Burger',
      ingredients: [
        'Hamburger ekmeği',
        'Dana eti',
        'Cheddar peyniri',
        'Marul',
        'Domates',
        'Mayonez'
      ],
      removableIngredients: ['Soğan', 'Domates', 'Marul', 'Mayonez'],
      addableIngredients: [
        'Cheddar peyniri',
        'Patates kızartması',
        'Barbekü sos'
      ],
      calorieMin: 750,
      calorieMax: 1050,
      meatOriginRequired: true,
    ),
    FoodSuggestion(
      name: 'Karışık Pizza',
      category: 'Pizza',
      ingredients: [
        'Pizza hamuru',
        'Mozzarella',
        'Sucuk',
        'Sosis',
        'Mantar',
        'Mısır',
        'Zeytin'
      ],
      removableIngredients: ['Sucuk', 'Sosis', 'Mantar', 'Mısır', 'Zeytin'],
      addableIngredients: ['Kaşar peyniri', 'Jalapeno', 'Barbekü sos'],
      calorieMin: 850,
      calorieMax: 1250,
      meatOriginRequired: true,
    ),
    FoodSuggestion(
      name: 'Mantı',
      category: 'Ev Yemekleri',
      ingredients: ['Buğday unu', 'Yumurta', 'Kıyma', 'Yoğurt', 'Tereyağı'],
      addableIngredients: ['Yoğurt', 'Tereyağı', 'Acı sos'],
      calorieMin: 600,
      calorieMax: 850,
      meatOriginRequired: true,
    ),
    FoodSuggestion(
      name: 'Patates Kızartması',
      category: 'Yan Ürün',
      ingredients: ['Patates kızartması', 'Ayçiçek yağı'],
      addableIngredients: ['Ketçap', 'Mayonez', 'Ranch sos'],
      calorieMin: 320,
      calorieMax: 520,
      warnings: ['Kızartma ve yüksek yağ içerir.'],
    ),
    FoodSuggestion(
      name: 'Çiğ Köfte Dürüm',
      category: 'Yan Ürün',
      ingredients: ['Bulgur', 'Ekmek / lavaş', 'Baharat', 'Limon', 'Marul'],
      removableIngredients: ['Acı sos', 'Soğan'],
      addableIngredients: ['Nar ekşisi', 'Limon', 'Marul'],
      calorieMin: 350,
      calorieMax: 520,
      warnings: ['Acı ve gluten içerebilir.'],
    ),
    FoodSuggestion(
      name: 'Cevizli Baklava',
      category: 'Tatlı',
      ingredients: ['Buğday unu', 'Ceviz', 'Tereyağı', 'Şerbet', 'Yumurta'],
      addableIngredients: ['Kaymak', 'Dondurma'],
      calorieMin: 420,
      calorieMax: 650,
      warnings: ['Yüksek şeker içerir. Diyabet hastaları dikkat etmelidir.'],
    ),
    FoodSuggestion(
      name: 'Künefe',
      category: 'Tatlı',
      ingredients: [
        'Buğday unu',
        'Kaşar peyniri',
        'Tereyağı',
        'Şerbet',
        'Antep fıstığı'
      ],
      addableIngredients: ['Kaymak', 'Dondurma', 'Antep fıstığı'],
      calorieMin: 650,
      calorieMax: 950,
      warnings: ['Yüksek şeker ve laktoz içerir.'],
    ),
    FoodSuggestion(
      name: 'Fırın Sütlaç',
      category: 'Tatlı',
      ingredients: ['Süt', 'Pirinç', 'Şeker', 'Yumurta'],
      addableIngredients: ['Fındık', 'Antep fıstığı'],
      calorieMin: 260,
      calorieMax: 420,
      warnings: ['Laktoz ve şeker içerir.'],
    ),
    FoodSuggestion(
      name: 'Ayran',
      category: 'İçecek',
      ingredients: ['Yoğurt'],
      addableIngredients: ['Buz'],
      calorieMin: 70,
      calorieMax: 140,
    ),
    FoodSuggestion(
      name: 'Kola',
      category: 'İçecek',
      ingredients: ['Şeker'],
      addableIngredients: ['Buz', 'Limon'],
      calorieMin: 140,
      calorieMax: 220,
      warnings: ['Şekerli ve asitli içecektir.'],
    ),
    FoodSuggestion(
      name: 'Türk Kahvesi',
      category: 'İçecek',
      ingredients: [],
      addableIngredients: ['Şeker'],
      calorieMin: 5,
      calorieMax: 80,
    ),
  ];

  static List<FoodSuggestion> searchSuggestions(String query) {
    final q = _normalize(query);
    final source = q.isEmpty
        ? suggestions
        : suggestions.where((item) {
            return _normalize(item.name).contains(q) ||
                _normalize(item.category).contains(q);
          });
    return _uniqueSuggestions(source).take(q.isEmpty ? 12 : 16).toList();
  }

  static List<String> allergensFor(List<String> selectedIngredients) {
    final result = <String>{};
    for (final selected in selectedIngredients) {
      final normalized = _normalize(selected);
      for (final item in ingredients) {
        if (_normalize(item.name) == normalized) {
          result.addAll(item.allergens);
        }
      }
    }
    return result.toList()..sort();
  }

  static List<String> warningsFor(
    List<String> selectedIngredients, {
    FoodSuggestion? suggestion,
  }) {
    final result = <String>{...?suggestion?.warnings};
    for (final selected in selectedIngredients) {
      final normalized = _normalize(selected);
      for (final item in ingredients) {
        if (_normalize(item.name) == normalized) {
          result.addAll(item.warnings);
        }
      }
    }
    if (allergensFor(selectedIngredients).contains('Gluten')) {
      result.add(
          'Gluten içerir. Çölyak hastaları ve gluten hassasiyeti olanlar için uygun olmayabilir.');
    }
    return result.toList()..sort();
  }

  static bool requiresMeatOrigin(List<String> selectedIngredients) {
    return selectedIngredients.any((selected) {
      final normalized = _normalize(selected);
      return ingredients.any(
        (item) => _normalize(item.name) == normalized && item.meat,
      );
    });
  }

  static int extraCaloriesFor(List<String> selectedAddables) {
    var total = 0;
    for (final selected in selectedAddables) {
      final normalized = _normalize(selected);
      for (final item in ingredients) {
        if (_normalize(item.name) == normalized) {
          total += item.calories;
          break;
        }
      }
    }
    return total;
  }

  static Map<String, int> calorieMapFor(Iterable<String> ingredientNames) {
    return {
      for (final name in ingredientNames)
        name: ingredients
            .where(
                (ingredient) => _normalize(ingredient.name) == _normalize(name))
            .map((ingredient) => ingredient.calories)
            .fold(0, (total, calories) => total + calories),
    };
  }

  static String calorieTextFor(
    FoodSuggestion? suggestion,
    List<String> selectedAddables,
  ) {
    if (suggestion == null) {
      final extra = extraCaloriesFor(selectedAddables);
      return extra > 0 ? 'Ekstralar yaklaşık +$extra kcal' : '';
    }
    final extra = extraCaloriesFor(selectedAddables);
    final min = suggestion.calorieMin + extra;
    final max = suggestion.calorieMax + extra;
    return extra > 0
        ? 'Yaklaşık $min-$max kcal (ekstralar dahil)'
        : suggestion.calorieText;
  }

  static String celiacWarning(List<String> allergens) {
    return allergens.contains('Gluten')
        ? 'Gluten içerir. Çölyak hastaları ve gluten hassasiyeti olanlar için uygun olmayabilir.'
        : '';
  }

  static FoodSuggestion? findSuggestionByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final normalized = _normalize(name);
    for (final item in suggestions) {
      if (_normalize(item.name) == normalized) return item;
    }
    return null;
  }

  static List<FoodSuggestion> _uniqueSuggestions(
      Iterable<FoodSuggestion> list) {
    final seen = <String>{};
    final result = <FoodSuggestion>[];
    for (final item in list) {
      final key = _normalize(item.name);
      if (seen.add(key)) result.add(item);
    }
    return result;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }
}
