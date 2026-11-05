import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/prayer_log.dart';
import '../services/prayer_service.dart';
import 'city_picker.dart';
import 'offsets_page.dart';

class PrayerPage extends StatelessWidget {
  const PrayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        const SizedBox(height: 8),
        const Text('الصلاة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const TabBar(tabs: [
          Tab(text: 'اليوم'),
          Tab(text: 'الشهر'),
          Tab(text: 'متابعتي'),
        ]),
        const Expanded(
          child: TabBarView(children: [_TodayTab(), _MonthTab(), _TrackerTab()]),
        ),
      ]),
    );
  }
}

// ======================= اليوم =======================
class _TodayTab extends StatefulWidget {
  const _TodayTab();
  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> {
  int shift = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && shift == 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.i,
      builder: (context, _) {
        final now = cairoNow();
        final date = DateTime(now.year, now.month, now.day + shift);
        final day = PrayerService.forDate(date);
        final next = PrayerService.next(now);
        final cs = Theme.of(context).colorScheme;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Panel(
            child: Column(children: [
              Row(children: [
                IconButton(
                    onPressed: () => setState(() => shift--),
                    icon: const Icon(Icons.chevron_right)),
                Expanded(
                  child: Column(children: [
                    Text(shift == 0 ? 'اليوم' : fmtDate(date),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${fmtHijri(date)}${shift == 0 ? '  •  ${fmtDate(date)}' : ''}',
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(150))),
                  ]),
                ),
                IconButton(
                    onPressed: () => setState(() => shift++),
                    icon: const Icon(Icons.chevron_left)),
              ]),
              const Divider(),
              Row(children: [
                const Icon(Icons.location_on, color: gold, size: 18),
                const SizedBox(width: 4),
                Expanded(child: Text('${Settings.i.gov} • ${Settings.i.cityName}')),
                TextButton(
                    onPressed: () => go(context, const CityPickerPage()),
                    child: const Text('تغيير')),
              ]),
              if (shift != 0)
                TextButton(
                    onPressed: () => setState(() => shift = 0),
                    child: const Text('العودة لليوم')),
            ]),
          ),
          const SizedBox(height: 12),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(children: [
              for (final p in Prayer.values)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: shift == 0 && p == next.prayer
                        ? cs.primary.withAlpha(28)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Text(prayerAr[p]!,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                    if (Settings.i.offset(p.name) != 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                            '(${Settings.i.offset(p.name) > 0 ? '+' : ''}${ar(Settings.i.offset(p.name))} د)',
                            style: const TextStyle(fontSize: 11, color: goldDeep)),
                      ),
                    Text(fmtTime(day.t[p]!),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  ]),
                ),
            ]),
          ),
          if (shift == 0) ...[
            const SizedBox(height: 12),
            Panel(
              color: cs.primary.withAlpha(24),
              child: Row(children: [
                Icon(Icons.timer_outlined, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('باقي على ${prayerAr[next.prayer]}: ${fmtDur(next.at.difference(now))}',
                        style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => go(context, const OffsetsPage()),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('ضبط فرق الدقائق لكل صلاة'),
          ),
          const SizedBox(height: 8),
          Text(
              'الحساب بطريقة الهيئة المصرية العامة للمساحة (الفجر 19.5° والعشاء 17.5°)، ويعمل بدون إنترنت.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.6, color: cs.onSurface.withAlpha(140))),
        ]);
      },
    );
  }
}

// ======================= الشهر =======================
class _MonthTab extends StatefulWidget {
  const _MonthTab();
  @override
  State<_MonthTab> createState() => _MonthTabState();
}

class _MonthTabState extends State<_MonthTab> {
  late DateTime month;

  @override
  void initState() {
    super.initState();
    final n = cairoNow();
    month = DateTime(n.year, n.month, 1);
  }

  Future<void> _export() async {
    try {
      final days = DateTime(month.year, month.month + 1, 0).day;
      final b = StringBuffer('\uFEFFالتاريخ,الفجر,الشروق,الظهر,العصر,المغرب,العشاء\n');
      for (int d = 1; d <= days; d++) {
        final date = DateTime(month.year, month.month, d);
        final t = PrayerService.forDate(date).t;
        String hm(Prayer p) =>
            '${t[p]!.hour.toString().padLeft(2, '0')}:${t[p]!.minute.toString().padLeft(2, '0')}';
        b.writeln('${dayKey(date)},${hm(Prayer.fajr)},${hm(Prayer.sunrise)},${hm(Prayer.dhuhr)},${hm(Prayer.asr)},${hm(Prayer.maghrib)},${hm(Prayer.isha)}');
      }
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/sakina_prayer_${month.year}_${month.month.toString().padLeft(2, '0')}.csv');
      await f.writeAsString(b.toString());
      await Share.shareXFiles([XFile(f.path)],
          text: 'مواقيت الصلاة - ${Settings.i.cityName} - ${gregMonths[month.month - 1]} ${month.year}');
    } catch (_) {
      if (mounted) toast(context, 'تعذر تصدير الجدول');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.i,
      builder: (context, _) {
        final days = DateTime(month.year, month.month + 1, 0).day;
        final now = cairoNow();
        final cs = Theme.of(context).colorScheme;
        const cols = [Prayer.fajr, Prayer.sunrise, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];
        Widget cell(String t, {bool bold = false, Color? color, double w = 56}) => SizedBox(
            width: w,
            child: Text(t,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color)));
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              IconButton(
                  onPressed: () => setState(() => month = DateTime(month.year, month.month - 1, 1)),
                  icon: const Icon(Icons.chevron_right)),
              Expanded(
                  child: Text('${gregMonths[month.month - 1]} ${ar(month.year)} • ${Settings.i.cityName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              IconButton(
                  onPressed: () => setState(() => month = DateTime(month.year, month.month + 1, 1)),
                  icon: const Icon(Icons.chevron_left)),
              IconButton(
                  tooltip: 'تصدير الجدول',
                  onPressed: _export,
                  icon: const Icon(Icons.ios_share_rounded)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 64 + 56.0 * 6 + 24,
                child: Column(children: [
                  Container(
                    color: cs.primary.withAlpha(30),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: Row(children: [
                      cell('اليوم', bold: true, w: 64),
                      for (final p in cols) cell(prayerAr[p]!, bold: true),
                    ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: days,
                      itemBuilder: (context, i) {
                        final date = DateTime(month.year, month.month, i + 1);
                        final t = PrayerService.forDate(date).t;
                        final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                        return Container(
                          color: isToday ? gold.withAlpha(50) : (i.isEven ? null : cs.onSurface.withAlpha(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          child: Row(children: [
                            SizedBox(
                              width: 64,
                              child: Column(children: [
                                Text(ar(date.day), style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(weekdays[date.weekday - 1], style: const TextStyle(fontSize: 9.5)),
                              ]),
                            ),
                            for (final p in cols) cell(fmtTime(t[p]!).replaceAll(' ', '\n'), color: p == Prayer.sunrise ? goldDeep : null),
                          ]),
                        );
                      },
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

// ======================= المتابعة =======================
class _TrackerTab extends StatefulWidget {
  const _TrackerTab();
  @override
  State<_TrackerTab> createState() => _TrackerTabState();
}

class _TrackerTabState extends State<_TrackerTab> {
  int shift = 0;
  int range = 7;

  @override
  Widget build(BuildContext context) {
    final now = cairoNow();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(today.year, today.month, today.day + shift);
    final cs = Theme.of(context).colorScheme;
    final total = range * 5;
    final done = PrayerLog.doneInRange(today, range);
    final pct = total == 0 ? 0.0 : done / total;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Panel(
        child: Column(children: [
          Row(children: [
            IconButton(
                onPressed: () => setState(() => shift--),
                icon: const Icon(Icons.chevron_right)),
            Expanded(
                child: Text(shift == 0 ? 'صلوات اليوم' : fmtDate(date),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            IconButton(
                onPressed: shift >= 0 ? null : () => setState(() => shift++),
                icon: const Icon(Icons.chevron_left)),
          ]),
          const SizedBox(height: 6),
          for (final p in fardPrayers)
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(prayerAr[p]!, style: const TextStyle(fontWeight: FontWeight.w700)),
              secondary: Text(fmtTime(PrayerService.forDate(date).t[p]!),
                  style: TextStyle(color: cs.onSurface.withAlpha(150))),
              value: PrayerLog.done(date, p),
              onChanged: (_) async {
                await PrayerLog.toggle(date, p);
                if (mounted) setState(() {});
              },
            ),
        ]),
      ),
      const SectionTitle('إحصائيات الالتزام'),
      Panel(
        child: Column(children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('أسبوع')),
              ButtonSegment(value: 30, label: Text('شهر')),
              ButtonSegment(value: 90, label: Text('٣ أشهر')),
            ],
            selected: {range},
            onSelectionChanged: (v) => setState(() => range = v.first),
          ),
          const SizedBox(height: 16),
          Text('${ar((pct * 100).round())}%',
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: cs.primary)),
          Text('${ar(done)} من ${ar(total)} صلاة', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: pct, minHeight: 10),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.local_fire_department_rounded, color: gold),
            const SizedBox(width: 6),
            Text('${ar(PrayerLog.streak(today))} يوم متتالٍ بالتزام كامل',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
      const SectionTitle('آخر ٧ أيام'),
      Panel(
        child: SizedBox(
          height: 130,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (int i = 6; i >= 0; i--)
              Expanded(
                child: Builder(builder: (context) {
                  final d = DateTime(today.year, today.month, today.day - i);
                  final c = PrayerLog.countDay(d);
                  return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(ar(c), style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      height: 8 + c * 16.0,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: c == 5 ? gold : cs.primary.withAlpha(c == 0 ? 40 : 180),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(weekdays[d.weekday - 1].substring(0, 3),
                        style: const TextStyle(fontSize: 9.5)),
                  ]);
                }),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Text('سجل عبادتك محفوظ على هاتفك فقط ولا يُرسل لأي جهة.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: cs.onSurface.withAlpha(140))),
    ]);
  }
}
