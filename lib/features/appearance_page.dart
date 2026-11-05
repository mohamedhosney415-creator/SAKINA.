import 'package:flutter/material.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التخصيص والمظهر')),
      body: ListenableBuilder(
        listenable: Settings.i,
        builder: (context, _) {
          final s = Settings.i;
          final cs = Theme.of(context).colorScheme;
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('الوضع', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, icon: Icon(Icons.brightness_auto), label: Text('النظام')),
                ButtonSegment(value: 1, icon: Icon(Icons.light_mode), label: Text('فاتح')),
                ButtonSegment(value: 2, icon: Icon(Icons.dark_mode), label: Text('داكن')),
              ],
              selected: {s.themeMode.clamp(0, 2)},
              onSelectionChanged: (v) => s.set('themeMode', v.first),
            ),
            const SizedBox(height: 22),
            const Text('لون التطبيق', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (int i = 0; i < accents.length; i++)
                GestureDetector(
                  onTap: () => s.set('accent', i),
                  child: Column(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accents[i].color,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: s.accent == i ? gold : Colors.transparent, width: 3),
                      ),
                      child: s.accent == i
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(accents[i].name, style: const TextStyle(fontSize: 10.5)),
                  ]),
                ),
            ]),
            const SizedBox(height: 22),
            const Text('نوع الخط', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final f in fontChoices)
                ChoiceChip(
                  label: Text(f),
                  selected: s.font == f,
                  onSelected: (_) => s.set('font', f),
                ),
            ]),
            const SizedBox(height: 6),
            Text('الخطوط تُحمَّل أول مرة من الإنترنت ثم تعمل بدونه. لتضمينها دائمًا راجع README.',
                style: TextStyle(fontSize: 11.5, color: cs.onSurface.withAlpha(140))),
            const SizedBox(height: 22),
            Row(children: [
              const Text('حجم الخط', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${(s.fontScale * 100).round()}%'),
            ]),
            Slider(
              value: s.fontScale,
              min: 0.85,
              max: 1.4,
              divisions: 11,
              onChanged: (v) => s.set('fontScale', double.parse(v.toStringAsFixed(2))),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('الأرقام العربية (١٢٣)'),
              value: s.arabicDigits,
              onChanged: (v) => s.set('arabicDigits', v),
            ),
            const SizedBox(height: 10),
            Panel(
              child: Column(children: [
                const Text('معاينة', style: TextStyle(color: goldDeep, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ سُبْحَانَ اللَّهِ الْعَظِيمِ',
                    textAlign: TextAlign.center,
                    style: quranStyle(24, cs.onSurface)),
                const SizedBox(height: 6),
                const Text('صلاة الفجر ٤:٥٢ ص • الظهر ١١:٥٥ ص'),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
