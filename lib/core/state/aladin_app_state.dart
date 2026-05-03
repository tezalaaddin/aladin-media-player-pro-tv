import 'package:flutter/foundation.dart';
import '../models/aladin_playlist_model.dart';
import '../services/aladin_playlist_service.dart';
import 'aladin_app_prefs.dart';
import 'aladin_app_strings.dart';

const aladinDemoPlaylists = [
  {
    'name': '🇹🇷 Türkçe TV Kanalları',
    'url': 'https://iptv-org.github.io/iptv/countries/tr.m3u'
  },
  {
    'name': '📰 Haber',
    'url': 'https://iptv-org.github.io/iptv/categories/news.m3u'
  },
  {
    'name': '⚽ Spor',
    'url': 'https://iptv-org.github.io/iptv/categories/sports.m3u'
  },
  {
    'name': '🎬 Sinema',
    'url': 'https://iptv-org.github.io/iptv/categories/movies.m3u'
  },
  {
    'name': '🎞 Belgesel',
    'url': 'https://iptv-org.github.io/iptv/categories/documentary.m3u'
  },
  {
    'name': '👶 Çocuk',
    'url': 'https://iptv-org.github.io/iptv/categories/kids.m3u'
  },
  {
    'name': '🌍 Genel Liste',
    'url': 'https://iptv-org.github.io/iptv/index.m3u'
  },
  {
    'name': '🇹🇷 Türkçe Kanallar',
    'url': 'https://iptv-org.github.io/iptv/languages/tur.m3u'
  },
];

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  List<PlaylistModel> _playlists = [];
  PlaylistModel? _active;
  String _lang = 'tr';
  bool _demoSeeded = false;

  // Dizi bölümleri arasında paylaşılan metadata
  String? _activeSeriesPoster;
  String? _activeSeriesName;
  String? _activeSeriesOverview;

  List<PlaylistModel> get playlists => List.unmodifiable(_playlists);
  PlaylistModel? get active => _active;
  String get lang => _lang;
  bool get isTurkish => _lang == 'tr';
  AppStrings get s => AppStrings.of(_lang);
  
  String? get activeSeriesPoster => _activeSeriesPoster;
  String? get activeSeriesName => _activeSeriesName;
  String? get activeSeriesOverview => _activeSeriesOverview;

  Future<void> init() async {
    await AladinPrefs.instance.load();
    _lang = AladinPrefs.instance.getString('lang') ?? 'tr';
    _demoSeeded = AladinPrefs.instance.getBool('demoSeeded');
  }

  void setActiveSeriesMeta({String? poster, String? name, String? overview}) {
    _activeSeriesPoster = poster;
    _activeSeriesName = name;
    _activeSeriesOverview = overview;
  }

  Future<void> setLang(String l) async {
    _lang = l;
    await AladinPrefs.instance.setString('lang', l);
    notifyListeners();
  }

  Future<void> loadPlaylists() async {
    _playlists = await PlaylistService.instance.getAll();
    if (_playlists.isEmpty && !_demoSeeded) {
      _demoSeeded = true;
      await AladinPrefs.instance.setBool('demoSeeded', true);
      await _seedDemos();
      _playlists = await PlaylistService.instance.getAll();
    }
    if (_active == null && _playlists.isNotEmpty) {
      _active = _playlists.first;
    } else if (_active != null) {
      final still = _playlists.firstWhere(
        (p) => p.id == _active!.id,
        orElse: () => _playlists.isNotEmpty ? _playlists.first : _active!,
      );
      _active = still;
    }
    if (_active == null || _playlists.isEmpty) {
      final savedId = AladinPrefs.instance.getInt('activePlaylistId');
      if (savedId != 0 && _playlists.isNotEmpty) {
        _active = _playlists.firstWhere(
          (p) => p.id == savedId,
          orElse: () => _playlists.first,
        );
      }
    }
    notifyListeners();
  }

  Future<void> _seedDemos() async {
    for (final d in aladinDemoPlaylists) {
      final p = PlaylistModel()
        ..url = d['url']!
        ..name = d['name']!
        ..type = 'm3u'
        ..createdAt = DateTime.now()
        ..lastUpdated = DateTime.now()
        ..totalCount = 0;
      await PlaylistService.instance.saveStub(p);
    }
  }

  void selectPlaylist(PlaylistModel p) {
    _active = p;
    AladinPrefs.instance.setInt('activePlaylistId', p.id);
    notifyListeners();
  }

  void refreshFavorites() {
    notifyListeners();
  }

  Future<void> refresh() => loadPlaylists();
}
