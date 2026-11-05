import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../core/settings.dart';
import '../data/surahs.dart';
import 'notification_service.dart';
import 'quran_service.dart';

/// مشغّل صوت واحد للتطبيق كله (القرآن + تجربة الأذان) مع إشعار التحكم بالخلفية.
class AudioCtl {
  static final AudioCtl i = AudioCtl._();

  final AudioPlayer player = AudioPlayer();
  final ValueNotifier<int?> surah = ValueNotifier(null);
  final ValueNotifier<String?> previewLabel = ValueNotifier(null);
  bool _advancing = false;

  AudioCtl._() {
    player.playerStateStream.listen((st) {
      if (st.processingState == ProcessingState.completed) {
        final n = surah.value;
        if (n != null && previewLabel.value == null) {
          if (Settings.i.autoNext && n < 114 && !_advancing) {
            _advancing = true;
            playSurah(n + 1).whenComplete(() => _advancing = false);
          }
        } else if (previewLabel.value != null) {
          previewLabel.value = null;
        }
      }
    });
  }

  Future<void> playSurah(int n) async {
    final s = surahs[n - 1];
    final rec = reciterById(Settings.i.reciter);
    final tag = MediaItem(
      id: '${rec.id}-$n',
      title: 'سورة ${s.name}',
      artist: rec.name,
      album: 'القرآن الكريم - سكينة',
    );
    final local = await QuranService.audioFile(rec.id, n);
    final source = await local.exists()
        ? AudioSource.uri(Uri.file(local.path), tag: tag)
        : AudioSource.uri(Uri.parse(rec.urlFor(n)), tag: tag);
    previewLabel.value = null;
    surah.value = n;
    await player.setVolume(1.0);
    await player.setAudioSource(source);
    unawaited(player.play());
  }

  Future<void> previewAdhan(Muezzin m, {bool fajr = false}) async {
    final path = (fajr && m.hasFajr) ? m.fajrAssetPath! : m.assetPath;
    final tag = MediaItem(
      id: 'adhan-${m.id}',
      title: fajr ? 'أذان الفجر' : 'الأذان',
      artist: m.label,
    );
    surah.value = null;
    previewLabel.value = m.label;
    await player.setVolume(Settings.i.volume);
    await player.setAudioSource(AudioSource.asset(path, tag: tag));
    unawaited(player.play());
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      unawaited(player.play());
    }
  }

  Future<void> stop() async {
    await player.stop();
    previewLabel.value = null;
  }
}
