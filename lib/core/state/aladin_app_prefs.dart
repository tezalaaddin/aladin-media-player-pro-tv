import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Lightweight key-value prefs stored as JSON in app documents dir.
/// Avoids adding shared_preferences dependency.
class AladinPrefs {
  AladinPrefs._();
  static final AladinPrefs instance = AladinPrefs._();

  Map<String, dynamic> _cache = {};
  bool _loaded = false;

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/aladin_prefs.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file;
      if (await f.exists()) {
        final raw = await f.readAsString();
        _cache =
            Map<String, dynamic>.from((raw.isNotEmpty) ? _jsonDecode(raw) : {});
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> _save() async {
    final f = await _file;
    await f.writeAsString(_jsonEncode(_cache));
  }

  String? getString(String key) => _cache[key]?.toString();
  Future<void> setString(String key, String val) async {
    _cache[key] = val;
    await _save();
  }

  bool getBool(String key, {bool def = false}) => _cache[key] as bool? ?? def;
  Future<void> setBool(String key, bool val) async {
    _cache[key] = val;
    await _save();
  }

  int getInt(String key, {int def = 0}) =>
      (_cache[key] as num?)?.toInt() ?? def;
  Future<void> setInt(String key, int val) async {
    _cache[key] = val;
    await _save();
  }

  static String _jsonEncode(Map<String, dynamic> m) => jsonEncode(m);

  static Map<String, dynamic> _jsonDecode(String s) =>
      Map<String, dynamic>.from(jsonDecode(s) as Map);
}
