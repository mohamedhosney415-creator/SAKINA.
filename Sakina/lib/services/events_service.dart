import '../core/format.dart';
import '../data/events.dart';

class UpcomingEvent {
  final IslamicEvent event;
  final DateTime date;
  UpcomingEvent(this.event, this.date);
  int daysFrom(DateTime now) => date.difference(onlyDate(now)).inDays;
}

class EventsService {
  /// المناسبات القادمة خلال [horizonDays] يومًا.
  static List<UpcomingEvent> upcoming(DateTime now,
      {int horizonDays = 400}) {
    final today = onlyDate(now);
    final end = today.add(Duration(days: horizonDays));
    final hy = hijriOf(now).hYear;
    final out = <UpcomingEvent>[];
    for (int y = hy - 1; y <= hy + 2; y++) {
      for (final e in islamicEvents) {
        final d = gregOfHijri(y, e.month, e.day);
        if (!d.isBefore(today) && !d.isAfter(end)) out.add(UpcomingEvent(e, d));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// أحداث يوم معيّن (لعرضها في التقويم).
  static List<IslamicEvent> onDate(DateTime d) {
    final h = hijriOf(d);
    final out = <IslamicEvent>[];
    for (final e in islamicEvents) {
      if (e.month != h.hMonth) continue;
      if (h.hDay >= e.day && h.hDay < e.day + e.days) out.add(e);
    }
    return out;
  }

  static bool isWhiteDay(DateTime d) {
    final h = hijriOf(d);
    return h.hDay >= 13 && h.hDay <= 15;
  }
}
