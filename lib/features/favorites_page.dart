import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/favorites.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  static const tabs = <(String, String, IconData)>[
    ('ayah', 'الآيات', Icons.menu_book),
    ('bookmark', 'العلامات', Icons.bookmark),
    ('hadith', 'الأحاديث', Icons.format_quote),
    ('zikr', 'الأذكار', Icons.auto_awesome),
    ('wisdom', 'الحكم', Icons.lightbulb_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المفضلة'),
          bottom: TabBar(isScrollable: true, tabs: [for (final t in tabs) Tab(text: t.$2)]),
        ),
        body: ListenableBuilder(
          listenable: Favorites.i,
          builder: (context, _) => TabBarView(children: [
            for (final t in tabs) _list(context, t.$1),
          ]),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, String type) {
    // الحكم تشمل الحكمة والحديث القادم من "نور يومك" بنفس النوع
    final items = Favorites.i.byType(type);
    if (items.isEmpty) {
      return const EmptyState(
          icon: Icons.favorite_border, text: 'لا يوجد شيء هنا بعد.\nاضغط على القلب في أي محتوى لحفظه.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        final text = (e['text'] ?? '').toString();
        final title = (e['title'] ?? '').toString();
        final source = (e['source'] ?? '').toString();
        final full = source.isEmpty ? text : '$text\n\n$source';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title.isNotEmpty)
                Text(title, style: const TextStyle(color: goldDeep, fontWeight: FontWeight.w800)),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(fontSize: 16.5, height: 1.9)),
              ],
              if (source.isNotEmpty)
                Text(source,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
              Row(children: [
                IconButton(
                    onPressed: () => copyText(context, full),
                    icon: const Icon(Icons.copy_rounded)),
                IconButton(
                    onPressed: () => shareText(context, full),
                    icon: const Icon(Icons.share_rounded)),
                const Spacer(),
                IconButton(
                  tooltip: 'حذف',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => Favorites.i.toggle(type, e['id'].toString()),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
