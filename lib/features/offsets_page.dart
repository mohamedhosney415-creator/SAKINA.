import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/widgets.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';

/// ضبط فرق الدقائق لكل صلاة والتاريخ الهجري.
class OffsetsPage extends StatelessWidget {
  const OffsetsPage({super.key});

  Future<void> _change(String key, int v) async {
    await Settings.i.set(key, v.clamp(-30, 30));
    PrayerService.clearCache();
    await NotificationService.ensureScheduled();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ضبط المواقيت')),
      body: ListenableBuilder(
        listenable: Settings.i,
        builder: (context, _) {
          final s = Settings.i;
          final day = PrayerService.forDate(cairoNow());
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('أضف أو اطرح دقائق لتطابق مسجدك أو جدولك المعتمد. تُطبَّق على الأذان والويدجت.',
                style: TextStyle(
                    height: 1.7,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
            const SizedBox(height: 12),
            for (final p in Prayer.values)
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(prayerAr[p]!, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(fmtTime(day.t[p]!), style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                  IconButton(
                      onPressed: () => _change('off_${p.name}', s.offset(p.name) - 1),
                      icon: const Icon(Icons.remove_circle_outline)),
                  SizedBox(
                      width: 52,
                      child: Text(
                          '${s.offset(p.name) > 0 ? '+' : ''}${ar(s.offset(p.name))}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  IconButton(
                      onPressed: () => _change('off_${p.name}', s.offset(p.name) + 1),
                      icon: const Icon(Icons.add_circle_outline)),
                ]),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                for (final p in Prayer.values) {
                  await s.set('off_${p.name}', 0);
                }
                PrayerService.clearCache();
                await NotificationService.ensureScheduled();
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('إعادة الضبط الافتراضي'),
            ),
            const SectionTitle('التاريخ الهجري'),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('اليوم: ${fmtHijri(DateTime.now())}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('قد يختلف الهجري يومًا عن إعلان دار الإفتاء؛ عدّله هنا.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: -1, label: Text('-١')),
                    ButtonSegment(value: 0, label: Text('٠')),
                    ButtonSegment(value: 1, label: Text('+١')),
                  ],
                  selected: {s.hijriOffset.clamp(-1, 1)},
                  onSelectionChanged: (v) async {
                    await s.set('hijriOffset', v.first);
                    await NotificationService.ensureScheduled();
                  },
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
