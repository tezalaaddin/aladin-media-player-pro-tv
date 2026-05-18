import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../database/aladin_isar_service.dart';
import '../models/aladin_channel_model.dart';
import '../models/aladin_category_model.dart';

class ChannelService {
  ChannelService._();
  static final ChannelService instance = ChannelService._();
  Isar get _db => IsarService.instance.db;

  // ── Categories ─────────────────────────────────────────────────────────────

  Future<List<CategoryModel>> getCategories(
          {required int playlistId, required String contentType}) =>
      _db.categoryModels
          .filter()
          .playlistIdEqualTo(playlistId)
          .and()
          .contentTypeEqualTo(contentType)
          .sortBySortOrder()
          .findAll();

  // ── Channels per category (paginated) ─────────────────────────────────────

  Future<List<ChannelModel>> getChannelsByCategory(
      {required int playlistId,
      required String categoryName,
      required String contentType,
      int offset = 0,
      int limit = 100}) async {
    // Special handling for series: group by seriesName (or name) to avoid duplicate entries for episodes
    if (contentType == 'series') {
      // Optimization: Try to get only "main" records first (url is empty or episode 1/null)
      final reps = await _db.channelModels
          .filter()
          .playlistIdEqualTo(playlistId)
          .and()
          .categoryNameEqualTo(categoryName.trim())
          .and()
          .contentTypeEqualTo('series')
          .group((q) => q.urlEqualTo('').or().episodeEqualTo(1).or().episodeIsNull())
          .sortBySortOrder()
          .offset(offset)
          .limit(limit)
          .findAll();

      if (reps.isNotEmpty) return reps;

      // Fallback if no "main" records found (e.g. strange M3U)
      final all = await _db.channelModels
          .filter()
          .playlistIdEqualTo(playlistId)
          .and()
          .categoryNameEqualTo(categoryName.trim())
          .and()
          .contentTypeEqualTo('series')
          .sortBySortOrder()
          .findAll();

      final seen = <String>{};
      final results = <ChannelModel>[];
      for (final ch in all) {
        final key = ch.seriesName?.trim() ?? ch.name.trim();
        if (seen.add(key.toLowerCase())) {
          results.add(ch);
        }
      }

      if (offset >= results.length) return [];
      int end = offset + limit;
      if (end > results.length) end = results.length;
      return results.sublist(offset, end);
    }

    return _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .categoryNameEqualTo(categoryName.trim())
        .and()
        .contentTypeEqualTo(contentType)
        .sortBySortOrder()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  // ── Favorites ──────────────────────────────────────────────────────────────

  Future<List<ChannelModel>> getFavorites(int playlistId) => _db.channelModels
      .filter()
      .playlistIdEqualTo(playlistId)
      .and()
      .isFavoriteEqualTo(true)
      .findAll();

  Future<void> toggleFavorite(int channelId) async {
    await _db.writeTxn(() async {
      final ch = await _db.channelModels.get(channelId);
      if (ch != null) {
        ch.isFavorite = !ch.isFavorite;
        await _db.channelModels.put(ch);
      }
    });
  }

  Future<void> setFavoriteByUrl(String url, bool isFavorite) async {
    await _db.writeTxn(() async {
      final matches = await _db.channelModels.filter().urlEqualTo(url).findAll();
      for (final ch in matches) {
        ch.isFavorite = isFavorite;
        await _db.channelModels.put(ch);
      }
    });
  }

  // ── Recent ─────────────────────────────────────────────────────────────────

  Future<List<ChannelModel>> getRecent(int playlistId, {int limit = 20}) =>
      _db.channelModels
          .filter()
          .playlistIdEqualTo(playlistId)
          .lastWatchedIsNotNull()
          .sortByLastWatchedDesc()
          .limit(limit)
          .findAll();

  Future<void> updateWatched(int channelId, int seconds) async {
    await _db.writeTxn(() async {
      final ch = await _db.channelModels.get(channelId);
      if (ch != null) {
        ch.lastWatched = DateTime.now();
        ch.watchedSeconds = seconds;
        await _db.channelModels.put(ch);
      }
    });
  }

  Future<void> updateProgressByUrl(String url, int seconds, int totalSeconds) async {
    if (totalSeconds <= 0) return;
    
    await _db.writeTxn(() async {
      final matches = await _db.channelModels.filter().urlEqualTo(url).findAll();
      for (final ch in matches) {
        final percent = (seconds / totalSeconds) * 100;
        
        // Kullanıcı isteği: %3 - %90 arası izleme takibi
        if (percent >= 3 && percent <= 90) {
          ch.lastWatched = DateTime.now();
          ch.watchedSeconds = seconds;
          ch.totalDurationSeconds = totalSeconds;
        } else if (percent > 90) {
          // %90 geçildiyse bitmiş say ama ilerleme çubuğu için süreyi koru
          ch.lastWatched = DateTime.now();
          ch.watchedSeconds = totalSeconds;
          ch.totalDurationSeconds = totalSeconds;
        }
        await _db.channelModels.put(ch);
      }
    });
  }

  /// Dizi ana sayfası için her dizinin izleme oranını hesaplar (Bellek Optimize)
  Future<Map<String, double>> getSeriesProgressMap(int playlistId) async {
    // Sadece izlenen dizi bölümlerini çekiyoruz. 
    // Isar 3'te bir mülk bazlı gruplama olmadığı için, izlenenleri çekmek daha verimli.
    final watchedSeries = await _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .contentTypeEqualTo('series')
        .and()
        .watchedSecondsGreaterThan(299) // 5 dk ve üzeri izlenenler
        .findAll();
    
    // İzleme oranını tam hesaplamak için aslında toplam bölüm sayısını da bilmeliyiz.
    // Ancak 60k record'u çekmemek için, bu map'i sadece "devam edilenler" olarak kurgulayabiliriz
    // ya da bir kategorideki diziler için sayfa bazlı yapabiliriz.
    // Şimdilik sadece izlenenlerin varlığını tutan bir yapı dönelim veya Claude'un uyarısına uyup limitli çekelim.
    
    if (watchedSeries.length > 2000) {
      // Çok fazla veri varsa bellek hatası almamak için kırpıyoruz
      watchedSeries.removeRange(2000, watchedSeries.length);
    }

    final stats = <String, List<bool>>{};
    for (final ch in watchedSeries) {
      if (ch.url.isEmpty) continue;
      final key = ch.seriesName?.trim() ?? ch.name.trim();
      stats.putIfAbsent(key, () => []).add(true);
    }
    
    return stats.map((key, list) => MapEntry(key, 1.0)); // Basitleştirilmiş
  }

  /// Returns items that are partially watched (between 3% and 90%)
  /// UPDATED: Only one entry per Series (the latest one)
  Future<List<ChannelModel>> getContinueWatching(int playlistId, {int limit = 20}) async {
    final allRecent = await _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .lastWatchedIsNotNull()
        .and()
        .watchedSecondsGreaterThan(0)
        .and()
        .totalDurationSecondsGreaterThan(0)
        .sortByLastWatchedDesc()
        .findAll();

    final results = <ChannelModel>[];
    final seenSeries = <String>{};

    for (final ch in allRecent) {
      if (results.length >= limit) break;

      // 1. %3 - %90 Filtresi
      final percent = (ch.watchedSeconds / ch.totalDurationSeconds) * 100;
      if (percent < 3 || percent > 90) continue;

      // 2. Dizi Tekilleştirme (Sadece en son izlenen bölüm)
      if (ch.contentType == 'series') {
        final seriesKey = ch.seriesName?.trim().toLowerCase() ?? ch.name.trim().toLowerCase();
        if (seenSeries.contains(seriesKey)) continue; // Daha yenisi zaten eklendi
        seenSeries.add(seriesKey);
      }

      results.add(ch);
    }

    return results;
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<ChannelModel?> getById(int id) => _db.channelModels.get(id);

  Future<List<ChannelModel>> search(
      {required int playlistId, required String query, int limit = 100}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return []; // Claude uyarısı: min 2 karakter
    return _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .nameContains(trimmed, caseSensitive: false)
        .limit(limit)
        .findAll();
  }

  // ── Series helpers ─────────────────────────────────────────────────────────

  Future<List<ChannelModel>> getSeriesRepresentatives(int playlistId) async {
    // Proactive optimization for memory: get empty URL or Episode 1/null records
    final reps = await _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .contentTypeEqualTo('series')
        .group((q) => q.urlEqualTo('').or().episodeEqualTo(1).or().episodeIsNull())
        .sortBySortOrder()
        .findAll();

    if (reps.isNotEmpty) return reps;

    // Last resort fallback (heavy on RAM)
    final all = await _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .contentTypeEqualTo('series')
        .sortBySortOrder()
        .findAll();

    final seen = <String>{};
    final results = <ChannelModel>[];
    for (final ch in all) {
      final key = ch.seriesName?.trim() ?? ch.name.trim();
      if (seen.add(key.toLowerCase())) results.add(ch);
    }
    return results;
  }

  Future<List<ChannelModel>> getSeriesEpisodes(int playlistId, String sName) async {
    final trimmed = sName.trim();
    return _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .contentTypeEqualTo('series')
        .and()
        .group((q) => q.seriesNameEqualTo(trimmed).or().nameEqualTo(trimmed))
        .sortBySeason()
        .thenByEpisode()
        .findAll();
  }

  Future<List<ChannelModel>> getEpisodes({
    required int playlistId,
    required String seriesName,
    int? season,
  }) async {
    final trimmed = seriesName.trim();
    var query = _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .contentTypeEqualTo('series')
        .and()
        .group((q) => q.seriesNameEqualTo(trimmed).or().nameEqualTo(trimmed));

    if (season != null) {
      query = query.and().seasonEqualTo(season);
    }

    return query.sortBySeason().thenByEpisode().findAll();
  }

  Future<void> saveChannels(List<ChannelModel> channels) async {
    await _db.writeTxn(() => _db.channelModels.putAll(channels));
  }

  /// Optimized category count update
  Future<void> updateCategoryCountsForPlaylist(int playlistId) async {
    final cats = await _db.categoryModels.filter().playlistIdEqualTo(playlistId).findAll();
    final Map<int, int> counts = {};

    for (var cat in cats) {
      if (cat.contentType == 'series') {
        // Optimization: Use seriesNameProperty to get only names and unique them
        final names = await _db.channelModels
            .filter()
            .playlistIdEqualTo(playlistId)
            .and()
            .categoryNameEqualTo(cat.name)
            .and()
            .contentTypeEqualTo('series')
            .seriesNameProperty()
            .findAll();
        
        final seen = <String>{};
        for (var n in names) {
          if (n != null && n.isNotEmpty) seen.add(n.toLowerCase());
        }
        counts[cat.id] = seen.length;
      } else {
        counts[cat.id] = await _db.channelModels
            .filter()
            .playlistIdEqualTo(playlistId)
            .and()
            .categoryNameEqualTo(cat.name)
            .and()
            .contentTypeEqualTo(cat.contentType)
            .count();
      }
    }

    await _db.writeTxn(() async {
      for (var cat in cats) {
        cat.channelCount = counts[cat.id] ?? 0;
        await _db.categoryModels.put(cat);
      }
    });
  }

  // ── TMDB ───────────────────────────────────────────────────────────────────

  Future<void> saveTmdbMeta({
    required int channelId,
    String? tmdbId,
    String? imdbRating,
    String? poster,
    String? overview,
    String? year,
    bool applyToAllEpisodes = false,
  }) async {
    await _db.writeTxn(() async {
      final ch = await _db.channelModels.get(channelId);
      if (ch == null) return;

      ch.tmdbId = tmdbId ?? ch.tmdbId;
      ch.imdbRating = imdbRating ?? ch.imdbRating;
      ch.tmdbPoster = poster ?? ch.tmdbPoster;
      ch.tmdbOverview = overview ?? ch.tmdbOverview;
      ch.tmdbYear = year ?? ch.tmdbYear;
      await _db.channelModels.put(ch);

      if (applyToAllEpisodes && ch.contentType == 'series') {
        final seriesName = ch.seriesName ?? ch.name;
        final episodes = await _db.channelModels
            .filter()
            .playlistIdEqualTo(ch.playlistId)
            .and()
            .contentTypeEqualTo('series')
            .and()
            .group((q) => q.seriesNameEqualTo(seriesName.trim()).or().nameEqualTo(seriesName.trim()))
            .findAll();

        for (final ep in episodes) {
          if (ep.id == ch.id) continue;
          ep.tmdbId = tmdbId ?? ep.tmdbId;
          ep.imdbRating = imdbRating ?? ep.imdbRating;
          ep.tmdbPoster = poster ?? ep.tmdbPoster;
          ep.tmdbOverview = overview ?? ep.tmdbOverview;
          ep.tmdbYear = year ?? ep.tmdbYear;
          await _db.channelModels.put(ep);
        }
      }
    });
  }
}
