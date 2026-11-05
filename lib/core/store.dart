import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين محلي بسيط. كل مفاتيح التطبيق تبدأ بـ "sk." لتُدرج في النسخ الاحتياطي.
class Store {
  static late SharedPreferences _p;
  static const prefix = 'sk.';

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static String _k(String k) => '$prefix$k';

  static String str(String k, [String def = '']) => _p.getString(_k(k)) ?? def;
  static int integer(String k, [int def = 0]) => _p.getInt(_k(k)) ?? def;
  static bool flag(String k, [bool def = false]) => _p.getBool(_k(k)) ?? def;

  static Future<void> setStr(String k, String v) => _p.setString(_k(k), v);
  static Future<void> setInt(String k, int v) => _p.setInt(_k(k), v);
  static Future<void> setFlag(String k, bool v) => _p.setBool(_k(k), v);
  static Future<void> remove(String k) => _p.remove(_k(k));

  static dynamic json(String k, [dynamic def]) {
    final s = _p.getString(_k(k));
    if (s == null) return def;
    try {
      return jsonDecode(s);
    } catch (_) {
      return def;
    }
  }

  static Future<void> setJson(String k, dynamic v) =>
      _p.setString(_k(k), jsonEncode(v));

  /// يُصدّر كل بيانات المستخدم (بدون الملفات المؤقتة).
  static const _volatile = {'sched_key'};

  static Map<String, dynamic> exportAll() {
    final m = <String, dynamic>{};
    for (final k in _p.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      final name = k.substring(prefix.length);
      if (_volatile.contains(name)) continue;
      m[name] = _p.get(k);
    }
    return m;
  }

  static Future<void> importAll(Map<String, dynamic> m) async {
    for (final e in m.entries) {
      final v = e.value;
      final k = _k(e.key);
      if (v is String) {
        await _p.setString(k, v);
      } else if (v is bool) {
        await _p.setBool(k, v);
      } else if (v is int) {
        await _p.setInt(k, v);
      } else if (v is double) {
        await _p.setDouble(k, v);
      } else if (v is List) {
        await _p.setStringList(k, v.map((x) => '$x').toList());
      }
    }
  }
}
