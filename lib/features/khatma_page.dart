import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/surahs.dart';
import '../services/khatma_store.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import 'quran_page.dart';

class KhatmaPage extends StatefulWidget {
  const KhatmaPage({super.key});
  @override
  State<KhatmaPage> createState() => _KhatmaPageState();
}

class _KhatmaPageState extends State<KhatmaPage> {
  int days = 30;
  final custom = TextEditingController();

  DateTime get today {
    final n = cairoNow();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _addPages(int n) async {
    await KhatmaStore.addPages(n, today);
    if (mounted) setState(() {});
  }

  Future<void> _pickTime() async {
    final s = Settings.i;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: s.khatmaHour, minute: s.khatmaMinute));
    if (t == null) return;
    await s.set('khatmaHour', t.hour);
    await s.set('khatmaMinute', t.minute);
    await NotificationService.ensureScheduled();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final plan = KhatmaStore.plan();
    return Scaffold(
      appBar: AppBar(title: const Text('مساعد الختمة')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          children: plan == null ? _create(context) : _active(context, plan)),
    );
  }

  List<Widget> _create(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final perDay = (totalMushafPages / days).ceil();
    return [
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ابدأ ختمة جديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('المصحف ${ar(totalMushafPages)} صفحة (مصحف المدينة). اختر المدة وسنحسب وردك اليومي.',
              style: TextStyle(height: 1.7, color: cs.onSurface.withAlpha(170))),
          if (KhatmaStore.completed() > 0) ...[
            const SizedBox(height: 8),
            Text('ختمات أتممتها: ${ar(KhatmaStore.completed())} 🌙',
                style: const TextStyle(color: goldDeep, fontWeight: FontWeight.w800)),
          ],
        ]),
      ),
      const SectionTitle('المدة'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in const [30, 15, 60, 90, 180])
          ChoiceChip(
            label: Text('${ar(d)} يوم${d == 30 ? ' (شهر)' : ''}'),
            selected: days == d,
            onSelected: (_) => setState(() => days = d),
          ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: custom,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'مدة مخصصة (بالأيام)', border: OutlineInputBorder()),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) setState(() => days = n.clamp(1, 3650));
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'أو صفحات يوميًا', border: OutlineInputBorder()),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) {
                setState(() => days = (totalMushafPages / n.clamp(1, totalMushafPages)).ceil());
              }
            },
          ),
        ),
      ]),
      const SizedBox(height: 16),
      Panel(
        color: cs.primary.withAlpha(24),
        child: Row(children: [
          Icon(Icons.calculate_rounded, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text('وردك: نحو ${ar(perDay)} صفحة يوميًا لمدة ${ar(days)} يومًا',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () async {
          await KhatmaStore.create(days);
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.flag_rounded),
        label: const Text('ابدأ الختمة'),
      ),
    ];
  }

  List<Widget> _active(BuildContext context, Map<String, dynamic> plan) {
    final cs = Theme.of(context).colorScheme;
    final read = KhatmaStore.pagesRead(plan);
    final remaining = totalMushafPages - read;
    final pct = read / totalMushafPages;
    final todayRead = KhatmaStore.readOn(plan, today);
    final wird = KhatmaStore.wirdToday(plan, today);
    final left = KhatmaStore.daysLeft(plan, today);
    final expected = KhatmaStore.expectedPagesByNow(plan, today);
    final diff = read - expected;
    final start = KhatmaStore.startOf(plan);
    final elapsed = (daysBetween(start, today) + 1).clamp(1, 100000);
    final pace = read / elapsed;
    final finishIn = pace > 0 ? (remaining / pace).ceil() : null;
    final s = Settings.i;
    final done = read >= totalMushafPages;

    return [
      HeroCard(
        margin: EdgeInsets.zero,
        child: Column(children: [
          Text('${ar((pct * 100).toStringAsFixed(1))}%',
              style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900)),
          Text('${ar(read)} من ${ar(totalMushafPages)} صفحة',
              style: TextStyle(color: Colors.white.withAlpha(220))),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: pct, minHeight: 10, backgroundColor: Colors.white24, color: gold),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('المتبقي', '${ar(remaining)} ص'),
            _stat('الأيام المتبقية', ar(left)),
            _stat('مدة الخطة', '${ar(KhatmaStore.daysOf(plan))} يوم'),
          ]),
        ]),
      ),
      if (done) ...[
        const SizedBox(height: 14),
        Panel(
          color: gold.withAlpha(40),
          child: Column(children: [
            const Text('🌙 ما شاء الله! أتممت الختمة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('تقبّل الله منك، ويُستحب دعاء ختم القرآن.'),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () async {
                await KhatmaStore.finish();
                if (mounted) setState(() {});
              },
              child: const Text('تسجيل الختمة وبدء جديدة'),
            ),
          ]),
        ),
      ],
      const SectionTitle('ورد اليوم'),
      Panel(
        child: Column(children: [
          Row(children: [
            Expanded(child: _big('المطلوب اليوم', '${ar(wird)} ص')),
            Expanded(child: _big('قرأت اليوم', '${ar(todayRead)} ص')),
          ]),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: wird == 0 ? 1.0 : (todayRead / wird).clamp(0.0, 1.0), minHeight: 8),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            FilledButton.tonal(onPressed: () => _addPages(-1), child: const Text('−١')),
            FilledButton.tonal(onPressed: () => _addPages(1), child: const Text('+١ صفحة')),
            FilledButton.tonal(onPressed: () => _addPages(5), child: const Text('+٥ صفحات')),
            FilledButton(
              onPressed: todayRead >= wird ? null : () => _addPages(wird - todayRead),
              child: const Text('أتممت وردي'),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        color: (diff >= 0 ? Colors.green : Colors.orange).withAlpha(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              diff >= 0
                  ? 'أنت متقدم بـ ${ar(diff)} صفحة عن الخطة 👏'
                  : 'أنت متأخر ${ar(-diff)} صفحة عن الخطة، عوّضها بهدوء.',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          if (finishIn != null && !done) ...[
            const SizedBox(height: 4),
            Text('بمعدلك الحالي تنتهي بعد ${ar(finishIn)} يومًا تقريبًا.',
                style: TextStyle(fontSize: 12.5, color: cs.onSurface.withAlpha(170))),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => go(context, const QuranPage(standalone: true)),
        icon: const Icon(Icons.menu_book_rounded),
        label: const Text('افتح المصحف'),
      ),
      const SectionTitle('تذكير الورد'),
      SwitchListTile(
        title: const Text('تذكير يومي بالورد'),
        value: s.khatmaReminder,
        onChanged: (v) async {
          await s.set('khatmaReminder', v);
          if (v) await NotificationService.requestPermissions();
          await NotificationService.ensureScheduled();
          if (mounted) setState(() {});
        },
      ),
      if (s.khatmaReminder)
        ListTile(
          leading: const Icon(Icons.alarm),
          title: const Text('وقت التذكير'),
          subtitle: Text(fmtTime(DateTime(2000, 1, 1, s.khatmaHour, s.khatmaMinute))),
          onTap: _pickTime,
        ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('إلغاء الخطة الحالية؟'),
              content: const Text('سيُحذف تقدمك في هذه الخطة.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إلغاء الخطة')),
              ],
            ),
          );
          if (ok == true) {
            await KhatmaStore.cancel();
            if (mounted) setState(() {});
          }
        },
        icon: const Icon(Icons.delete_outline),
        label: const Text('إلغاء الخطة'),
      ),
    ];
  }

  Widget _stat(String l, String v) => Column(children: [
        Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        Text(l, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11.5)),
      ]);

  Widget _big(String l, String v) => Column(children: [
        Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        Text(l, style: const TextStyle(fontSize: 12)),
      ]);
}
