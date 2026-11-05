import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/surahs.dart';
import '../services/audio_controller.dart';
import '../services/favorites.dart';
import '../services/quran_service.dart';
import 'quran_page.dart';

class SurahReaderPage extends StatefulWidget {
  final int number;
  final int? ayah;
  const SurahReaderPage({super.key, required this.number, this.ayah});
  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  late Future<List<Ayah>> fut;
  final sc = ScrollController();
  double? restore;
  bool restored = false;
  bool downloaded = false;
  double? dl; // تقدم تحميل الصوت

  Surah get surah => surahs[widget.number - 1];

  @override
  void initState() {
    super.initState();
    fut = QuranService.text(widget.number);
    final last = Store.json('lastread');
    if (last is Map && last['s'] == widget.number && last['off'] is num) {
      restore = (last['off'] as num).toDouble();
    }
    _checkDl();
  }

  Future<void> _checkDl() async {
    final d = await QuranService.isDownloaded(Settings.i.reciter, widget.number);
    if (mounted) setState(() => downloaded = d);
  }

  Future<void> _saveLast({int? ayah}) async {
    final prev = Store.json('lastread');
    await Store.setJson('lastread', {
      's': widget.number,
      'off': sc.hasClients ? sc.offset : 0,
      if (ayah != null) 'ayah': ayah else if (prev is Map && prev['s'] == widget.number && prev['ayah'] != null) 'ayah': prev['ayah'],
    });
  }

  @override
  void dispose() {
    _saveLast();
    sc.dispose();
    super.dispose();
  }

  void _tryRestore() {
    if (restored || restore == null) return;
    restored = true;
    void jump() {
      if (sc.hasClients) sc.jumpTo(restore!.clamp(0.0, sc.position.maxScrollExtent).toDouble());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      jump();
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    });
  }

  Future<void> _download() async {
    if (downloaded) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('حذف التلاوة المحمّلة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
          ],
        ),
      );
      if (ok == true) {
        await QuranService.deleteAudio(Settings.i.reciter, widget.number);
        await _checkDl();
      }
      return;
    }
    setState(() => dl = 0);
    try {
      await QuranService.downloadAudio(Settings.i.reciter, widget.number,
          onProgress: (p) {
        if (mounted) setState(() => dl = p);
      });
      if (mounted) toast(context, 'تم التحميل، ستسمعها دون إنترنت');
    } catch (_) {
      if (mounted) toast(context, 'تعذر التحميل، تحقق من الاتصال');
    }
    if (mounted) setState(() => dl = null);
    await _checkDl();
  }

  void _ayahSheet(Ayah a) {
    final id = '${widget.number}:${a.n}';
    final title = 'سورة ${surah.name} • آية ${ar(a.n)}';
    final full = '﴿${a.text}﴾\n[${surah.name}: ${ar(a.n)}]';
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('نسخ الآية'),
            onTap: () {
              Navigator.pop(context);
              copyText(context, full);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('مشاركة الآية'),
            onTap: () {
              Navigator.pop(context);
              shareText(context, full);
            },
          ),
          ListTile(
            leading: Icon(Favorites.i.has('ayah', id) ? Icons.favorite : Icons.favorite_border),
            title: Text(Favorites.i.has('ayah', id) ? 'إزالة من المفضلة' : 'إضافة للمفضلة'),
            onTap: () async {
              Navigator.pop(context);
              await Favorites.i.toggle('ayah', id, title: title, text: '﴿${a.text}﴾');
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: Icon(Favorites.i.has('bookmark', id) ? Icons.bookmark : Icons.bookmark_border),
            title: Text(Favorites.i.has('bookmark', id) ? 'إزالة العلامة المرجعية' : 'وضع علامة مرجعية'),
            onTap: () async {
              Navigator.pop(context);
              await Favorites.i.toggle('bookmark', id, title: title, text: '﴿${a.text}﴾');
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.push_pin_outlined),
            title: const Text('حفظ كآخر موضع قراءة'),
            onTap: () async {
              Navigator.pop(context);
              await _saveLast(ayah: a.n);
              if (mounted) toast(context, 'تم حفظ موضع القراءة');
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('سورة ${surah.name}'),
        actions: [
          if (dl != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 3, value: dl! > 0 ? dl : null)),
            )
          else
            IconButton(
              tooltip: downloaded ? 'محمّلة (اضغط للحذف)' : 'تحميل للاستماع دون إنترنت',
              icon: Icon(downloaded ? Icons.offline_pin : Icons.download_for_offline_outlined,
                  color: downloaded ? gold : null),
              onPressed: _download,
            ),
          IconButton(
            tooltip: 'استماع',
            icon: const Icon(Icons.headphones_rounded),
            onPressed: () async {
              try {
                await AudioCtl.i.playSurah(widget.number);
              } catch (_) {
                if (mounted) toast(context, 'تعذر التشغيل. تحقق من الإنترنت أو حمّل السورة');
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        AudioBar(onlySurah: widget.number),
        Expanded(
          child: FutureBuilder<List<Ayah>>(
            future: fut,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError || snap.data == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off, size: 54, color: gold),
                      const SizedBox(height: 12),
                      const Text(
                          'لا يوجد اتصال، ولم يُحفظ نص هذه السورة بعد.\nاتصل بالإنترنت مرة واحدة لتُحفظ للقراءة دون اتصال.',
                          textAlign: TextAlign.center,
                          style: TextStyle(height: 1.8)),
                      const SizedBox(height: 14),
                      FilledButton(
                          onPressed: () => setState(() => fut = QuranService.text(widget.number)),
                          child: const Text('إعادة المحاولة')),
                    ]),
                  ),
                );
              }
              final ayahs = snap.data!;
              _tryRestore();
              final size = Settings.i.quranFont;
              return NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  _saveLast();
                  return false;
                },
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: gold.withAlpha(140)),
                        borderRadius: BorderRadius.circular(14),
                        color: cs.primary.withAlpha(18),
                      ),
                      child: Column(children: [
                        Text('سورة ${surah.name}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
                        Text('${ar(surah.ayahs)} آية', style: const TextStyle(fontSize: 12)),
                        if (widget.number != 1 && widget.number != 9)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                                style: quranStyle(size, cs.onSurface)),
                          ),
                      ]),
                    ),
                    for (final a in ayahs)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _ayahSheet(a),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: Favorites.i.has('bookmark', '${widget.number}:${a.n}')
                                ? gold.withAlpha(40)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: a.text),
                              TextSpan(
                                  text: ' ﴿${ar(a.n)}﴾ ',
                                  style: const TextStyle(color: gold, fontWeight: FontWeight.w800)),
                            ]),
                            textAlign: TextAlign.justify,
                            style: quranStyle(size, cs.onSurface),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
