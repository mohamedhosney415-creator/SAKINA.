import 'package:adhan/adhan.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/settings.dart';
import '../data/cities.dart';

enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

const fardPrayers = [
  Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha
];

const prayerAr = {
  Prayer.fajr: 'الفجر',
  Prayer.sunrise: 'الشروق',
  Prayer.dhuhr: 'الظهر',
  Prayer.asr: 'العصر',
  Prayer.maghrib: 'المغرب',
  Prayer.isha: 'العشاء',
};

String prayerKey(Prayer p) => p.name;

/// الوقت الحالي بتوقيت القاهرة (يتبع التوقيت الصيفي تلقائيًا).
tz.TZDateTime cairoNow() => tz.TZDateTime.now(tz.getLocation('Africa/Cairo'));

tz.TZDateTime cairoDate(int y, int m, int d, [int h = 0, int mi = 0]) =>
    tz.TZDateTime(tz.getLocation('Africa/Cairo'), y, m, d, h, mi);

class DayTimes {
  final DateTime date;
  final Map<Prayer, tz.TZDateTime> t;
  DayTimes(this.date, this.t);
}

class NextPrayer {
  final Prayer prayer;
  final tz.TZDateTime at;
  NextPrayer(this.prayer, this.at);
}

/// حساب المواقيت محليًا بطريقة الهيئة المصرية العامة للمساحة
/// (الفجر 19.5° والعشاء 17.5°) — يعمل بدون إنترنت.
class PrayerService {
  static final Map<String, DayTimes> _memo = {};

  static String _sig(DateTime d, City c) {
    final s = Settings.i;
    final off = Prayer.values.map((p) => s.offset(p.name)).join(',');
    return '${d.year}-${d.month}-${d.day}|${c.lat},${c.lng}|$off';
  }

  static DayTimes forDate(DateTime date, {City? city}) {
    final c = city ?? Settings.i.city;
    final key = _sig(date, c);
    final hit = _memo[key];
    if (hit != null) return hit;

    final params = CalculationMethod.egyptian.getParameters();
    params.madhab = Madhab.shafi;
    final pt = PrayerTimes(Coordinates(c.lat, c.lng),
        DateComponents(date.year, date.month, date.day), params);

    final cairo = tz.getLocation('Africa/Cairo');
    tz.TZDateTime conv(DateTime t, Prayer p) {
      final base = tz.TZDateTime.from(t, cairo);
      return base.add(Duration(minutes: Settings.i.offset(p.name)));
    }

    final map = <Prayer, tz.TZDateTime>{
      Prayer.fajr: conv(pt.fajr, Prayer.fajr),
      Prayer.sunrise: conv(pt.sunrise, Prayer.sunrise),
      Prayer.dhuhr: conv(pt.dhuhr, Prayer.dhuhr),
      Prayer.asr: conv(pt.asr, Prayer.asr),
      Prayer.maghrib: conv(pt.maghrib, Prayer.maghrib),
      Prayer.isha: conv(pt.isha, Prayer.isha),
    };
    final res = DayTimes(date, map);
    if (_memo.length > 400) _memo.clear();
    _memo[key] = res;
    return res;
  }

  static void clearCache() => _memo.clear();

  /// الصلاة القادمة (من الصلوات الخمس + الشروق لا يُحتسب).
  static NextPrayer next([DateTime? from]) {
    final now = from ?? cairoNow();
    for (int d = 0; d < 3; d++) {
      final date = DateTime(now.year, now.month, now.day + d);
      final day = forDate(date);
      for (final p in fardPrayers) {
        final at = day.t[p]!;
        if (at.isAfter(now)) return NextPrayer(p, at);
      }
    }
    final day = forDate(DateTime(now.year, now.month, now.day + 1));
    return NextPrayer(Prayer.fajr, day.t[Prayer.fajr]!);
  }

  /// الصلاة الحالية (آخر صلاة دخل وقتها) أو null قبل الفجر.
  static Prayer? current([DateTime? from]) {
    final now = from ?? cairoNow();
    final day = forDate(DateTime(now.year, now.month, now.day));
    Prayer? cur;
    for (final p in fardPrayers) {
      if (!day.t[p]!.isAfter(now)) cur = p;
    }
    return cur;
  }
}
