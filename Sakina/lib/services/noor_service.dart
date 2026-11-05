import 'dart:math';
import '../core/settings.dart';
import '../data/hadiths.dart';
import '../data/wisdom.dart';

class NoorItem {
  final String kind; // hadith | wisdom
  final String id, text, by, source, grade;
  const NoorItem(this.kind, this.id, this.text, this.by, this.source, this.grade);

  String get label => kind == 'hadith' ? 'حديث اليوم' : 'حكمة اليوم';
  String get favType => kind;
  String get sourceLine => kind == 'hadith'
      ? '$by • $source • الدرجة: $grade'
      : '$by • $source';

  static NoorItem fromHadith(Hadith h) =>
      NoorItem('hadith', h.id, h.text, h.narrator, h.source, h.grade);
  static NoorItem fromWisdom(Wisdom w) =>
      NoorItem('wisdom', w.id, w.text, w.author, w.source, '');
}

/// اختيار يومي ثابت (لا يتغير بإعادة فتح التطبيق، ولا يتكرر بالأمس).
class NoorService {
  static int _epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  static NoorItem forDay(DateTime d, {int? mode}) {
    final m = mode ?? Settings.i.noorMode;
    final e = _epochDay(d);
    switch (m) {
      case 1:
        return NoorItem.fromHadith(hadiths[e % hadiths.length]);
      case 2:
        return NoorItem.fromWisdom(wisdoms[e % wisdoms.length]);
      case 3:
        return _random(e);
      default:
        return e.isEven
            ? NoorItem.fromHadith(hadiths[(e ~/ 2) % hadiths.length])
            : NoorItem.fromWisdom(wisdoms[(e ~/ 2) % wisdoms.length]);
    }
  }

  static int _randIndex(int e) {
    final total = hadiths.length + wisdoms.length;
    return Random(e * 7919 + 13).nextInt(total);
  }

  static NoorItem _random(int e) {
    final total = hadiths.length + wisdoms.length;
    var i = _randIndex(e);
    if (i == _randIndex(e - 1)) i = (i + 1) % total;
    return i < hadiths.length
        ? NoorItem.fromHadith(hadiths[i])
        : NoorItem.fromWisdom(wisdoms[i - hadiths.length]);
  }
}
