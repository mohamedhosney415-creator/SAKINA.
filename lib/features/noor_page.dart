import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/noor_service.dart';
import '../services/prayer_service.dart';

class NoorPage extends StatefulWidget {
  const NoorPage({super.key});
  @override
  State<NoorPage> createState() => _NoorPageState();
}

class _NoorPageState extends State<NoorPage> {
  @override
  Widget build(BuildContext context) {
    final now = cairoNow();
    final today = DateTime(now.year, now.month, now.day);
    final item = NoorService.forDay(today);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('نور يومك')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        HeroCard(
          margin: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.wb_twilight_rounded, color: gold),
              const SizedBox(width: 8),
              Text(item.label,
                  style: const TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 15)),
              const Spacer(),
              Text(fmtDate(today), style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11.5)),
            ]),
            const SizedBox(height: 14),
            Text(item.text,
                style: const TextStyle(color: Colors.white, fontSize: 21, height: 2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(item.sourceLine,
                style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 12.5, height: 1.7)),
          ]),
        ),
        const SizedBox(height: 6),
        ContentActions(
            type: item.favType, id: item.id, text: item.text, source: item.sourceLine),
        const SectionTitle('ماذا تريد أن يظهر؟'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('تناوب')),
            ButtonSegment(value: 1, label: Text('حديث')),
            ButtonSegment(value: 2, label: Text('حكمة')),
            ButtonSegment(value: 3, label: Text('عشوائي')),
          ],
          selected: {Settings.i.noorMode.clamp(0, 3)},
          onSelectionChanged: (v) async {
            await Settings.i.set('noorMode', v.first);
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 6),
        Text('الاختيار ثابت طوال اليوم ويتجدد تلقائيًا كل يوم دون تكرار، والمحتوى محفوظ بدون إنترنت.',
            style: TextStyle(fontSize: 11.5, color: cs.onSurface.withAlpha(140))),
        const SectionTitle('الأيام السابقة'),
        for (int i = 1; i <= 6; i++)
          Builder(builder: (context) {
            final d = DateTime(today.year, today.month, today.day - i);
            final it = NoorService.forDay(d);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${it.label} • ${fmtShortDate(d)}',
                      style: const TextStyle(color: goldDeep, fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(it.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.8, fontSize: 15)),
                  Text(it.sourceLine, style: TextStyle(fontSize: 11, color: cs.onSurface.withAlpha(140))),
                  ContentActions(type: it.favType, id: it.id, text: it.text, source: it.sourceLine),
                ]),
              ),
            );
          }),
      ]),
    );
  }
}
