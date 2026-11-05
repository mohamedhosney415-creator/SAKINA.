import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'theme.dart';
import '../services/favorites.dart';

/// بطاقة موحّدة.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color ?? cs.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: dark
                    ? Colors.white.withAlpha(18)
                    : gold.withAlpha(60)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(children: [
          Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: gold, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// رأس صفحة بخلفية زخرفية.
class HeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  const HeroCard(
      {super.key,
      required this.child,
      this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 0)});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [cs.primary, Color.lerp(cs.primary, Colors.black, .42)!],
        ),
        boxShadow: [
          BoxShadow(
              color: cs.primary.withAlpha(70),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: CustomPaint(
          painter: _PatternPainter(),
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withAlpha(16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final c = Offset(size.width * .12, size.height * .2);
    for (int i = 0; i < 6; i++) {
      final r = 34.0 + i * 24;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(math.pi / 8 * i);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 1.6), p);
      canvas.rotate(math.pi / 4);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 1.6), p);
      canvas.restore();
    }
    final g = Paint()
      ..color = gold.withAlpha(46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(Offset(size.width * .95, size.height * .95), 60, g);
    canvas.drawCircle(Offset(size.width * .95, size.height * .95), 90, g);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: gold.withAlpha(180)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    height: 1.7,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
          ]),
        ),
      );
}

/// توقيع المطور (خط صغير ورفيع).
class DeveloperSignature extends StatelessWidget {
  const DeveloperSignature({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: Text('تطوير حُسْنِي',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(120))),
        ),
      );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(msg), behavior: SnackBarBehavior.floating));
}

/// زر مفضلة موحّد.
class FavButton extends StatefulWidget {
  final String type, id, title, text, source;
  const FavButton({
    super.key,
    required this.type,
    required this.id,
    required this.text,
    this.title = '',
    this.source = '',
  });

  @override
  State<FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<FavButton> {
  @override
  Widget build(BuildContext context) {
    final on = Favorites.i.has(widget.type, widget.id);
    return IconButton(
      tooltip: on ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
      icon: Icon(on ? Icons.favorite : Icons.favorite_border,
          color: on ? Colors.redAccent : null),
      onPressed: () async {
        await Favorites.i.toggle(widget.type, widget.id,
            title: widget.title, text: widget.text, source: widget.source);
        if (mounted) setState(() {});
      },
    );
  }
}

Future<void> shareText(BuildContext context, String text) async {
  try {
    await Share.share('$text\n\n— تطبيق سكينة');
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) toast(context, 'تم نسخ النص');
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'تم النسخ');
}

/// صف إجراءات (نسخ / مشاركة / مفضلة) للمحتوى النصي.
class ContentActions extends StatelessWidget {
  final String type, id, text, title, source;
  const ContentActions({
    super.key,
    required this.type,
    required this.id,
    required this.text,
    this.title = '',
    this.source = '',
  });

  @override
  Widget build(BuildContext context) {
    final full = source.isEmpty ? text : '$text\n\n$source';
    return Row(children: [
      FavButton(type: type, id: id, text: text, title: title, source: source),
      IconButton(
          tooltip: 'نسخ',
          onPressed: () => copyText(context, full),
          icon: const Icon(Icons.copy_rounded)),
      IconButton(
          tooltip: 'مشاركة',
          onPressed: () => shareText(context, full),
          icon: const Icon(Icons.share_rounded)),
    ]);
  }
}

void go(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

/// يلفّ الصفحة بـ Scaffold عند فتحها كصفحة مستقلة (وليس كتبويب).
class Standalone extends StatelessWidget {
  final bool on;
  final String title;
  final Widget child;
  const Standalone(
      {super.key, required this.on, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}
