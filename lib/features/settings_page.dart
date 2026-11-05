import 'package:flutter/material.dart';
import '../core/settings.dart';
import '../core/widgets.dart';
import '../services/notification_service.dart';
import '../services/quran_service.dart';
import 'about_page.dart';
import 'adhan_settings_page.dart';
import 'appearance_page.dart';
import 'backup_page.dart';
import 'city_picker.dart';
import 'downloads_page.dart';
import 'offsets_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _editName(BuildContext context) async {
    final c = TextEditingController(text: Settings.i.userName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('اسمك'),
        content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'يظهر في التحية بالصفحة الرئيسية')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) await Settings.i.set('userName', c.text.trim());
  }

  void _privacy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('الخصوصية'),
        content: const SingleChildScrollView(
          child: Text(
              'سكينة لا تجمع أي بيانات شخصية ولا تستخدم حسابات أو إعلانات أو أدوات تتبّع.\n\n'
              '• سجل صلواتك وختمتك ومفضلتك وإعداداتك محفوظة على هاتفك فقط.\n'
              '• لا يُطلب إذن الموقع (GPS)؛ تختار مدينتك يدويًا.\n'
              '• الإنترنت يُستخدم فقط لتحميل نص القرآن والتلاوات عند طلبك، ثم تُحفظ للاستخدام دون اتصال.\n'
              '• النسخة الاحتياطية ملف تتحكم أنت في مكان حفظه.',
              style: TextStyle(height: 1.8)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListenableBuilder(
        listenable: Settings.i,
        builder: (context, _) {
          final s = Settings.i;
          Future<void> sw(String k, bool v) async {
            await s.set(k, v);
            await NotificationService.ensureScheduled();
          }

          return ListView(children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('اسمك'),
              subtitle: Text(s.userName.isEmpty ? 'غير محدد' : s.userName),
              onTap: () => _editName(context),
            ),
            const SectionTitle('الصلاة والتنبيهات'),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('المدينة'),
              subtitle: Text('${s.gov} • ${s.cityName}'),
              onTap: () => go(context, const CityPickerPage()),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: const Text('إعدادات الأذان والمؤذن'),
              onTap: () => go(context, const AdhanSettingsPage()),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('ضبط فروق المواقيت والتاريخ الهجري'),
              onTap: () => go(context, const OffsetsPage()),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.restaurant),
              title: const Text('تنبيهات السحور والإفطار في رمضان'),
              value: s.ramadanAlerts,
              onChanged: (v) => sw('ramadanAlerts', v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.event),
              title: const Text('تنبيهات المناسبات الإسلامية'),
              value: s.eventAlerts,
              onChanged: (v) => sw('eventAlerts', v),
            ),
            const SectionTitle('المظهر'),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('الألوان والخط والوضع الداكن'),
              onTap: () => go(context, const AppearancePage()),
            ),
            const SectionTitle('القرآن'),
            ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('القارئ'),
              subtitle: Text(reciterById(s.reciter).name),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final r in reciters)
                        ListTile(
                          title: Text(r.name),
                          trailing: s.reciter == r.id ? const Icon(Icons.check) : null,
                          onTap: () {
                            s.set('reciter', r.id);
                            Navigator.pop(context);
                          },
                        ),
                    ]),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: const Text('حجم خط المصحف'),
              subtitle: Slider(
                value: s.quranFont,
                min: 20,
                max: 42,
                divisions: 11,
                onChanged: (v) => s.set('quranFont', v),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.skip_next),
              title: const Text('الانتقال التلقائي للسورة التالية'),
              value: s.autoNext,
              onChanged: (v) => s.set('autoNext', v),
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline_outlined),
              title: const Text('إدارة الملفات المحمّلة'),
              onTap: () => go(context, const DownloadsPage()),
            ),
            const SectionTitle('البيانات'),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('النسخ الاحتياطي والاستعادة'),
              onTap: () => go(context, const BackupPage()),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('الخصوصية'),
              onTap: () => _privacy(context),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('عن التطبيق'),
              onTap: () => go(context, const AboutPage()),
            ),
            const DeveloperSignature(),
          ]);
        },
      ),
    );
  }
}
