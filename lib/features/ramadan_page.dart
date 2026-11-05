import 'dart:async';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/ramadan_duas.dart';
import '../services/prayer_service.dart';

class RamadanPage extends StatefulWidget {
  const RamadanPage({super.key});
  @override
  State<RamadanPage> createState() => _RamadanPageState();
}

class _RamadanPageState extends State<RamadanPage> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  // ---------- تخزين ----------
  Map<String, dynamic> _fasts() {
    final j = Store.json('fasts', {});
    return j is Map ? Map<String, dynamic>.from(j) : {};
  }

  Future<void> _toggleFast(DateTime d) async {
    final f = _fasts();
    final k = dayKey(d);
    if (f.containsKey(k)) {
      f.remove(k);
    } else {
      f[k] = 'ramadan';
    }
    await Store.setJson('fasts', f);
    if (mounted) setState(() {});
  }

  List<int> _checked(DateTime d) {
    final j = Store.json('rchk', {});
    final v = j is Map ? j[dayKey(d)] : null;
    return v is List ? v.map((e) => (e as num).toInt()).toList() : [];
  }

  Future<void> _toggleCheck(DateTime d, int i) async {
    final j = Store.json('rchk', {});
    final all = j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
    final cur = _checked(d);
    cur.contains(i) ? cur.remove(i) : cur.add(i);
    all[dayKey(d)] = cur;
    await Store.setJson('rchk', all);
    if (mounted) setState(() {});
  }

  int get qOwed => Store.integer('qada_owed', 0);
  int get qDone => Store.integer('qada_done', 0);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = cairoNow();
    final today = DateTime(now.year, now.month, now.day);
    final h = hijriOf(today);
    final ry = h.hMonth <= 9 ? h.hYear : h.hYear + 1;
    final start = gregOfHijri(ry, 9, 1);
    final len = hijriMonthLength(ry, 9);
    final inRamadan = h.hMonth == 9;
    final toStart = daysBetween(today, start);

    final day = PrayerService.forDate(today);
    final fajr = day.t[Prayer.fajr]!;
    final maghrib = day.t[Prayer.maghrib]!;
    String label;
    Duration left;
    if (now.isBefore(fajr)) {
      label = 'باقي على أذان الفجر (نهاية السحور)';
      left = fajr.difference(now);
    } else if (now.isBefore(maghrib)) {
      label = 'باقي على الإفطار';
      left = maghrib.difference(now);
    } else {
      label = 'باقي على الإمساك القادم';
      left = PrayerService.forDate(DateTime(today.year, today.month, today.day + 1))
          .t[Prayer.fajr]!
          .difference(now);
    }

    final fasts = _fasts();
    final ramadanFasted = List.generate(len, (i) => gregOfHijri(ry, 9, i + 1))
        .where((d) => fasts.containsKey(dayKey(d)))
        .length;
    final checked = _checked(today);

    return Scaffold(
      appBar: AppBar(title: const Text('رمضان والصيام')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        HeroCard(
          margin: EdgeInsets.zero,
          child: Column(children: [
            Text(
                inRamadan
                    ? 'اليوم ${ar(h.hDay)} من رمضان ${ar(h.hYear)}'
                    : 'رمضان ${ar(ry)} هـ بعد ${ar(toStart)} يومًا',
                style: const TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(color: Colors.white.withAlpha(220))),
            Text(fmtDur(left),
                style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _t2('السحور ينتهي', fmtTime(fajr)),
              _t2('الإفطار', fmtTime(maghrib)),
            ]),
          ]),
        ),
        const SectionTitle('صيام اليوم'),
        Panel(
          child: Row(children: [
            Expanded(
              child: Text(fasts.containsKey(dayKey(today)) ? 'سجّلت صيام اليوم ✅' : 'هل تصوم اليوم؟',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            FilledButton.tonal(
              onPressed: () => _toggleFast(today),
              child: Text(fasts.containsKey(dayKey(today)) ? 'إلغاء' : 'تسجيل'),
            ),
          ]),
        ),
        const SectionTitle('جدول العبادات اليومي'),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (int i = 0; i < ramadanChecklist.length; i++)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(ramadanChecklist[i]),
                value: checked.contains(i),
                onChanged: (_) => _toggleCheck(today, i),
              ),
          ]),
        ),
        SectionTitle('أيام رمضان ${ar(ry)}  (${ar(ramadanFasted)} / ${ar(len)} صيام)'),
        Panel(
          child: GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (int i = 1; i <= len; i++)
                Builder(builder: (context) {
                  final d = gregOfHijri(ry, 9, i);
                  final on = fasts.containsKey(dayKey(d));
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _toggleFast(d),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? cs.primary : cs.primary.withAlpha(16),
                        borderRadius: BorderRadius.circular(12),
                        border: d == today ? Border.all(color: gold, width: 2) : null,
                      ),
                      child: Text(ar(i),
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: on ? cs.onPrimary : null)),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SectionTitle('أيام القضاء'),
        Panel(
          child: Column(children: [
            Row(children: [
              const Expanded(child: Text('عليّ قضاء', style: TextStyle(fontWeight: FontWeight.w800))),
              IconButton(
                  onPressed: qOwed > 0 ? () async { await Store.setInt('qada_owed', qOwed - 1); setState(() {}); } : null,
                  icon: const Icon(Icons.remove_circle_outline)),
              Text('${ar(qOwed)} يوم', style: const TextStyle(fontWeight: FontWeight.w900)),
              IconButton(
                  onPressed: () async { await Store.setInt('qada_owed', qOwed + 1); setState(() {}); },
                  icon: const Icon(Icons.add_circle_outline)),
            ]),
            Row(children: [
              Expanded(child: Text('قضيتُ ${ar(qDone)} • المتبقي ${ar((qOwed - qDone).clamp(0, 9999))}')),
              FilledButton.tonal(
                onPressed: () async {
                  await Store.setInt('qada_done', qDone + 1);
                  if (qDone + 1 > qOwed) await Store.setInt('qada_owed', qDone + 1);
                  if (mounted) setState(() {});
                },
                child: const Text('سجّلت يوم قضاء'),
              ),
            ]),
          ]),
        ),
        const SectionTitle('إمساكية رمضان'),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            Container(
              color: cs.primary.withAlpha(26),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: const Row(children: [
                SizedBox(width: 34, child: Text('يوم', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                Expanded(child: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                SizedBox(width: 70, child: Text('الإمساك', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                SizedBox(width: 70, child: Text('الإفطار', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              ]),
            ),
            for (int i = 1; i <= len; i++)
              Builder(builder: (context) {
                final d = gregOfHijri(ry, 9, i);
                final t = PrayerService.forDate(d).t;
                return Container(
                  color: d == today ? gold.withAlpha(45) : (i.isEven ? cs.onSurface.withAlpha(8) : null),
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                  child: Row(children: [
                    SizedBox(width: 34, child: Text(ar(i), style: const TextStyle(fontWeight: FontWeight.w800))),
                    Expanded(child: Text(fmtShortDate(d), style: const TextStyle(fontSize: 12))),
                    SizedBox(width: 70, child: Text(fmtTime(t[Prayer.fajr]!), style: const TextStyle(fontSize: 12))),
                    SizedBox(width: 70, child: Text(fmtTime(t[Prayer.maghrib]!), style: const TextStyle(fontSize: 12))),
                  ]),
                );
              }),
          ]),
        ),
        const SectionTitle('أدعية رمضان'),
        for (int i = 0; i < ramadanDuas.length; i++) _duaCard(context, ramadanDuas[i], 'rd$i'),
        const SectionTitle('أذكار رمضان'),
        for (int i = 0; i < ramadanAzkar.length; i++) _duaCard(context, ramadanAzkar[i], 'ra$i'),
      ]),
    );
  }

  Widget _t2(String l, String v) => Column(children: [
        Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
        Text(l, style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11.5)),
      ]);

  Widget _duaCard(BuildContext context, Dua d, String id) {
    final cs = Theme.of(context).colorScheme;
    final src = d.note.isEmpty ? d.source : '${d.note} • ${d.source}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.text, style: const TextStyle(fontSize: 18, height: 2, fontWeight: FontWeight.w700)),
          Text(src, style: TextStyle(fontSize: 11.5, color: cs.onSurface.withAlpha(150))),
          ContentActions(type: 'zikr', id: id, text: d.text, source: src),
        ]),
      ),
    );
  }
}
