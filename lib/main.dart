import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'services/favorites.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  Settings.i.load();
  Favorites.i.load();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.hosny.sakina.audio',
      androidNotificationChannelName: 'تشغيل القرآن',
      androidNotificationOngoing: true,
    );
  } catch (_) {}
  await NotificationService.init();
  runApp(const SakinaApp());
}
