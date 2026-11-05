import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/audio_controller.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';

class AdhanSettingsPage extends StatefulWidget {
  const AdhanSettingsPage({super.key});
  @override
  State<AdhanSettingsPage> createState() => _AdhanSettingsPageState();
}

class _AdhanSettingsPageState extends State<AdhanSettingsPage> {
  List<Muezzin> muezzins = [];
  bool notifOk = true, exactOk = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await AdhanAudio.muezzins();
    final n = await NotificationService.notificationsAllowed();
    final e = await NotificationService.exactAllowed();
    if (mounted) setState(() { muezzins = m; notifOk = n; exactOk = e; });
  }

  Future<void> _set(String k, dynamic v) async {
    await Settings.i.set(k, v);
    await NotificationService.ensureScheduled();
  }

  Future<void> _open(String action, {Map<String, dynamic>? args}) async {
    try {
      await AndroidIntent(action: action, arguments: args).launch();
    } catch (_) {
      if (mounted) toast(context, 'تعذر فتح الإعدادات، افتحها يدويًا من إعدادات الهاتف');
    }
  }

  @override
  void dispose() {
    final p = AudioCtl.i.previewLabel.value;
    if (p != null) AudioCtl.i.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الأذان')),
      body: ListenableBuilder(
        listenable: Settings.i,
        builder: (context, _) {
          final s = Settings.i;
          return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            if (!notifOk || !exactOk)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Panel(
                  color: Colors.orange.withAlpha(35),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('⚠️ أذونات ناقصة قد تمنع الأذان من العمل',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (!notifOk)
                      FilledButton.tonal(
                          onPressed: () async {
                            await NotificationService.requestPermissions();
                            await _load();
                          },
                          child: const Text('السماح بالإشعارات')),
                    if (!exactOk)
                      FilledButton.tonal(
                          onPressed: () async {
                            await NotificationService.requestPermissions();
                            await _load();
                          },
                          child: const Text('السماح بالمنبهات الدقيقة')),
                  ]),
                ),
              ),
            SwitchListTile(
              title: const Text('تشغيل الإشعارات'),
              subtitle: const Text('المفتاح الرئيسي لكل التنبيهات'),
              value: s.notificationsOn,
              onChanged: (v) => _set('notifOn', v),
            ),
            SwitchListTile(
              title: const Text('تشغيل الأذان عند دخول الوقت'),
              value: s.adhanOn,
              onChanged: s.notificationsOn ? (v) => _set('adhanOn', v) : null,
            ),
            const SectionTitle('الأذان لكل صلاة'),
            for (final p in fardPrayers)
              SwitchListTile(
                title: Text(prayerAr[p]!),
                secondary: Text(fmtTime(PrayerService.forDate(cairoNow()).t[p]!)),
                value: s.adhanFor(p.name),
                onChanged: (v) => _set('adhan_${p.name}', v),
              ),
            const SectionTitle('التذكير قبل الصلاة'),
            SwitchListTile(
              title: const Text('تنبيه قبل كل صلاة'),
              value: s.reminderOn,
              onChanged: (v) => _set('reminderOn', v),
            ),
            if (s.reminderOn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 8, children: [
                  for (final m in const [5, 10, 15, 20, 30])
                    ChoiceChip(
                      label: Text('${ar(m)} د'),
                      selected: s.reminderMinutes == m,
                      onSelected: (_) => _set('reminderMin', m),
                    ),
                ]),
              ),
            const SectionTitle('صوت الأذان (المؤذن)'),
            if (muezzins.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Panel(
                  child: Text(
                      'لا توجد ملفات أذان داخل التطبيق. ضع الملفات في assets/adhan/ ثم أعد البناء (راجع README). حاليًا يُستخدم صوت التنبيه الافتراضي.',
                      style: TextStyle(height: 1.7, color: cs.onSurface.withAlpha(170))),
                ),
              )
            else ...[
              for (final m in muezzins)
                ListTile(
                  leading: Icon(
                      s.muezzin == m.id ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: cs.primary),
                  title: Text(m.label),
                  subtitle: Text(m.hasFajr ? 'يتضمن أذان فجر مميزًا' : 'نفس الأذان لكل الصلوات'),
                  onTap: () => _set('muezzin', m.id),
                  trailing: ValueListenableBuilder<String?>(
                    valueListenable: AudioCtl.i.previewLabel,
                    builder: (context, playing, _) => IconButton(
                      tooltip: 'تجربة',
                      icon: Icon(playing == m.label
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline),
                      onPressed: () async {
                        if (playing == m.label) {
                          await AudioCtl.i.stop();
                        } else {
                          try {
                            await AudioCtl.i.previewAdhan(m);
                          } catch (_) {
                            if (context.mounted) toast(context, 'تعذر تشغيل الملف');
                          }
                        }
                      },
                    ),
                  ),
                ),
              if (muezzins.any((m) => m.hasFajr))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      for (final m in muezzins) {
                        if (m.id == s.muezzin && m.hasFajr) {
                          await AudioCtl.i.previewAdhan(m, fajr: true);
                        }
                      }
                    },
                    icon: const Icon(Icons.wb_twilight),
                    label: const Text('تجربة أذان الفجر'),
                  ),
                ),
            ],
            const SectionTitle('مستوى الصوت (للتجربة داخل التطبيق)'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    value: s.volume,
                    min: 0.1,
                    max: 1,
                    onChanged: (v) {
                      s.set('volume', v);
                      AudioCtl.i.player.setVolume(v);
                    },
                  ),
                ),
                const Icon(Icons.volume_up),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                  'أذان الإشعارات يعمل بمستوى صوت «المنبّه» في الهاتف، فاضبطه من أزرار الصوت أو إعدادات الهاتف.',
                  style: TextStyle(fontSize: 12, height: 1.6, color: cs.onSurface.withAlpha(150))),
            ),
            SwitchListTile(
              title: const Text('اهتزاز مع الأذان'),
              value: s.vibrate,
              onChanged: (v) => _set('vibrate', v),
            ),
            const SectionTitle('اختبار'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () async {
                  await NotificationService.requestPermissions();
                  await NotificationService.testAdhanNotification();
                  if (context.mounted) toast(context, 'تم إرسال إشعار تجريبي بنفس إعدادات الأذان');
                },
                icon: const Icon(Icons.notifications_active),
                label: const Text('تجربة إشعار الأذان الآن'),
              ),
            ),
            const SectionTitle('لضمان عمل الأذان في الخلفية'),
            ListTile(
              leading: const Icon(Icons.battery_saver),
              title: const Text('استثناء التطبيق من توفير البطارية'),
              subtitle: const Text('مهم جدًا في هواتف شاومي وسامسونج وأوبو وغيرها'),
              onTap: () => _open('android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS'),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('إعدادات إشعارات سكينة'),
              onTap: () => _open('android.settings.APP_NOTIFICATION_SETTINGS',
                  args: {'android.provider.extra.APP_PACKAGE': 'com.hosny.sakina'}),
            ),
            ListTile(
              leading: const Icon(Icons.alarm),
              title: const Text('المنبهات والتذكيرات الدقيقة'),
              onTap: () async {
                await NotificationService.requestPermissions();
                await _load();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                  'بعض الشركات تُغلق التطبيقات في الخلفية: فعّل «التشغيل التلقائي / Autostart» واسمح بالعمل في الخلفية لسكينة. تُجدول التنبيهات لأربعة عشر يومًا وتتجدد كلما فتحت التطبيق.',
                  style: TextStyle(fontSize: 12, height: 1.7, color: cs.onSurface.withAlpha(150))),
            ),
          ]);
        },
      ),
    );
  }
}
