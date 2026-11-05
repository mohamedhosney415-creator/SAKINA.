import 'package:flutter/foundation.dart';
import 'store.dart';
import '../data/cities.dart';

/// إعدادات التطبيق (مخزنة كلها في مفتاح واحد لسهولة النسخ الاحتياطي).
class Settings extends ChangeNotifier {
  static final Settings i = Settings._();
  Settings._();

  Map<String, dynamic> _m = {};

  void load() {
    final j = Store.json('settings');
    _m = j is Map ? Map<String, dynamic>.from(j) : {};
    notifyListeners();
  }

  bool _b(String k, bool d) => _m[k] is bool ? _m[k] as bool : d;
  int _i(String k, int d) => _m[k] is num ? (_m[k] as num).toInt() : d;
  double _d(String k, double d) => _m[k] is num ? (_m[k] as num).toDouble() : d;
  String _s(String k, String d) => _m[k] is String ? _m[k] as String : d;

  Future<void> set(String k, dynamic v) async {
    _m[k] = v;
    notifyListeners();
    await Store.setJson('settings', _m);
  }

  int intOf(String k, int d) => _i(k, d);

  // ---------- المظهر ----------
  int get themeMode => _i('themeMode', 0); // 0 النظام 1 فاتح 2 داكن
  int get accent => _i('accent', 0);
  double get fontScale => _d('fontScale', 1.0);
  String get font => _s('font', 'Cairo');
  bool get arabicDigits => _b('arabicDigits', true);
  String get userName => _s('userName', '');

  // ---------- الموقع ----------
  String get gov => _s('gov', 'القاهرة');
  String get cityName => _s('city', 'القاهرة');
  City get city => Cities.find(gov, cityName);

  // ---------- المواقيت ----------
  int get hijriOffset => _i('hijriOffset', 0);
  int offset(String prayerKey) => _i('off_$prayerKey', 0);

  // ---------- الأذان والتنبيهات ----------
  bool get notificationsOn => _b('notifOn', true);
  bool get adhanOn => _b('adhanOn', true);
  bool adhanFor(String prayerKey) => _b('adhan_$prayerKey', true);
  bool get reminderOn => _b('reminderOn', true);
  int get reminderMinutes => _i('reminderMin', 10);
  String get muezzin => _s('muezzin', 'afasy');
  double get volume => _d('volume', 1.0);
  bool get vibrate => _b('vibrate', true);
  bool get ramadanAlerts => _b('ramadanAlerts', true);
  bool get eventAlerts => _b('eventAlerts', true);

  // ---------- القرآن ----------
  String get reciter => _s('reciter', 'afasy');
  double get quranFont => _d('quranFont', 26);
  bool get autoNext => _b('autoNext', false);

  // ---------- نور يومك ----------
  int get noorMode => _i('noorMode', 0); // 0 تناوب 1 حديث 2 حكمة 3 عشوائي

  // ---------- المسبحة ----------
  bool get haptic => _b('haptic', true);

  // ---------- الختمة ----------
  bool get khatmaReminder => _b('khatmaReminder', false);
  int get khatmaHour => _i('khatmaHour', 20);
  int get khatmaMinute => _i('khatmaMinute', 0);

  /// بصمة الإعدادات المؤثرة على جدولة التنبيهات.
  String get scheduleSignature {
    final keys = _m.keys
        .where((k) =>
            k.startsWith('off_') ||
            k.startsWith('adhan_') ||
            const [
              'gov', 'city', 'notifOn', 'adhanOn', 'reminderOn', 'reminderMin',
              'muezzin', 'vibrate', 'ramadanAlerts', 'eventAlerts',
              'hijriOffset', 'khatmaReminder', 'khatmaHour', 'khatmaMinute'
            ].contains(k))
        .toList()
      ..sort();
    return keys.map((k) => '$k=${_m[k]}').join('&');
  }
}
