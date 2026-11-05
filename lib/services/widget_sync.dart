import 'package:home_widget/home_widget.dart';
import '../core/format.dart';
import '../core/settings.dart';
import 'prayer_service.dart';

/// يرسل بيانات المواقيت لويدجت الشاشة الرئيسية.
class WidgetSync {
  static Future<void> update() async {
    try {
      final now = cairoNow();
      final parts = <String>[];
      for (int d = 0; d < 5; d++) {
        final date = DateTime(now.year, now.month, now.day + d);
        final day = PrayerService.forDate(date);
        for (final p in fardPrayers) {
          parts.add('${prayerAr[p]},${day.t[p]!.millisecondsSinceEpoch}');
        }
      }
      await HomeWidget.saveWidgetData<String>('upcoming', parts.join(';'));
      await HomeWidget.saveWidgetData<String>('hijri', fmtHijri(now));
      await HomeWidget.saveWidgetData<String>('city', Settings.i.cityName);
      await HomeWidget.updateWidget(androidName: 'SakinaWidgetProvider');
    } catch (_) {}
  }
}
