import 'package:hijri/hijri_calendar.dart';
import 'settings.dart';

const _latin = '0123456789';
const _arabic = '٠١٢٣٤٥٦٧٨٩';

/// يحوّل الأرقام للعربية حسب إعداد المستخدم.
String ar(Object v) {
  final s = '$v';
  if (!Settings.i.arabicDigits) return s;
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = _latin.indexOf(ch);
    b.write(i >= 0 ? _arabic[i] : ch);
  }
  return b.toString();
}

const weekdays = [
  'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
];
const gregMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];
const hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
];

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return ar('$h:$m ${d.hour < 12 ? 'ص' : 'م'}');
}

String fmtDur(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return ar('$h:$m:$s');
}

String fmtDurWords(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '${ar(m)} دقيقة';
  if (m == 0) return '${ar(h)} ساعة';
  return '${ar(h)} ساعة و${ar(m)} دقيقة';
}

String fmtDate(DateTime d) =>
    '${weekdays[d.weekday - 1]} ${ar(d.day)} ${gregMonths[d.month - 1]} ${ar(d.year)}';

String fmtShortDate(DateTime d) => ar('${d.day}/${d.month}/${d.year}');

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

// ---------- الهجري ----------
HijriCalendar hijriOf(DateTime d) => HijriCalendar.fromDate(
    DateTime(d.year, d.month, d.day + Settings.i.hijriOffset));

String fmtHijri(DateTime d) {
  final h = hijriOf(d);
  return '${ar(h.hDay)} ${hijriMonths[h.hMonth - 1]} ${ar(h.hYear)} هـ';
}

/// التاريخ الميلادي المقابل ليوم هجري (مع مراعاة فرق الإعدادات).
DateTime gregOfHijri(int y, int m, int d) {
  final g = HijriCalendar().hijriToGregorian(y, m, d);
  return DateTime(g.year, g.month, g.day - Settings.i.hijriOffset);
}

int hijriMonthLength(int y, int m) {
  final ny = m == 12 ? y + 1 : y;
  final nm = m == 12 ? 1 : m + 1;
  return gregOfHijri(ny, nm, 1).difference(gregOfHijri(y, m, 1)).inDays;
}

/// عدد الأيام بين تاريخين (بالتقويم، بغض النظر عن التوقيت الصيفي).
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
