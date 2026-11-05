import '../core/format.dart';
import '../core/store.dart';
import '../data/surahs.dart';

/// خطة الختمة: عدد الأيام، وسجل الصفحات المقروءة يوميًا (مصحف المدينة 604 صفحة).
class KhatmaStore {
  static Map<String, dynamic>? plan() {
    final j = Store.json('khatma');
    return j is Map ? Map<String, dynamic>.from(j) : null;
  }

  static int completed() => Store.integer('khatma_done', 0);

  static Future<void> create(int days) async {
    await Store.setJson('khatma', {
      'start': dayKey(DateTime.now()),
      'days': days.clamp(1, 3650),
      'log': <String, dynamic>{},
    });
  }

  static Future<void> cancel() => Store.remove('khatma');

  static Future<void> finish() async {
    await Store.setInt('khatma_done', completed() + 1);
    await Store.remove('khatma');
  }

  static DateTime startOf(Map<String, dynamic> p) {
    final s = (p['start'] as String).split('-').map(int.parse).toList();
    return DateTime(s[0], s[1], s[2]);
  }

  static int daysOf(Map<String, dynamic> p) => (p['days'] as num).toInt();

  static Map<String, dynamic> _log(Map<String, dynamic> p) =>
      p['log'] is Map ? Map<String, dynamic>.from(p['log']) : {};

  static int pagesRead(Map<String, dynamic> p) {
    int t = 0;
    for (final v in _log(p).values) {
      t += (v as num).toInt();
    }
    return t.clamp(0, totalMushafPages);
  }

  static int readOn(Map<String, dynamic> p, DateTime d) =>
      ((_log(p)[dayKey(d)] ?? 0) as num).toInt();

  /// الأيام المتبقية شاملة اليوم (لا تقل عن 1).
  static int daysLeft(Map<String, dynamic> p, DateTime today) {
    final end = DateTime(startOf(p).year, startOf(p).month,
        startOf(p).day + daysOf(p) - 1);
    return (daysBetween(today, end) + 1).clamp(1, 100000);
  }

  /// الورد المطلوب اليوم = المتبقي قبل اليوم ÷ الأيام المتبقية.
  static int wirdToday(Map<String, dynamic> p, DateTime today) {
    final before = pagesRead(p) - readOn(p, today);
    final remain = (totalMushafPages - before).clamp(0, totalMushafPages);
    final left = daysLeft(p, today);
    return (remain / left).ceil();
  }

  static Future<void> addPages(int delta, DateTime today) async {
    final p = plan();
    if (p == null) return;
    final log = _log(p);
    final k = dayKey(today);
    final cur = ((log[k] ?? 0) as num).toInt();
    final room = totalMushafPages - (pagesRead(p) - cur);
    log[k] = (cur + delta).clamp(0, room);
    p['log'] = log;
    await Store.setJson('khatma', p);
  }

  /// الأيام المنقضية منذ بدء الخطة (لمعرفة هل أنت متقدم أو متأخر).
  static int expectedPagesByNow(Map<String, dynamic> p, DateTime today) {
    final elapsed = (daysBetween(startOf(p), today) + 1).clamp(0, daysOf(p));
    return (totalMushafPages * elapsed / daysOf(p)).ceil();
  }
}
