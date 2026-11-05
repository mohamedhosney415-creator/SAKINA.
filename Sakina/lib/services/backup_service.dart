import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/store.dart';
import 'favorites.dart';
import 'prayer_service.dart';

/// نسخة احتياطية كاملة: المفضلة، القرآن والختمة، الأذكار والتسبيح،
/// سجل الصلوات، والإعدادات. الملفات الصوتية المحمّلة لا تُدرج (تُعاد من الإنترنت).
class BackupService {
  static const format = 1;

  static String buildJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'SAKINA',
        'format': format,
        'exportedAt': DateTime.now().toIso8601String(),
        'data': Store.exportAll(),
      });

  static Future<File> exportFile() async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/sakina_backup_${dayKey(DateTime.now())}.json');
    await f.writeAsString(buildJson());
    return f;
  }

  static Future<void> share() async {
    final f = await exportFile();
    await Share.shareXFiles([XFile(f.path)], text: 'النسخة الاحتياطية لتطبيق سكينة');
  }

  /// يستعيد النسخة ويُعيد عدد العناصر. يرمي استثناء إذا كان الملف غير صالح.
  static Future<int> restore(String raw) async {
    final j = jsonDecode(raw);
    if (j is! Map || j['app'] != 'SAKINA' || j['data'] is! Map) {
      throw const FormatException('ملف غير صالح');
    }
    final data = Map<String, dynamic>.from(j['data'] as Map);
    await Store.importAll(data);
    await Store.remove('sched_key');
    Settings.i.load();
    Favorites.i.load();
    PrayerService.clearCache();
    return data.length;
  }
}
