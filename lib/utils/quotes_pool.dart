import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class QuotesPool {
  static final List<Map<String, String>> _defaultQuotes = [
    {
      "text": "Gönül ne kahve ister ne kahvehane, gönül sohbet ister kahve bahane.",
      "author": "Yunus Emre"
    },
    {
      "text": "Pazarcık'ın sıcak insanları ve kadim bereketi her daim hanenize dolsun.",
      "author": "Pazarcık Portal"
    },
    {
      "text": "Güzel bakan güzel görür, güzel gören hayatından lezzet alır.",
      "author": "Bediüzzaman"
    },
    {
      "text": "Komşusu açken tok yatan bizden değildir. Paylaşmak berekettir.",
      "author": "Hadis-i Şerif"
    },
    {
      "text": "Dostluk ve kardeşliğin şehri Pazarcık'ta her gün yeni bir umuttur.",
      "author": "Pazarcık Portal"
    },
    {
      "text": "Birlik ve beraberlik içinde aşılamayacak hiçbir engel yoktur.",
      "author": "Pazarcık Portal"
    },
    {
      "text": "Kalp kırmak Kabe yıkmak gibidir. Gönüller yapmaya geldik.",
      "author": "Yunus Emre"
    },
    {
      "text": "Sevgi emek ister; memleket ise vefa ve dayanışma ister.",
      "author": "Pazarcık Portal"
    },
    {
      "text": "Tebessüm sadakadır. Hemşehrinize bir tebessümü çok görmeyin.",
      "author": "Hadis-i Şerif"
    },
    {
      "text": "Doğruluk ve dürüstlük en büyük sermayedir. Hayırlı ve bereketli kazançlar.",
      "author": "Pazarcık Esnafı"
    },
    {
      "text": "Güneşin ve tarihin kucağında, Pazarcık'ta her sabah yeni bir güzelliktir.",
      "author": "Pazarcık Portal"
    },
    {
      "text":"İyilik İyidir",
      "author": "Anonim"
    },
    {
      "text": "İncinsen de incitme.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "Eline, beline, diline sahip ol.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "Bilimden gidilmeyen yolun sonu karanlıktır.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "Okunacak en büyük kitap insandır.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "Oturduğun yeri pak et, kazandığın lokmayı hak et.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "Hararet nardadır sacda değildir, keramet baştadır tacda değildir.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "Her ne arar isen kendinde ara, Kudüs'te, Mekke'de, Hac'da değildir.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "Düşmanınızın dahi insan olduğunu unutmayın.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "Dili, dini, rengi ne olursa olsun iyiler iyidir.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "En büyük keramet çalışmaktır.",
      "author": "Hacı Bektaş Veli"
    },
    {
      "text": "Gelin canlar bir olalım.",
      "author": "Pir Sultan Abdal"
    },
    {
      "text": "Dönen dönsün ben dönmezem yolumdan.",
      "author": "Pir Sultan Abdal"
    },
    {
      "text": "Cehennem dediğin dal odun yoktur, herkes ateşini buradan götürür.",
      "author": "Pir Sultan Abdal"
    },
    {
      "text": "Bozuk düzende sağlam çark olmaz.",
      "author": "Pir Sultan Abdal"
    },
    {
      "text": "Kadılar müftüler fetva yazarsa, işte kement, işte boynum, asarsa.",
      "author": "Pir Sultan Abdal"
    },
    {
      "text": "Haksızlığa karşı eğilmeyiniz; çünkü hakkınızla beraber şerefinizi de kaybedersiniz.",
      "author": "Hz. Ali"
    },
    {
      "text": "Mazlumun zalimden öcünü alacağı gün, zalimin zulmettiği günden daha çetin olacaktır.",
      "author": "Hz. Ali"
    },
    {
      "text": "Bin zulme uğrasan da, bir zulüm yapma.",
      "author": "Hz. Ali"
    },
    {
      "text": "Kendini tanıyan, Rabbini de tanır.",
      "author": "Hz. Ali"
    },
    {
      "text": "Gören göze karanlık yok, yoktan öte karanlık yok.",
      "author": "Seyyid Nesîmî"
    },
    {
      "text": "Bende sığar iki cihân, ben bu cihâna sığmazam.",
      "author": "Seyyid Nesîmî"
    },
    {
      "text": "Bir olalım, iri olalım, diri olalım.",
      "author": "Hacı Bektaş Veli"
    },
    {
    "text": "Yol cümleden uludur.",
    "author": "Anonim"
  },
  {
    "text": "Gönül kalsın, yol kalmasın.",
    "author": "Anonim"
  },
  {
    "text": "Yolumuz sevgi, kıblemiz insandır.",
    "author": "Anonim"
  },
  {
    "text": "Adam olmak bir pula, insan olmak bin yıla.",
    "author": "Anonim"
  },
  {
    "text": "Özü doğru olanın, sözü de doğru olur.",
    "author": "Anonim"
  },
  {
    "text": "Aşk ile yürüyen yorulmaz.",
    "author": "Anonim"
  },
  {
    "text": "Kendine revâ görmediğini başkasına görme.",
    "author": "Anonim"
  },
  {
    "text": "Gözüyle görmediğine şahitlik etme.",
    "author": "Anonim"
  },
  {
    "text": "Sözü süz de söyle, manayı diz de söyle.",
    "author": "Anonim"
  },
  {
    "text": "Dostun gülü yara açmaz.",
    "author": "Anonim"
  },
  {
    "text": "Erkeğin de dişinin de canı birdir.",
    "author": "Anonim"
  },
  {
    "text": "Gönül evini temiz tut ki, mihman gelsin.",
    "author": "Anonim"
  },
  {
    "text": "Eksiklik kendi özümüzdedir, darda değil.",
    "author": "Anonim"
  },
  {
    "text": "Gündüz şevk ile, gece aşk ile.",
    "author": "Anonim"
  },
  {
    "text": "Hakk'ı uzakta arama, Hak senin içindedir.",
    "author": "Anonim"
  },
  ];

  static Map<String, String>? _cachedRandomQuote;

  /// Rastgele bir güzel söz döner.
  static Map<String, String> getRandomQuoteSync({bool forceNew = false}) {
    final random = Random();
    if (_cachedRandomQuote != null && !forceNew) return _cachedRandomQuote!;
    
    // Aynı sözün üst üste gelmesini engelle
    Map<String, String> candidate;
    int tries = 0;
    do {
      candidate = _defaultQuotes[random.nextInt(_defaultQuotes.length)];
      tries++;
    } while (_cachedRandomQuote != null &&
        candidate['text'] == _cachedRandomQuote!['text'] &&
        _defaultQuotes.length > 1 &&
        tries < 5);

    _cachedRandomQuote = candidate;
    return _cachedRandomQuote!;
  }

  /// Firebase Firestore'dan (app_settings/quotes_pool) varsa canlı havuzu çeker, yoksa yerel havuzu kullanır.
  static Future<Map<String, String>> fetchRandomQuote({bool forceRefresh = false}) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('quotes_pool')
          .get();

      if (doc.exists && doc.data() != null) {
        final List<dynamic>? remoteList = doc.data()!['quotes'];
        if (remoteList != null && remoteList.isNotEmpty) {
          final random = Random();
          final validQuotes = remoteList
              .whereType<Map>()
              .map((item) => {
                    "text": (item['text'] ?? '').toString(),
                    "author": (item['author'] ?? 'Pazarcık Portal').toString(),
                  })
              .where((q) => q["text"]!.isNotEmpty)
              .toList();

          if (validQuotes.isNotEmpty) {
            Map<String, String> candidate;
            int tries = 0;
            do {
              candidate = validQuotes[random.nextInt(validQuotes.length)];
              tries++;
            } while (_cachedRandomQuote != null &&
                candidate['text'] == _cachedRandomQuote!['text'] &&
                validQuotes.length > 1 &&
                tries < 5);

            _cachedRandomQuote = candidate;
            return candidate;
          }
        }
      }
    } catch (e) {
      debugPrint("Quotes pool fetch error: $e");
    }
    return getRandomQuoteSync(forceNew: forceRefresh);
  }
}
