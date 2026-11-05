import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/cities.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';

/// اختيار المدينة يدويًا (بدون GPS): بحث بالاسم أو محافظة ثم مدينة.
class CityPickerPage extends StatefulWidget {
  const CityPickerPage({super.key});
  @override
  State<CityPickerPage> createState() => _CityPickerPageState();
}

class _CityPickerPageState extends State<CityPickerPage> {
  String q = '';

  Future<void> _pick(Gov g, City c) async {
    await Settings.i.set('gov', g.name);
    await Settings.i.set('city', c.name);
    PrayerService.clearCache();
    await NotificationService.ensureScheduled(force: true);
    if (!mounted) return;
    toast(context, 'تم اختيار ${c.name} وإعادة جدولة الأذان');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final results = Cities.search(q);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('اختيار المدينة')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ابحث باسم المدينة أو المحافظة...',
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        Expanded(
          child: q.trim().isNotEmpty
              ? (results.isEmpty
                  ? const EmptyState(icon: Icons.search_off, text: 'لا توجد نتائج مطابقة')
                  : ListView(children: [
                      for (final e in results)
                        ListTile(
                          leading: const Icon(Icons.location_city, color: gold),
                          title: Text(e.value.name),
                          subtitle: Text(e.key.name),
                          trailing: _isCurrent(e.key, e.value)
                              ? Icon(Icons.check_circle, color: cs.primary)
                              : null,
                          onTap: () => _pick(e.key, e.value),
                        ),
                    ]))
              : ListView(children: [
                  for (final g in Cities.all)
                    ExpansionTile(
                      leading: const Icon(Icons.map_outlined),
                      title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${ar(g.cities.length)} مدينة/مركز'),
                      initiallyExpanded: g.name == Settings.i.gov,
                      children: [
                        for (final c in g.cities)
                          ListTile(
                            contentPadding: const EdgeInsets.only(right: 40, left: 16),
                            title: Text(c.name),
                            trailing: _isCurrent(g, c)
                                ? Icon(Icons.check_circle, color: cs.primary)
                                : null,
                            onTap: () => _pick(g, c),
                          ),
                      ],
                    ),
                ]),
        ),
      ]),
    );
  }

  bool _isCurrent(Gov g, City c) =>
      g.name == Settings.i.gov && c.name == Settings.i.cityName;
}
