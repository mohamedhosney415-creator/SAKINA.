import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/surahs.dart';
import '../services/audio_controller.dart';
import '../services/quran_service.dart';
import 'downloads_page.dart';
import 'favorites_page.dart';
import 'reader_page.dart';

String _norm(String t) => t
    .replaceAll(RegExp('[\u064B-\u065F]'), '')
    .replaceAll('أ', 'ا')
    .replaceAll('إ', 'ا')
    .replaceAll('آ', 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .trim();

/// شريط تشغيل الصوت. إذا مُرّر [onlySurah] يظهر فقط عند تشغيل تلك السورة.
class AudioBar extends StatelessWidget {
  final int? onlySurah;
  const AudioBar({super.key, this.onlySurah});

  @override
  Widget build(BuildContext context) {
    final c = AudioCtl.i;
    return ValueListenableBuilder<int?>(
      valueListenable: c.surah,
      builder: (context, n, _) {
        if (n == null || (onlySurah != null && n != onlySurah)) {
          return const SizedBox.shrink();
        }
        final cs = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          decoration: BoxDecoration(
            color: cs.primary.withAlpha(28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: gold.withAlpha(90)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Text('سورة ${surahs[n - 1].name} • ${reciterById('afasy').name}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              PopupMenuButton<double>(
                tooltip: 'السرعة',
                icon: const Icon(Icons.speed, size: 20),
                onSelected: (v) => c.player.setSpeed(v),
                itemBuilder: (_) => [
                  for (final v in const [0.75, 1.0, 1.25, 1.5])
                    PopupMenuItem(value: v, child: Text('${ar(v)}x')),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20),
                onPressed: () async {
                  await c.stop();
                  c.surah.value = null;
                },
              ),
            ]),
            StreamBuilder<Duration?>(
              stream: c.player.durationStream,
              builder: (context, ds) {
                final dur = ds.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: c.player.positionStream,
                  builder: (context, ps) {
                    final pos = ps.data ?? Duration.zero;
                    final max = dur.inMilliseconds.toDouble();
                    final v = pos.inMilliseconds.toDouble().clamp(0.0, max > 0 ? max : 1.0).toDouble();
                    return Row(children: [
                      Text(fmtDur(pos).substring(3), style: const TextStyle(fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: v,
                          max: max > 0 ? max : 1.0,
                          onChanged: max > 0
                              ? (x) => c.player.seek(Duration(milliseconds: x.toInt()))
                              : null,
                        ),
                      ),
                      Text(fmtDur(dur).substring(3), style: const TextStyle(fontSize: 11)),
                    ]);
                  },
                );
              },
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  onPressed: n > 1 ? () => c.playSurah(n - 1) : null,
                  icon: const Icon(Icons.skip_next_rounded)),
              IconButton(
                  onPressed: () => c.player.seek(c.player.position - const Duration(seconds: 10)),
                  icon: const Icon(Icons.replay_10_rounded)),
              StreamBuilder<bool>(
                stream: c.player.playingStream,
                builder: (context, s) => IconButton.filled(
                  iconSize: 30,
                  onPressed: c.toggle,
                  icon: Icon(s.data == true ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
              ),
              IconButton(
                  onPressed: () => c.player.seek(c.player.position + const Duration(seconds: 10)),
                  icon: const Icon(Icons.forward_10_rounded)),
              IconButton(
                  onPressed: n < 114 ? () => c.playSurah(n + 1) : null,
                  icon: const Icon(Icons.skip_previous_rounded)),
            ]),
          ]),
        );
      },
    );
  }
}

class QuranPage extends StatefulWidget {
  final bool standalone;
  const QuranPage({super.key, this.standalone = false});
  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  String q = '';
  Set<int> downloaded = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final f = await QuranService.downloadedAudio();
    if (mounted) setState(() => downloaded = f.map((e) => e.surah).toSet());
  }

  Future<void> _open(int n, {int? ayah}) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SurahReaderPage(number: n, ayah: ayah)));
    if (mounted) {
      setState(() {});
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qn = _norm(q);
    final list = surahs.where((s) => qn.isEmpty || _norm(s.name).contains(qn) || '${s.number}' == qn).toList();
    final last = Store.json('lastread');
    final hasLast = last is Map && last['s'] is num;

    return Standalone(
      on: widget.standalone,
      title: 'القرآن الكريم',
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(children: [
            const Expanded(
                child: Text('القرآن الكريم',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            IconButton(
                tooltip: 'العلامات والمفضلة',
                onPressed: () => go(context, const FavoritesPage()),
                icon: const Icon(Icons.bookmark_border_rounded)),
            IconButton(
                tooltip: 'التحميلات',
                onPressed: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const DownloadsPage()));
                  _refresh();
                },
                icon: const Icon(Icons.download_for_offline_outlined)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ابحث عن سورة بالاسم أو الرقم',
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        if (hasLast && q.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Panel(
              color: cs.primary.withAlpha(24),
              onTap: () => _open((last['s'] as num).toInt()),
              child: Row(children: [
                const Icon(Icons.history_edu, color: gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'تابع القراءة: سورة ${surahs[(last['s'] as num).toInt() - 1].name}'
                      '${last['ayah'] is num ? ' • آية ${ar((last['ayah'] as num).toInt())}' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const Icon(Icons.chevron_left),
              ]),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              final isDl = downloaded.contains(s.number);
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: gold, width: 1.6),
                  ),
                  child: Text(ar(s.number),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                title: Text('سورة ${s.name}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Row(children: [
                  Text('${ar(s.ayahs)} آية'),
                  if (isDl) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.offline_pin, size: 14, color: gold),
                    const Text(' محمّلة', style: TextStyle(fontSize: 11)),
                  ],
                ]),
                trailing: IconButton(
                  icon: Icon(Icons.play_circle_fill_rounded, color: cs.primary, size: 30),
                  onPressed: () async {
                    try {
                      await AudioCtl.i.playSurah(s.number);
                    } catch (_) {
                      if (context.mounted) {
                        toast(context, 'تعذر التشغيل. تحقق من الإنترنت أو حمّل السورة أولًا');
                      }
                    }
                  },
                ),
                onTap: () => _open(s.number),
              );
            },
          ),
        ),
        const AudioBar(),
      ]),
    );
  }
}
