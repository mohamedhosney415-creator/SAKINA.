import 'package:flutter/foundation.dart';
import '../core/store.dart';

/// المفضلة: آيات، أحاديث، أذكار، حكم، علامات مرجعية.
class Favorites extends ChangeNotifier {
  static final Favorites i = Favorites._();
  Favorites._();

  List<Map<String, dynamic>> items = [];

  void load() {
    final j = Store.json('favs', []);
    items = (j is List)
        ? j.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : [];
    notifyListeners();
  }

  bool has(String type, String id) =>
      items.any((e) => e['type'] == type && e['id'] == id);

  Future<void> toggle(String type, String id,
      {String title = '', String text = '', String source = ''}) async {
    if (has(type, id)) {
      items.removeWhere((e) => e['type'] == type && e['id'] == id);
    } else {
      items.insert(0, {
        'type': type,
        'id': id,
        'title': title,
        'text': text,
        'source': source,
        'at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await Store.setJson('favs', items);
    notifyListeners();
  }

  List<Map<String, dynamic>> byType(String type) =>
      items.where((e) => e['type'] == type).toList();
}
