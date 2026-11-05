import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../data/surahs.dart';

class Ayah {
  final int n;
  final String text;
  Ayah(this.n, this.text);
}

/// القرّاء. لإضافة قارئ جديد: أضف عنصرًا هنا بنمط رابط يحتوي {n} (رقم السورة).
class Reciter {
  final String id, name, urlPattern;
  const Reciter(this.id, this.name, this.urlPattern);
  String urlFor(int surah) => urlPattern.replaceAll('{n}', '$surah');
}

const reciters = <Reciter>[
  Reciter('afasy', 'الشيخ مشاري العفاسي',
      'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/{n}.mp3'),
];

Reciter reciterById(String id) =>
    reciters.firstWhere((r) => r.id == id, orElse: () => reciters.first);

class DownloadedFile {
  final String reciter;
  final int surah;
  final int bytes;
  final File file;
  DownloadedFile(this.reciter, this.surah, this.bytes, this.file);
}

class QuranService {
  static Future<Directory> _dir(String sub) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/$sub');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // ---------- النص ----------
  static String _plain(String s) => s
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll('ٱ', 'ا');

  /// النص من المصدر يبدأ بالبسملة في أول آية؛ نفصلها لنعرضها كسطر مستقل.
  static String _stripBasmala(String t) {
    final words = t.trim().split(RegExp(r'\s+'));
    if (words.length > 4 &&
        _plain(words.sublist(0, 4).join(' ')) == 'بسم الله الرحمن الرحيم') {
      return words.sublist(4).join(' ');
    }
    return t;
  }

  static List<Ayah> _parse(int surah, List list) {
    final out = <Ayah>[];
    for (final a in list) {
      final n = (a['n'] as num).toInt();
      var t = a['t'].toString();
      if (n == 1 && surah != 1 && surah != 9) t = _stripBasmala(t);
      out.add(Ayah(n, t));
    }
    return out;
  }

  static Future<File> _textFile(int s) async =>
      File('${(await _dir('quran_text')).path}/$s.json');

  static Future<bool> hasText(int s) async => (await _textFile(s)).exists();

  /// يقرأ من التخزين المحلي، وإن لم يوجد يحمّله مرة واحدة ويحفظه.
  static Future<List<Ayah>> text(int s) async {
    final f = await _textFile(s);
    if (await f.exists()) {
      try {
        return _parse(s, jsonDecode(await f.readAsString()) as List);
      } catch (_) {
        await f.delete();
      }
    }
    final r = await http
        .get(Uri.parse('https://api.alquran.cloud/v1/surah/$s/quran-uthmani'))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('quran-text');
    final data = jsonDecode(utf8.decode(r.bodyBytes))['data']['ayahs'] as List;
    final list = data
        .map((a) => {'n': a['numberInSurah'], 't': a['text']})
        .toList();
    await f.writeAsString(jsonEncode(list));
    return _parse(s, list);
  }

  static Future<int> cachedTextCount() async {
    final d = await _dir('quran_text');
    return d.listSync().whereType<File>().length;
  }

  static Future<void> downloadAllText(
      {void Function(int done)? onProgress}) async {
    for (final s in surahs) {
      if (!await hasText(s.number)) {
        await text(s.number);
      }
      onProgress?.call(s.number);
    }
  }

  static Future<void> clearText() async {
    final d = await _dir('quran_text');
    for (final f in d.listSync()) {
      try {
        f.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  // ---------- الصوت ----------
  static Future<File> audioFile(String reciter, int s) async =>
      File('${(await _dir('audio/$reciter')).path}/${s.toString().padLeft(3, '0')}.mp3');

  static Future<bool> isDownloaded(String reciter, int s) async =>
      (await audioFile(reciter, s)).exists();

  static Future<void> downloadAudio(String reciterId, int s,
      {void Function(double p)? onProgress}) async {
    final rec = reciterById(reciterId);
    final client = http.Client();
    try {
      final res = await client
          .send(http.Request('GET', Uri.parse(rec.urlFor(s))))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('audio ${res.statusCode}');
      final total = res.contentLength ?? 0;
      final file = await audioFile(reciterId, s);
      final tmp = File('${file.path}.part');
      final sink = tmp.openWrite();
      int got = 0;
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress?.call(got / total);
        }
      } finally {
        await sink.close();
      }
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } finally {
      client.close();
    }
  }

  static Future<void> deleteAudio(String reciter, int s) async {
    final f = await audioFile(reciter, s);
    if (await f.exists()) await f.delete();
  }

  static Future<List<DownloadedFile>> downloadedAudio() async {
    final out = <DownloadedFile>[];
    for (final r in reciters) {
      final d = await _dir('audio/${r.id}');
      for (final e in d.listSync().whereType<File>()) {
        final name = e.path.split('/').last;
        if (!name.endsWith('.mp3')) continue;
        final n = int.tryParse(name.replaceAll('.mp3', ''));
        if (n == null || n < 1 || n > 114) continue;
        out.add(DownloadedFile(r.id, n, e.lengthSync(), e));
      }
    }
    out.sort((a, b) => a.surah.compareTo(b.surah));
    return out;
  }
}
