import '../core/format.dart';
import '../core/store.dart';
import 'prayer_service.dart';

/// سجل أداء الصلوات الخمس (محلي وخاص).
class PrayerLog {
  static Map<String, dynamic> _all() {
    final j = Store.json('plog', {});
    return j is Map ? Map<String, dynamic>.from(j) : {};
  }

  static bool done(DateTime d, Prayer p) {
    final m = _all()[dayKey(d)];
    return m is Map && m[p.name] == true;
  }

  static Future<void> toggle(DateTime d, Prayer p) async {
    final all = _all();
    final k = dayKey(d);
    final m = all[k] is Map ? Map<String, dynamic>.from(all[k]) : <String, dynamic>{};
    if (m[p.name] == true) {
      m.remove(p.name);
    } else {
      m[p.name] = true;
    }
    if (m.isEmpty) {
      all.remove(k);
    } else {
      all[k] = m;
    }
    await Store.setJson('plog', all);
  }

  static int countDay(DateTime d) =>
      fardPrayers.where((p) => done(d, p)).length;

  /// عدد الصلوات المؤداة خلال [days] يومًا تنتهي بـ [last].
  static int doneInRange(DateTime last, int days) {
    final all = _all();
    int c = 0;
    for (int i = 0; i < days; i++) {
      final d = DateTime(last.year, last.month, last.day - i);
      final m = all[dayKey(d)];
      if (m is Map) c += fardPrayers.where((p) => m[p.name] == true).length;
    }
    return c;
  }

  /// أيام متتالية اكتملت فيها الصلوات الخمس.
  static int streak(DateTime today) {
    int s = 0;
    var d = DateTime(today.year, today.month, today.day);
    if (countDay(d) < 5) d = DateTime(d.year, d.month, d.day - 1);
    while (countDay(d) == 5) {
      s++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return s;
  }
}
