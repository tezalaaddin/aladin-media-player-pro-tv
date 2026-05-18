import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  TmdbService._();
  static final TmdbService instance = TmdbService._();

  static const _base = 'https://api.themoviedb.org/3';
  static const _imgBase = 'https://image.tmdb.org/t/p/w300';

  // API key'i build zamanında --dart-define=TMDB_API_KEY=xxxx olarak geçin.
  // Örnek: flutter build appbundle --release --dart-define=TMDB_API_KEY=your_key
  // Geliştirme için fallback bırakıldı; üretimde mutlaka --dart-define kullanın.
  static const _apiKey = String.fromEnvironment('TMDB_API_KEY');

  // Hafıza içi basit bir cache sistemi (maks 200 giriş)
  final Map<String, Map<String, dynamic>> _seriesCache = {};

  void _checkCacheLimit() {
    if (_seriesCache.length > 200) {
      _seriesCache.clear(); // Simple clear if too big
    }
  }

  /// Başlıktaki playlist sıra numaralarını, kalite eklerini ve dizi sezon/bölüm bilgilerini temizler.
  String cleanTitle(String title) {
    var cleaned = title.replaceFirst(RegExp(r'^\d+[\.\-\)\s]+'), '').trim();
    
    // Kalite ve kaynak eklerini temizle
    final noise = [
      '1080p', '720p', '4k', 'uhd', 'fhd', 'hd', 'hevc', 'x264', 'x265',
      'bluray', 'brrip', 'web-dl', 'webrip', 'hdtv', 'dual', 'tr-en', 'dublaj', 'altyazili',
      'netflix', 'amazon', 'disney+', 'hbo', 'apple tv',
    ];
    
    for (var n in noise) {
      cleaned = cleaned.replaceAll(RegExp('\\b$n\\b', caseSensitive: false), '');
    }

    // Dizi sezon/bölüm ifadelerini temizle (S01 E02, Sezon 1 Bölüm 5 vb.)
    cleaned = cleaned.replaceAll(RegExp(r'\bS\d{1,2}\s?E\d{1,3}\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b(Sezon|Season|Bölüm|Episode)\s?\d{1,3}\b', caseSensitive: false), '');
    
    // Gereksiz parantez ve köşeli parantez içlerini temizle
    cleaned = cleaned.replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '');
    
    // Birden fazla boşluğu teke indir
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<Map<String, dynamic>?> searchMovie(String title,
      {String? year, String lang = 'tr'}) async {
    try {
      final clean = cleanTitle(title);
      final q = Uri.encodeQueryComponent(clean);
      final url = '$_base/search/movie?api_key=$_apiKey&query=$q&language=$lang-${lang.toUpperCase()}';
      
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>;
      if (results.isEmpty) return null;

      Map<String, dynamic>? bestMatch;
      
      if (year != null && year.isNotEmpty) {
        for (final item in results) {
          final rDate = item['release_date'] as String?;
          final rYear = rDate?.split('-').firstOrNull;
          if (rYear == year) {
            bestMatch = item as Map<String, dynamic>;
            break;
          }
        }
      }
      
      bestMatch ??= results.first as Map<String, dynamic>;

      return {
        'tmdbId': bestMatch['id']?.toString(),
        'imdbRating': bestMatch['vote_average'] != null
            ? (bestMatch['vote_average'] as num).toStringAsFixed(1)
            : null,
        'poster': bestMatch['poster_path'] != null ? '$_imgBase${bestMatch['poster_path']}' : null,
        'overview': bestMatch['overview'],
        'year': (bestMatch['release_date'] as String?)?.split('-').firstOrNull,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> searchSeries(String title,
      {String? year, String lang = 'tr'}) async {
    final clean = cleanTitle(title);
    
    // Cache check
    if (_seriesCache.containsKey(clean)) {
      return _seriesCache[clean];
    }

    try {
      final q = Uri.encodeQueryComponent(clean);
      final url = '$_base/search/tv?api_key=$_apiKey&query=$q&language=$lang-${lang.toUpperCase()}';
      
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>;
      if (results.isEmpty) return null;

      Map<String, dynamic>? bestMatch;
      
      if (year != null && year.isNotEmpty) {
        for (final item in results) {
          final rDate = item['first_air_date'] as String?;
          final rYear = rDate?.split('-').firstOrNull;
          if (rYear == year) {
            bestMatch = item as Map<String, dynamic>;
            break;
          }
        }
      }
      
      bestMatch ??= results.first as Map<String, dynamic>;

      final data = {
        'tmdbId': bestMatch['id']?.toString(),
        'imdbRating': bestMatch['vote_average'] != null
            ? (bestMatch['vote_average'] as num).toStringAsFixed(1)
            : null,
        'poster': bestMatch['poster_path'] != null ? '$_imgBase${bestMatch['poster_path']}' : null,
        'overview': bestMatch['overview'],
        'year': (bestMatch['first_air_date'] as String?)?.split('-').firstOrNull,
      };

      // Save to cache
      _checkCacheLimit();
      _seriesCache[clean] = data;
      return data;
    } catch (_) {
      return null;
    }
  }
}
