import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('عن التطبيق')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        HeroCard(
          margin: EdgeInsets.zero,
          child: Column(children: [
            const Icon(Icons.nightlight_round, color: gold, size: 54),
            const SizedBox(height: 8),
            const Text('SAKINA', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4)),
            const Text('سكينة', style: TextStyle(color: gold, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('الإصدار ٣٫٠٫٠', style: TextStyle(color: Colors.white.withAlpha(200))),
          ]),
        ),
        const SizedBox(height: 18),
        const Panel(
          child: Text(
              'تطبيق إسلامي شامل يجمع مواقيت الصلاة والأذان والقرآن الكريم والأذكار ومتابعة العبادة اليومية والتقويم الإسلامي في مكان واحد، ويعمل بأكبر قدر ممكن دون إنترنت.',
              style: TextStyle(height: 1.9, fontSize: 15)),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Text(
              'المواقيت محسوبة بطريقة الهيئة المصرية العامة للمساحة. المحتوى الشرعي منقول من المصادر المذكورة تحته؛ نسأل الله أن يتقبل منا ومنكم.',
              style: TextStyle(height: 1.8, color: cs.onSurface.withAlpha(170))),
        ),
        const SizedBox(height: 12),
        const Panel(child: Text('© جميع الحقوق محفوظة لتطبيق سكينة', textAlign: TextAlign.center)),
        const DeveloperSignature(),
      ]),
    );
  }
}
