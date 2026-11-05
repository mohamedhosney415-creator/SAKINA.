import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/events.dart';
import '../services/events_service.dart';
import '../services/prayer_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late int hy, hm;

  @override
  void initState() {
    super.initState();
    final h = hijriOf(cairoNow());
    hy = h.hYear;
    hm = h.hMonth;
  }

  void _shift(int d) {
    setState(() {
      hm += d;
      if (hm > 12) {
        hm = 1;
        hy++;
      } else if (hm < 1) {
        hm = 12;
        hy--;
      }
    });
  }

  void _dayInfo(DateTime g, int hd) {
    final evs = EventsService.onDate(g);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${ar(hd)} ${hijriMonths[hm - 1]} ${ar(hy)} هـ',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(fmtDate(g)),
            const SizedBox(height: 10),
            if (evs.isEmpty && !EventsService.isWhiteDay(g))
              const Text('لا مناسبة في هذا اليوم.')
            else ...[
              for (final e in evs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star_rounded, color: gold),
                  title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(e.note),
                ),
              if (EventsService.isWhiteDay(g))
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.brightness_5, color: gold),
                  title: Text('من الأيام البيض', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('يُستحب صيامها.'),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = cairoNow();
    final today = DateTime(now.year, now.month, now.day);
    final first = gregOfHijri(hy, hm, 1);
    final len = hijriMonthLength(hy, hm);
    final lead = (first.weekday + 1) % 7; // السبت أول الأسبوع
    final last = gregOfHijri(hy, hm, len);
    const heads = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];
    final upcoming = EventsService.upcoming(now, horizonDays: 400).take(8).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('التقويم الإسلامي')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        Panel(
          child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_right)),
              Expanded(
                child: Column(children: [
                  Text('${hijriMonths[hm - 1]} ${ar(hy)} هـ',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  Text('${gregMonths[first.month - 1]} ${ar(first.year)} - ${gregMonths[last.month - 1]} ${ar(last.year)}',
                      style: TextStyle(fontSize: 11.5, color: cs.onSurface.withAlpha(150))),
                ]),
              ),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_left)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              for (int i = 0; i < 7; i++)
                Expanded(
                    child: Center(
                        child: Text(heads[i],
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: i == 6 ? cs.primary : cs.onSurface.withAlpha(150))))),
            ]),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: .88,
              children: [
                for (int i = 0; i < lead; i++) const SizedBox.shrink(),
                for (int d = 1; d <= len; d++)
                  Builder(builder: (context) {
                    final g = gregOfHijri(hy, hm, d);
                    final isToday = g == today;
                    final hasEvent = EventsService.onDate(g).isNotEmpty;
                    final white = EventsService.isWhiteDay(g);
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _dayInfo(g, d),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isToday ? cs.primary : (white ? gold.withAlpha(34) : null),
                          borderRadius: BorderRadius.circular(12),
                          border: hasEvent ? Border.all(color: gold, width: 1.6) : null,
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(ar(d),
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: isToday ? cs.onPrimary : null)),
                          Text(ar(g.day),
                              style: TextStyle(
                                  fontSize: 9.5,
                                  color: isToday ? cs.onPrimary.withAlpha(210) : cs.onSurface.withAlpha(130))),
                        ]),
                      ),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(border: Border.all(color: gold, width: 1.6), borderRadius: BorderRadius.circular(4))),
              const Text('  مناسبة     ', style: TextStyle(fontSize: 11)),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: gold.withAlpha(60), borderRadius: BorderRadius.circular(4))),
              const Text('  أيام بيض', style: TextStyle(fontSize: 11)),
            ]),
          ]),
        ),
        const SectionTitle('المناسبات القادمة'),
        for (final u in upcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Row(children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: cs.primary.withAlpha(26), borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Text(ar(u.daysFrom(now)), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: cs.primary)),
                    const Text('يوم', style: TextStyle(fontSize: 10)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${fmtDate(u.date)}',
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(150))),
                    Text(u.event.note, style: const TextStyle(fontSize: 12, height: 1.6)),
                  ]),
                ),
              ]),
            ),
          ),
        const SectionTitle('الأيام المباركة'),
        for (final b in blessedDays)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.brightness_7_rounded, color: gold, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(b, style: const TextStyle(height: 1.8))),
            ])),
          ),
        Text('قد يختلف التقويم يومًا عن إعلان دار الإفتاء، ويمكن تعديله من الإعدادات > ضبط المواقيت.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: cs.onSurface.withAlpha(140))),
      ]),
    );
  }
}
