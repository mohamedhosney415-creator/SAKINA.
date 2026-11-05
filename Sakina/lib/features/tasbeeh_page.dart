import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

const _presets = <String>[
  'سُبْحَانَ اللَّهِ',
  'الْحَمْدُ لِلَّهِ',
  'اللَّهُ أَكْبَرُ',
  'لَا إِلَهَ إِلَّا اللَّهُ',
  'أَسْتَغْفِرُ اللَّهَ',
  'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
  'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
  'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
];

class TasbeehPage extends StatefulWidget {
  const TasbeehPage({super.key});
  @override
  State<TasbeehPage> createState() => _TasbeehPageState();
}

class _TasbeehPageState extends State<TasbeehPage> {
  late String selected;
  List<String> custom = [];
  Map<String, dynamic> cur = {};
  Map<String, dynamic> stats = {};

  @override
  void initState() {
    super.initState();
    final c = Store.json('tasbeeh_custom', []);
    custom = c is List ? c.map((e) => '$e').toList() : [];
    final cu = Store.json('tasbeeh_cur', {});
    cur = cu is Map ? Map<String, dynamic>.from(cu) : {};
    final st = Store.json('tasbeeh_stats', {});
    stats = st is Map ? Map<String, dynamic>.from(st) : {};
    selected = Store.str('tasbeeh_sel', _presets.first);
    if (![..._presets, ...custom].contains(selected)) selected = _presets.first;
  }

  int get target => Settings.i.intOf('tasbeehTarget', 33);
  int get count => ((cur[selected] ?? 0) as num).toInt();

  Map<String, dynamic> _today() {
    final k = dayKey(DateTime.now());
    return stats[k] is Map ? Map<String, dynamic>.from(stats[k]) : <String, dynamic>{};
  }

  Future<void> _tap() async {
    final next = count + 1;
    cur[selected] = next;
    final k = dayKey(DateTime.now());
    final t = _today();
    t[selected] = ((t[selected] ?? 0) as num).toInt() + 1;
    stats[k] = t;
    final keys = stats.keys.toList()..sort();
    while (keys.length > 30) {
      stats.remove(keys.removeAt(0));
    }
    if (Settings.i.haptic) {
      if (target > 0 && next % target == 0) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
    setState(() {});
    await Store.setJson('tasbeeh_cur', cur);
    await Store.setJson('tasbeeh_stats', stats);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تصفير العداد؟'),
        content: const Text('سيُصفَّر عدّاد هذا الذكر فقط. إحصائيات اليوم تبقى كما هي.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تصفير')),
        ],
      ),
    );
    if (ok != true) return;
    cur[selected] = 0;
    setState(() {});
    await Store.setJson('tasbeeh_cur', cur);
  }

  Future<void> _addCustom() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة ذكر خاص'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'اكتب الذكر')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إضافة')),
        ],
      ),
    );
    final t = c.text.trim();
    if (ok == true && t.isNotEmpty && !custom.contains(t) && !_presets.contains(t)) {
      custom.add(t);
      selected = t;
      setState(() {});
      await Store.setJson('tasbeeh_custom', custom);
      await Store.setStr('tasbeeh_sel', t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = _today();
    int todayTotal = 0;
    for (final v in today.values) {
      todayTotal += (v as num).toInt();
    }
    final prog = target > 0 ? (count % target) / target : 0.0;
    final laps = target > 0 ? count ~/ target : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('المسبحة'), actions: [
        IconButton(
          tooltip: Settings.i.haptic ? 'إيقاف الاهتزاز' : 'تشغيل الاهتزاز',
          icon: Icon(Settings.i.haptic ? Icons.vibration : Icons.mobile_off),
          onPressed: () async {
            await Settings.i.set('haptic', !Settings.i.haptic);
            setState(() {});
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final z in [..._presets, ...custom])
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(z),
                  selected: selected == z,
                  onSelected: (_) async {
                    setState(() => selected = z);
                    await Store.setStr('tasbeeh_sel', z);
                  },
                ),
              ),
            ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('ذكر خاص'),
                onPressed: _addCustom),
          ]),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Text(selected,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, height: 1.9, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 22),
        Center(
          child: GestureDetector(
            onTap: _tap,
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: target > 0 ? (prog == 0 && count > 0 ? 1.0 : prog) : 0,
                    strokeWidth: 10,
                    backgroundColor: cs.primary.withAlpha(30),
                    color: gold,
                  ),
                ),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [cs.primary, Color.lerp(cs.primary, Colors.black, .4)!],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft),
                    boxShadow: [BoxShadow(color: cs.primary.withAlpha(90), blurRadius: 22)],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(ar(count),
                        style: const TextStyle(color: Colors.white, fontSize: 58, fontWeight: FontWeight.w900)),
                    if (target > 0)
                      Text('الهدف ${ar(target)} • الدورات ${ar(laps)}',
                          style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          for (final t in const [33, 100, 1000, 0])
            ChoiceChip(
              label: Text(t == 0 ? 'بلا هدف' : ar(t)),
              selected: target == t,
              onSelected: (_) async {
                await Settings.i.set('tasbeehTarget', t);
                setState(() {});
              },
            ),
        ]),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
              onPressed: _reset, icon: const Icon(Icons.restart_alt), label: const Text('تصفير العداد')),
        ),
        const SectionTitle('إحصائيات التسبيح'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('تسبيح اليوم: ${ar(todayTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            if (today.isEmpty)
              Text('ابدأ التسبيح وستظهر إحصائياتك هنا.',
                  style: TextStyle(color: cs.onSurface.withAlpha(150)))
            else
              for (final e in today.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(ar((e.value as num).toInt()), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
            const Divider(height: 24),
            Builder(builder: (context) {
              int week = 0;
              final now = DateTime.now();
              for (int i = 0; i < 7; i++) {
                final d = DateTime(now.year, now.month, now.day - i);
                final m = stats[dayKey(d)];
                if (m is Map) {
                  for (final v in m.values) {
                    week += (v as num).toInt();
                  }
                }
              }
              return Text('آخر ٧ أيام: ${ar(week)}');
            }),
          ]),
        ),
      ]),
    );
  }
}
