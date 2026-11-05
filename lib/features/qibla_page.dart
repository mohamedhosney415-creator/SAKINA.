import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../core/format.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// زاوية القبلة من الشمال الحقيقي (طريقة الدائرة العظمى) — تُحسب محليًا بدون إنترنت.
double qiblaBearing(double lat, double lng) {
  const kLat = 21.422487, kLng = 39.826206;
  final p1 = lat * math.pi / 180, p2 = kLat * math.pi / 180;
  final dl = (kLng - lng) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});
  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  bool _aligned = false;

  @override
  Widget build(BuildContext context) {
    final city = Settings.i.city;
    final bearing = qiblaBearing(city.lat, city.lng);
    final cs = Theme.of(context).colorScheme;
    final stream = FlutterCompass.events;

    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
          child: Column(children: [
            Text('من ${city.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${ar(bearing.toStringAsFixed(1))}°',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: cs.primary)),
            Text('زاوية القبلة من الشمال مع عقارب الساعة',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(150))),
          ]),
        ),
        const SizedBox(height: 16),
        if (stream == null)
          _noSensor(bearing, cs)
        else
          StreamBuilder<CompassEvent>(
            stream: stream,
            builder: (context, snap) {
              final h = snap.data?.heading;
              if (snap.connectionState == ConnectionState.waiting && h == null) {
                return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
              }
              if (h == null) return _noSensor(bearing, cs);
              var diff = (bearing - h) % 360;
              if (diff > 180) diff -= 360;
              final ok = diff.abs() < 3;
              if (ok && !_aligned) {
                _aligned = true;
                HapticFeedback.mediumImpact();
              } else if (!ok && diff.abs() > 8) {
                _aligned = false;
              }
              return Column(children: [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: Stack(alignment: Alignment.center, children: [
                    Transform.rotate(
                      angle: -h * math.pi / 180,
                      child: CustomPaint(
                        size: const Size(300, 300),
                        painter: _DialPainter(bearing, cs.onSurface, cs.primary),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      child: Icon(Icons.arrow_drop_down_rounded,
                          size: 46, color: ok ? Colors.green : gold),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: (ok ? Colors.green : cs.primary).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ok
                        ? 'أنت تواجه القبلة ✓'
                        : (diff > 0
                            ? 'در يمينًا ${ar(diff.abs().round())}°'
                            : 'در يسارًا ${ar(diff.abs().round())}°'),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: ok ? Colors.green : cs.primary),
                  ),
                ),
              ]);
            },
          ),
        const SizedBox(height: 18),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إرشادات المعايرة', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
                '• حرّك الهاتف في الهواء على شكل رقم ٨ عدة مرات لمعايرة البوصلة.\n'
                '• أمسك الهاتف أفقيًا مستويًا وابتعد عن المعادن والمغناطيس وأجهزة الشحن.\n'
                '• إن كانت الدقة ضعيفة فأعد المعايرة، أو اتجه نحو الزاوية المكتوبة أعلاه باستخدام أي بوصلة.',
                style: TextStyle(height: 1.9, color: cs.onSurface.withAlpha(190))),
          ]),
        ),
      ]),
    );
  }

  Widget _noSensor(double bearing, ColorScheme cs) => Panel(
        color: Colors.orange.withAlpha(30),
        child: Text(
            'مستشعر البوصلة غير متاح في هذا الهاتف. استخدم أي بوصلة واتجه نحو ${ar(bearing.toStringAsFixed(0))}° من الشمال.',
            style: const TextStyle(height: 1.8, fontWeight: FontWeight.w700)),
      );
}

class _DialPainter extends CustomPainter {
  final double qibla;
  final Color ink, accent;
  _DialPainter(this.qibla, this.ink, this.accent);

  void _text(Canvas c, String t, Offset o, double size, Color col, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(fontSize: size, color: col, fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
      textDirection: TextDirection.rtl,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = accent.withAlpha(22));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = gold);
    for (int d = 0; d < 360; d += 10) {
      final a = (d - 90) * math.pi / 180;
      final long = d % 30 == 0;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r - (long ? 16 : 8));
      final p2 = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawLine(p1, p2, Paint()..color = ink.withAlpha(long ? 160 : 70)..strokeWidth = long ? 2 : 1);
    }
    const letters = {0: 'ش', 90: 'ق', 180: 'ج', 270: 'غ'};
    letters.forEach((deg, l) {
      final a = (deg - 90) * math.pi / 180;
      _text(canvas, l, c + Offset(math.cos(a), math.sin(a)) * (r - 34), 17,
          deg == 0 ? Colors.redAccent : ink, bold: true);
    });
    // علامة القبلة
    final qa = (qibla - 90) * math.pi / 180;
    final dir = Offset(math.cos(qa), math.sin(qa));
    canvas.drawLine(c, c + dir * (r - 46), Paint()..color = gold..strokeWidth = 3);
    final kp = c + dir * (r - 62);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: kp, width: 30, height: 30), const Radius.circular(6)),
        Paint()..color = Colors.black87);
    canvas.drawRect(Rect.fromCenter(center: kp - const Offset(0, 6), width: 30, height: 5), Paint()..color = gold);
    canvas.drawCircle(c, 6, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.qibla != qibla || old.ink != ink;
}
