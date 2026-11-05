import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/widgets.dart';
import '../data/surahs.dart';
import '../services/quran_service.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<DownloadedFile> files = [];
  int textCount = 0;
  int? progress; // سورة حالية أثناء تحميل النص

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await QuranService.downloadedAudio();
    final t = await QuranService.cachedTextCount();
    if (mounted) setState(() { files = f; textCount = t; });
  }

  String _mb(int b) => '${ar((b / 1048576).toStringAsFixed(1))} م.ب';

  Future<void> _downloadText() async {
    setState(() => progress = 0);
    try {
      await QuranService.downloadAllText(onProgress: (n) {
        if (mounted) setState(() => progress = n);
      });
      if (mounted) toast(context, 'تم تحميل نص القرآن كاملًا للقراءة دون إنترنت');
    } catch (_) {
      if (mounted) toast(context, 'تعذر إكمال التحميل، تحقق من الاتصال وحاول ثانية');
    }
    if (mounted) setState(() => progress = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = files.fold<int>(0, (a, b) => a + b.bytes);
    return Scaffold(
      appBar: AppBar(title: const Text('الملفات المحمّلة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('نص القرآن (للقراءة دون إنترنت)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${ar(textCount)} من ١١٤ سورة محفوظة'),
            const SizedBox(height: 10),
            if (progress != null) ...[
              LinearProgressIndicator(value: progress! / 114),
              const SizedBox(height: 6),
              Text('جارٍ التحميل... ${ar(progress!)} / ١١٤'),
            ] else
              Row(children: [
                FilledButton.icon(
                    onPressed: textCount >= 114 ? null : _downloadText,
                    icon: const Icon(Icons.download),
                    label: const Text('تحميل كل السور')),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: textCount == 0
                        ? null
                        : () async {
                            await QuranService.clearText();
                            await _load();
                          },
                    child: const Text('حذف')),
              ]),
          ]),
        ),
        const SectionTitle('التلاوات المحمّلة'),
        if (files.isEmpty)
          const SizedBox(
              height: 200,
              child: EmptyState(
                  icon: Icons.headphones_outlined,
                  text: 'لا توجد تلاوات محمّلة.\nحمّل أي سورة من صفحة القرآن لتسمعها دون إنترنت.'))
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('الإجمالي: ${_mb(total)} • ${ar(files.length)} سورة'),
          ),
          for (final f in files)
            ListTile(
              leading: const Icon(Icons.audiotrack),
              title: Text('سورة ${surahs[f.surah - 1].name}'),
              subtitle: Text(_mb(f.bytes)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await QuranService.deleteAudio(f.reciter, f.surah);
                  await _load();
                },
              ),
            ),
        ],
      ]),
    );
  }
}
