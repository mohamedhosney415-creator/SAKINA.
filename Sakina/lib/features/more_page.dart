import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'about_page.dart';
import 'calendar_page.dart';
import 'favorites_page.dart';
import 'hadith_page.dart';
import 'khatma_page.dart';
import 'noor_page.dart';
import 'qibla_page.dart';
import 'ramadan_page.dart';
import 'settings_page.dart';
import 'tasbeeh_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData, Widget)>[
      ('مساعد الختمة', 'خطة ورد يومي وتتبع الإنجاز', Icons.flag_rounded, const KhatmaPage()),
      ('المسبحة الإلكترونية', 'عداد وإحصائيات التسبيح', Icons.touch_app_rounded, const TasbeehPage()),
      ('القبلة', 'بوصلة تعمل بدون إنترنت', Icons.explore_rounded, const QiblaPage()),
      ('نور يومك', 'حديث أو حكمة جديدة كل يوم', Icons.wb_twilight_rounded, const NoorPage()),
      ('الأحاديث النبوية', 'مكتبة مع التخريج والدرجة', Icons.format_quote_rounded, const HadithPage()),
      ('التقويم الإسلامي', 'المناسبات والأيام المباركة', Icons.calendar_month_rounded, const CalendarPage()),
      ('رمضان والصيام', 'إمساكية وصيام وقضاء وعبادات', Icons.dark_mode_rounded, const RamadanPage()),
      ('المفضلة', 'كل ما حفظته في مكان واحد', Icons.favorite_rounded, const FavoritesPage()),
      ('الإعدادات', 'الأذان والمدينة والمظهر والنسخ الاحتياطي', Icons.settings_rounded, const SettingsPage()),
      ('عن التطبيق', 'سكينة ٣٫٠', Icons.info_rounded, const AboutPage()),
    ];
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('المزيد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      ),
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            onTap: () => go(context, it.$4),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: cs.primary.withAlpha(26), borderRadius: BorderRadius.circular(14)),
                child: Icon(it.$3, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Text(it.$2, style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(150))),
                ]),
              ),
              const Icon(Icons.chevron_left, color: gold),
            ]),
          ),
        ),
      const DeveloperSignature(),
    ]);
  }
}
