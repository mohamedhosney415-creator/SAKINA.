import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/format.dart';
import '../core/settings.dart';
import '../core/store.dart';
import 'events_service.dart';
import 'prayer_service.dart';
import 'widget_sync.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

class Muezzin {
  final String id, label;
  final String assetPath;
  final String? fajrAssetPath;
  const Muezzin(this.id, this.label, this.assetPath, this.fajrAssetPath);
  bool get hasFajr => fajrAssetPath != null;
}

/// يكتشف ملفات الأذان الموجودة في assets/adhan وقت البناء.
/// الاسم: afasy.mp3 للأذان العادي، و afasy_fajr.mp3 لأذان الفجر.
class AdhanAudio {
  static const labels = {'afasy': 'الشيخ مشاري العفاسي'};
  static List<Muezzin>? _cache;

  static Future<List<Muezzin>> muezzins() async {
    if (_cache != null) return _cache!;
    final byName = <String, String>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final a in manifest.listAssets()) {
        if (!a.startsWith('assets/adhan/')) continue;
        final file = a.split('/').last;
        final dot = file.lastIndexOf('.');
        if (dot <= 0) continue;
        final ext = file.substring(dot + 1).toLowerCase();
        if (!const ['mp3', 'ogg', 'wav', 'm4a'].contains(ext)) continue;
        byName[Uri.decodeComponent(file.substring(0, dot))] = a;
      }
    } catch (_) {}
    final res = <Muezzin>[];
    for (final e in byName.entries) {
      if (e.key.endsWith('_fajr')) continue;
      res.add(Muezzin(e.key, labels[e.key] ?? e.key, e.value,
          byName['${e.key}_fajr']));
    }
    res.sort((a, b) =>
        a.id == 'afasy' ? -1 : (b.id == 'afasy' ? 1 : a.id.compareTo(b.id)));
    _cache = res;
    return res;
  }

  static Future<Muezzin?> selected() async {
    final list = await muezzins();
    for (final m in list) {
      if (m.id == Settings.i.muezzin) return m;
    }
    return list.isEmpty ? null : list.first;
  }
}

class NotificationService {
  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    } catch (_) {}
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notificationsPlugin
        .initialize(const InitializationSettings(android: android));
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<bool> notificationsAllowed() async =>
      (await _android?.areNotificationsEnabled()) ?? true;

  static Future<bool> exactAllowed() async {
    try {
      return (await _android?.canScheduleExactNotifications()) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestPermissions() async {
    bool ok = true;
    try {
      ok = (await _android?.requestNotificationsPermission()) ?? true;
    } catch (_) {}
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
    return ok;
  }

  // ---------- تفاصيل الإشعارات ----------
  static NotificationDetails _adhanDetails(
      Prayer p, Muezzin? m, String body) {
    final vib = Settings.i.vibrate;
    String? raw;
    if (m != null) raw = (p == Prayer.fajr && m.hasFajr) ? '${m.id}_fajr' : m.id;
    final channel = 'adhan_${raw ?? 'default'}_${vib ? 'v' : 'n'}';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        'الأذان',
        channelDescription: 'تنبيه دخول وقت الصلاة مع الأذان',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: raw == null ? null : RawResourceAndroidNotificationSound(raw),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        enableVibration: vib,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
  }

  static NotificationDetails _reminderDetails(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          'sakina_reminder',
          'تذكير قبل الصلاة',
          channelDescription: 'تذكير قبل دخول وقت الصلاة',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static NotificationDetails _generalDetails(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          'sakina_general',
          'تنبيهات سكينة',
          channelDescription: 'السحور والإفطار والمناسبات وتذكير الورد',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  static Future<void> _at(int id, String title, String body,
      tz.TZDateTime when, NotificationDetails d, AndroidScheduleMode mode,
      {DateTimeComponents? repeat}) async {
    try {
      await notificationsPlugin.zonedSchedule(id, title, body, when, d,
          androidScheduleMode: mode, matchDateTimeComponents: repeat);
    } catch (_) {}
  }

  // ---------- الجدولة ----------
  /// يعيد الجدولة إذا تغيّر اليوم أو الإعدادات.
  static Future<void> ensureScheduled({bool force = false}) async {
    final key = '${dayKey(cairoNow())}|${Settings.i.scheduleSignature}';
    if (!force && Store.str('sched_key') == key) {
      await WidgetSync.update();
      return;
    }
    await rescheduleAll();
    await Store.setStr('sched_key', key);
    await WidgetSync.update();
  }

  /// يجدول الأذان لأربعة عشر يومًا قادمة، ويُعاد تلقائيًا كلما فُتح التطبيق.
  static Future<void> rescheduleAll() async {
    final s = Settings.i;
    PrayerService.clearCache();
    try {
      await notificationsPlugin.cancelAll();
    } catch (_) {}
    if (!s.notificationsOn) return;

    final mode = (await exactAllowed())
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final muezzin = await AdhanAudio.selected();
    final now = cairoNow();

    for (int d = 0; d < 14; d++) {
      final date = DateTime(now.year, now.month, now.day + d);
      final day = PrayerService.forDate(date);

      for (int i = 0; i < fardPrayers.length; i++) {
        final p = fardPrayers[i];
        final at = day.t[p]!;
        final name = prayerAr[p]!;
        if (s.adhanOn && s.adhanFor(p.name) && at.isAfter(now)) {
          final body = 'حان الآن موعد أذان $name حسب توقيت ${s.cityName}';
          await _at(d * 20 + i * 3, 'حان وقت صلاة $name', body, at,
              _adhanDetails(p, muezzin, body), mode);
        }
        if (s.reminderOn && s.adhanFor(p.name)) {
          final r = at.subtract(Duration(minutes: s.reminderMinutes));
          if (r.isAfter(now)) {
            final body =
                'بقي ${fmtDurWords(Duration(minutes: s.reminderMinutes))} على صلاة $name';
            await _at(d * 20 + i * 3 + 1, 'اقترب وقت $name', body, r,
                _reminderDetails(body), mode);
          }
        }
      }

      // السحور والإفطار في رمضان
      if (s.ramadanAlerts && hijriOf(date).hMonth == 9) {
        final suhoor = day.t[Prayer.fajr]!.subtract(const Duration(minutes: 30));
        if (suhoor.isAfter(now)) {
          const body = 'بقي نصف ساعة على أذان الفجر، تسحّروا فإن في السحور بركة.';
          await _at(1000 + d * 2, 'وقت السحور', body, suhoor,
              _generalDetails(body), mode);
        }
        final iftar = day.t[Prayer.maghrib]!.subtract(const Duration(minutes: 10));
        if (iftar.isAfter(now)) {
          const body = 'بقي عشر دقائق على الإفطار، فاغتنم وقت الدعاء.';
          await _at(1001 + d * 2, 'اقترب الإفطار', body, iftar,
              _generalDetails(body), mode);
        }
      }
    }

    // المناسبات الإسلامية القادمة
    if (s.eventAlerts) {
      final evs = EventsService.upcoming(now, horizonDays: 60);
      for (int i = 0; i < evs.length && i < 12; i++) {
        final e = evs[i];
        final when = cairoDate(e.date.year, e.date.month, e.date.day, 8, 0);
        if (when.isAfter(now)) {
          await _at(2000 + i, e.event.title, e.event.note, when,
              _generalDetails(e.event.note), mode);
        }
      }
    }

    // تذكير الورد اليومي
    if (s.khatmaReminder) {
      var when = cairoDate(now.year, now.month, now.day, s.khatmaHour, s.khatmaMinute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      const body = 'حان وقت وردك من القرآن الكريم، قليل دائم خير من كثير منقطع.';
      await _at(3000, 'وردك اليومي', body, when, _generalDetails(body), mode,
          repeat: DateTimeComponents.time);
    }
  }

  /// إشعار فوري بنفس قناة الأذان لاختبار الصوت.
  static Future<void> testAdhanNotification() async {
    final m = await AdhanAudio.selected();
    const body = 'هذا اختبار لصوت الأذان في الإشعارات.';
    await notificationsPlugin.show(
        9999, 'تجربة الأذان', body, _adhanDetails(Prayer.dhuhr, m, body));
  }
}
