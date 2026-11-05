import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/azkar.dart';
import 'tasbeeh_page.dart';

/// تقدّم الأذكار اليومي (يُحفظ ٣ أيام فقط ثم يُمسح تلقائيًا).
class AzkarProgress {
  static Map<String, dynamic> _all() {
    final j = Store.json('azkar_prog', {});
    return j is Map ? Map<String, dynamic>.from(j) : {};
  }

  static int get(String id) {
    final day = _all()[dayKey(DateTime.now())];
    return day is Map && day[id] is num ? (day[id] as num).toInt() : 0;
  }

  static Future<void> set(String id, int v) async {
    final all = _all();
    final k = dayKey(DateTime.now());
    final day = all[k] is Map ? Map<String, dynamic>.from(all[k]) : <String, dynamic>{};
    if (v <= 0) {
      day.remove(id);
    } else {
      day[id] = v;
    }
    all[k] = day;
    final keys = all.keys.toList()..sort();
    while (keys.length > 3) {
      all.remove(keys.removeAt(0));
    }
    await Store.setJson('azkar_prog', all);
  }

  static int doneIn(AzkarCategory c) =>
      c.items.where((z) => get(z.id) >= z.count).length;
}

class AzkarPage extends StatefulWidget {
  final bool standalone;
  const AzkarPage({super.key, this.standalone = false});
  @override
  State<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends State<AzkarPage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Standalone(
      on: widget.standalone,
      title: 'الأذكار',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        if (!widget.standalone)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('الأذكار', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
        Panel(
          onTap: () => go(context, const TasbeehPage()),
          color: cs.primary.withAlpha(26),
          child: Row(children: [
            Icon(Icons.touch_app_rounded, color: cs.primary, size: 30),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('المسبحة الإلكترونية',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            const Icon(Icons.chevron_left),
          ]),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            for (final c in azkarCategories)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => AzkarListPage(category: c)));
                  if (mounted) setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gold.withAlpha(70)),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(c.icon, color: cs.primary, size: 30),
                        Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${ar(AzkarProgress.doneIn(c))} / ${ar(c.items.length)} اكتمل اليوم',
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withAlpha(150))),
                      ]),
                ),
              ),
          ],
        ),
        const DeveloperSignature(),
      ]),
    );
  }
}

class AzkarListPage extends StatefulWidget {
  final AzkarCategory category;
  const AzkarListPage({super.key, required this.category});
  @override
  State<AzkarListPage> createState() => _AzkarListPageState();
}

class _AzkarListPageState extends State<AzkarListPage> {
  Future<void> _tap(Zikr z) async {
    final cur = AzkarProgress.get(z.id);
    if (cur >= z.count) return;
    if (Settings.i.haptic) {
      cur + 1 >= z.count ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    }
    await AzkarProgress.set(z.id, cur + 1);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final cs = Theme.of(context).colorScheme;
    final done = AzkarProgress.doneIn(c);
    return Scaffold(
      appBar: AppBar(
        title: Text(c.title),
        actions: [
          IconButton(
            tooltip: 'إعادة العدّ',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              for (final z in c.items) {
                await AzkarProgress.set(z.id, 0);
              }
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: done / c.items.length, minHeight: 8),
            ),
          ),
          const SizedBox(width: 10),
          Text('${ar(done)}/${ar(c.items.length)}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        for (final z in c.items)
          Builder(builder: (context) {
            final cur = AzkarProgress.get(z.id);
            final finished = cur >= z.count;
            final full = '${z.text}\n\n${z.source}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: finished ? .55 : 1,
                child: Panel(
                  onTap: () => _tap(z),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(z.text, style: const TextStyle(fontSize: 18, height: 2, fontWeight: FontWeight.w600)),
                    if (z.fadl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(z.fadl,
                          style: TextStyle(fontSize: 12.5, height: 1.7, color: cs.primary)),
                    ],
                    const SizedBox(height: 4),
                    Text(z.source,
                        style: TextStyle(fontSize: 11.5, color: cs.onSurface.withAlpha(150))),
                    const SizedBox(height: 6),
                    Row(children: [
                      FavButton(type: 'zikr', id: z.id, text: z.text, source: z.source),
                      IconButton(onPressed: () => copyText(context, full), icon: const Icon(Icons.copy_rounded)),
                      IconButton(onPressed: () => shareText(context, full), icon: const Icon(Icons.share_rounded)),
                      const Spacer(),
                      if (finished)
                        const Icon(Icons.check_circle, color: gold, size: 32)
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: cs.primary, borderRadius: BorderRadius.circular(14)),
                          child: Text('${ar(cur)} / ${ar(z.count)}',
                              style: TextStyle(
                                  color: cs.onPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
                        ),
                    ]),
                  ]),
                ),
              ),
            );
          }),
      ]),
    );
  }
}
