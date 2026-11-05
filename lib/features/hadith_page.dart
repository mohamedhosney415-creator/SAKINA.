import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/hadiths.dart';

String _norm(String t) => t
    .replaceAll(RegExp('[\u064B-\u065F\u0670]'), '')
    .replaceAll('أ', 'ا')
    .replaceAll('إ', 'ا')
    .replaceAll('آ', 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي');

class HadithPage extends StatefulWidget {
  const HadithPage({super.key});
  @override
  State<HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<HadithPage> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qn = _norm(q.trim());
    final list = hadiths
        .where((h) => qn.isEmpty || _norm('${h.text} ${h.narrator} ${h.source}').contains(qn))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('الأحاديث النبوية')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ابحث في نص الحديث أو الراوي أو المصدر',
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: Icons.search_off, text: 'لا توجد أحاديث مطابقة')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final h = list[i];
                    final src = '${h.narrator} • ${h.source} • الدرجة: ${h.grade}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('«${h.text}»',
                              style: const TextStyle(fontSize: 18, height: 2, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('الراوي: ${h.narrator}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('المصدر والتخريج: ${h.source}',
                              style: TextStyle(fontSize: 12.5, color: cs.onSurface.withAlpha(170))),
                          const SizedBox(height: 6),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.verified, size: 16, color: gold),
                            label: Text('الدرجة: ${h.grade}', style: const TextStyle(fontSize: 12)),
                          ),
                          ContentActions(type: 'hadith', id: h.id, text: h.text, source: src),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
