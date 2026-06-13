const List<String> pazarcikDeliveryNeighborhoods = [
  '15 Temmuz Mahallesi',
  'Ahmet Bozdağ Mahallesi',
  'Akçakoyunlu Mahallesi',
  'Akçalar Mahallesi',
  'Akdemir Mahallesi',
  'Armutlu Mahallesi',
  'Aşağımülk Mahallesi',
  'Bağdınısağır Mahallesi',
  'Beşçeşme Mahallesi',
  'Bölükçam Mahallesi',
  'Büyüknacar Fatih Mahallesi',
  'Büyüknacar Kocadere Mahallesi',
  'Büyüknacar Merkez Mahallesi',
  'Camlıca Mahallesi',
  'Cengiztopel Mahallesi',
  'Cimikanlı Mahallesi',
  'Çamlıtepe Mahallesi',
  'Çiçek Mahallesi',
  'Çiçekalanı Mahallesi',
  'Çiğdemtepe Mahallesi',
  'Çöçelli Mahallesi',
  'Damlataş Mahallesi',
  'Dedepaşa Mahallesi',
  'Eğlen Mahallesi',
  'Eğrice Mahallesi',
  'Emiroğlu Mahallesi',
  'Evri Pınarbaşı Mahallesi',
  'Evri Taşbiçme Mahallesi',
  'Fatih Mahallesi',
  'Ganidağıketiler Mahallesi',
  'Göçer Mahallesi',
  'Göynük Mahallesi',
  'Hanobası Mahallesi',
  'Harmancık Mahallesi',
  'Hasankoca Mahallesi',
  'Hürriyet Mahallesi',
  'İncirli Mahallesi',
  'Kadıncık Mahallesi',
  'Karaağaç Mahallesi',
  'Karabıyıklı Mahallesi',
  'Karaçay Mahallesi',
  'Karagöl Mahallesi',
  'Karahüyük Mahallesi',
  'Keleş Mahallesi',
  'Kızkapanlı Mahallesi',
  'Kizirli Mahallesi',
  'Kuzeykent Mahallesi',
  'Mehmet Emin Arıkoğlu Mahallesi',
  'Memiş Özdal Mahallesi',
  'Memişkahya Mahallesi',
  'Menderes Mahallesi',
  'Mezere Mahallesi',
  'Musolar Mahallesi',
  'Narlı Bahçeli Evler Mahallesi',
  'Narlı Cumhuriyet Mahallesi',
  'Narlı İsmetpaşa Mahallesi',
  'Nefsidoğanlı Mahallesi',
  'Osmandede Mahallesi',
  'Ördekdede Mahallesi',
  'Sadakalar Mahallesi',
  'Sakarkaya Mahallesi',
  'Salmanlı Mahallesi',
  'Salmanıpak Mahallesi',
  'Sarıerik Mahallesi',
  'Sarıl Mahallesi',
  'Soku Mahallesi',
  'Sultanlar Mahallesi',
  'Şahintepe Mahallesi',
  'Şallıuşağı Mahallesi',
  'Şehit Nurettin Ademoğlu Mahallesi',
  'Taşdemir Mahallesi',
  'Tetirlik Mahallesi',
  'Tilkiler Mahallesi',
  'Turunçul Mahallesi',
  'Ufacıklı Mahallesi',
  'Ulubahçe Mahallesi',
  'Yarbaşı Mahallesi',
  'Yeşilkent Mahallesi',
  'Yiğitler Mahallesi',
  'Yolboyu Mahallesi',
  'Yukarıhöcüklü Mahallesi',
  'Yukarımülk Mahallesi',
  'Yumaklıcerit Bağlar Mahallesi',
  'Yumaklıcerit Cumhuriyet Mahallesi',
];

List<String> readDeliveryNeighborhoods(Object? rawZones) {
  if (rawZones is! Iterable) return List.of(pazarcikDeliveryNeighborhoods);

  final neighborhoods = <String>{};
  for (final zone in rawZones) {
    Object? value;
    if (zone is Map) {
      value = zone['neighborhood'] ?? zone['mahalle'] ?? zone['name'];
    } else {
      value = zone;
    }

    final neighborhood = value?.toString().trim() ?? '';
    if (neighborhood.isNotEmpty && neighborhood.toLowerCase() != 'null') {
      neighborhoods.add(neighborhood);
    }
  }

  final result = neighborhoods.toList()..sort();
  return result.isEmpty ? List.of(pazarcikDeliveryNeighborhoods) : result;
}
