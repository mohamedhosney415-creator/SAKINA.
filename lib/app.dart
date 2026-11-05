import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/settings.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'features/azkar_page.dart';
import 'features/home_page.dart';
import 'features/more_page.dart';
import 'features/prayer_page.dart';
import 'features/quran_page.dart';
import 'services/notification_service.dart';

class SakinaApp extends StatefulWidget {
  const SakinaApp({super.key});
  @override
  State<SakinaApp> createState() => _SakinaAppState();
}

class _SakinaAppState extends State<SakinaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  Future<void> _startup() async {
    if (!Store.flag('permAsked')) {
      await NotificationService.requestPermissions();
      await Store.setFlag('permAsked', true);
    }
    await NotificationService.ensureScheduled();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.ensureScheduled();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.i,
      builder: (context, _) {
        final s = Settings.i;
        return MaterialApp(
          title: 'سكينة',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: const [
            ThemeMode.system, ThemeMode.light, ThemeMode.dark
          ][s.themeMode.clamp(0, 2)],
          theme: buildTheme(Brightness.light, s.accent, s.font),
          darkTheme: buildTheme(Brightness.dark, s.accent, s.font),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(s.fontScale)),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: const Shell(),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[
      HomePage(),
      PrayerPage(),
      QuranPage(),
      AzkarPage(),
      MorePage(),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.access_time),
              selectedIcon: Icon(Icons.access_time_filled),
              label: 'الصلاة'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'القرآن'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'الأذكار'),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'المزيد'),
        ],
      ),
    );
  }
}
