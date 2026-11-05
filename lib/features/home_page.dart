import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/noor_service.dart';
import '../services/prayer_service.dart';
import 'adhan_settings_page.dart';
import 'azkar_page.dart';
import 'calendar_page.dart';
import 'city_picker.dart';
import 'hadith_page.dart';
import 'khatma_page.dart';
import 'noor_page.dart';
import 'qibla_page.dart';
import 'ramadan_page.dart';
import 'tasbeeh_page.dart';
import 'quran_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _greeting(DateTime now) {
    final n = Settings.i.userName.trim();
    final g = now.hour < 12 ? 'صباح الخير' : (now.hour < 17 ? 'نهارك سعيد' : 'مساء الخير');
    return n.isEmpty ? '$g، السلام عليكم' : '$g يا $n';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Settings.i,
      builder: (context, _) {
        final now = cairoNow();
        final today = DateTime(now.year, now.month, now.day);
        final day = PrayerService.forDate(today);
        final next = PrayerService.next(now);
        final cur = PrayerService.current(now);
        final s = Settings.i;
        final adhanOn = s.adhanOn && s.notificationsOn;
        final noor = NoorService.forDay(today);

        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          HeroCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(now),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${fmtHijri(today)}  •  ${fmtDate(today)}',
                  style: TextStyle(color: Colors.white.withAlpha(215), fontSize: 12.5)),
              const SizedBox(height: 14),
              Row(children: [
                ActionChip(
                  avatar: const Icon(Icons.location_on, size: 16, color: goldDeep),
                  label: Text(s.cityName),
                  onPressed: () => go(context, const CityPickerPage()),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(adhanOn ? Icons.volume_up : Icons.volume_off, size: 16),
                  label: Text(adhanOn ? 'الأذان مفعّل' : 'الأذان متوقف'),
                  onPressed: () => go(context, const AdhanSettingsPage()),
                ),
              ]),
              const SizedBox(height: 18),
              Text('الصلاة القادمة: ${prayerAr[next.prayer]}',
                  style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 14)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmtDur(next.at.difference(now)),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text('عند ${fmtTime(next.at)}',
                      style: const TextStyle(color: gold, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
          const SectionTitle('مواقيت اليوم'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Panel(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Column(children: [
                for (final p in Prayer.values)
                  _row(context, p, day.t[p]!, p == next.prayer, p == cur),
              ]),
            ),
          ),
          const SectionTitle('اختصارات'),
          _shortcuts(context),
          const SectionTitle('نور يومك'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Panel(
              onTap: () => go(context, const NoorPage()),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.wb_twilight_rounded, color: gold, size: 20),
                  const SizedBox(width: 6),
                  Text(noor.label,
                      style: const TextStyle(color: goldDeep, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                Text(noor.text,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, height: 1.9, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(noor.sourceLine,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                ContentActions(
                    type: noor.favType,
                    id: noor.id,
                    text: noor.text,
                    source: noor.sourceLine),
              ]),
            ),
          ),
          const DeveloperSignature(),
        ]);
      },
    );
  }

  Widget _row(BuildContext context, Prayer p, DateTime t, bool isNext, bool isCur) {
    final cs = Theme.of(context).colorScheme;
    final s = Settings.i;
    final isFard = p != Prayer.sunrise;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isNext ? cs.primary.withAlpha(30) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(
            isNext
                ? Icons.notifications_active
                : (isCur ? Icons.radio_button_checked : Icons.circle_outlined),
            size: 18,
            color: isNext ? cs.primary : (isCur ? gold : cs.onSurface.withAlpha(90))),
        const SizedBox(width: 10),
        Expanded(
            child: Text(prayerAr[p]!,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: isNext ? FontWeight.w900 : FontWeight.w600))),
        Text(fmtTime(t),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isNext ? cs.primary : null)),
        const SizedBox(width: 6),
        if (isFard)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'تشغيل/إيقاف الأذان',
            icon: Icon(
                s.adhanFor(p.name) ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: 20,
                color: s.adhanFor(p.name) ? cs.primary : cs.onSurface.withAlpha(90)),
            onPressed: () => s.set('adhan_${p.name}', !s.adhanFor(p.name)),
          )
        else
          const SizedBox(width: 40),
      ]),
    );
  }

  Widget _shortcuts(BuildContext context) {
    final items = <(String, IconData, Widget)>[
      ('القرآن', Icons.menu_book_rounded, const QuranPage(standalone: true)),
      ('الأذكار', Icons.auto_awesome_rounded, const AzkarPage(standalone: true)),
      ('المسبحة', Icons.touch_app_rounded, const TasbeehPage()),
      ('القبلة', Icons.explore_rounded, const QiblaPage()),
      ('الختمة', Icons.flag_rounded, const KhatmaPage()),
      ('الأحاديث', Icons.format_quote_rounded, const HadithPage()),
      ('التقويم', Icons.calendar_month_rounded, const CalendarPage()),
      ('رمضان', Icons.dark_mode_rounded, const RamadanPage()),
    ];
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .86,
        children: [
          for (final it in items)
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => go(context, it.$3),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(22),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(it.$2, color: cs.primary, size: 28),
                  const SizedBox(height: 6),
                  Text(it.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
