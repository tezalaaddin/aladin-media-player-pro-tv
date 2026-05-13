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
      final reps = <ChannelModel>[];
      for (final ch in all) {
        final key = ch.seriesName?.trim() ?? ch.name.trim();
        if (seen.add(key.toLowerCase())) {
          reps.add(ch);
        }
      }

      if (offset >= reps.length) return [];
      int end = offset + limit;
      if (end > reps.length) end = reps.length;
      return reps.sublist(offset, end);
    }

    // Default logic for 'tv' and 'movie'
    final results = await _db.channelModels
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
    return results;
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
    await _db.writeTxn(() async {
      final matches = await _db.channelModels.filter().urlEqualTo(url).findAll();
      for (final ch in matches) {
        ch.lastWatched = DateTime.now();
        ch.watchedSeconds = seconds;
        ch.totalDurationSeconds = totalSeconds;
        await _db.channelModels.put(ch);
      }
    });
  }

  /// Returns items that are partially watched (between 1% and 90%)
  Future<List<ChannelModel>> getContinueWatching(int playlistId, {int limit = 20}) async {
    final all = await _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .lastWatchedIsNotNull()
        .sortByLastWatchedDesc()
        .findAll();

    return all.where((ch) {
      if (ch.totalDurationSeconds <= 0) return false;
      final percent = (ch.watchedSeconds / ch.totalDurationSeconds) * 100;
      return percent >= 5 && percent <= 90;
    }).take(limit).toList();
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<ChannelModel?> getById(int id) => _db.channelModels.get(id);

  Future<List<ChannelModel>> search(
      {required int playlistId, required String query, int limit = 100}) async {
    if (query.trim().isEmpty) return [];
    return _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .nameContains(query, caseSensitive: false)
        .limit(limit)
        .findAll();
  }

  // ── Series helpers ─────────────────────────────────────────────────────────

  /// Single query — groups in Dart for speed (avoids N DB calls)
  Future<List<ChannelModel>> getSeriesRepresentatives(int playlistId) async {
    final all = await _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .contentTypeEqualTo('series')
        .sortBySortOrder()
        .findAll();

    final seen = <String>{};
    final reps = <ChannelModel>[];
    for (final ch in all) {
      final key = ch.seriesName?.trim() ?? ch.name.trim();
      if (seen.add(key)) reps.add(ch);
    }
    return reps;
  }

  Future<List<ChannelModel>> getSeriesEpisodes(
      int playlistId, String sName) async {
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

  /// All unique tvg-ids in a playlist (for EPG filtering)
  Future<Set<String>> getTvgIds(int playlistId) async {
    final all = await _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .tvgIdIsNotNull()
        .findAll();
    final ids = {
      for (final c in all)
        if (c.tvgId != null) c.tvgId!
    };
    debugPrint('[EPG] getTvgIds: ${ids.length} ids for playlist $playlistId');
    debugPrint('[EPG] sample tvgIds: ${ids.take(20).toList()}');
    return ids;
  }

  Future<void> saveChannels(List<ChannelModel> channels) async {
    await _db.writeTxn(() => _db.channelModels.putAll(channels));
  }

  /// Xtream import sonrası kategori kanal sayılarını veritabanından hesaplayıp günceller
  Future<void> updateCategoryCountsForPlaylist(int playlistId) async {
    await _db.writeTxn(() async {
      final cats = await _db.categoryModels.filter().playlistIdEqualTo(playlistId).findAll();
      for (var cat in cats) {
        int count = 0;
        if (cat.contentType == 'series') {
          // Diziler için unique seriesName sayıyoruz
          final allSeries = await _db.channelModels
              .filter()
              .playlistIdEqualTo(playlistId)
              .and()
              .categoryNameEqualTo(cat.name)
              .and()
              .contentTypeEqualTo('series')
              .findAll();
          final seen = <String>{};
          for (var s in allSeries) {
            seen.add(s.seriesName?.toLowerCase() ?? s.name.toLowerCase());
          }
          count = seen.length;
        } else {
          count = await _db.channelModels
              .filter()
              .playlistIdEqualTo(playlistId)
              .and()
              .categoryNameEqualTo(cat.name)
              .and()
              .contentTypeEqualTo(cat.contentType)
              .count();
        }
        cat.channelCount = count;
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

      // If it's a series and we want to apply metadata to all episodes
      if (applyToAllEpisodes && ch.contentType == 'series') {
        final seriesName = ch.seriesName ?? ch.name;
        final episodes = await _db.channelModels
            .filter()
            .playlistIdEqualTo(ch.playlistId)
            .and()
            .contentTypeEqualTo('series')
            .and()
            .group((q) => q
                .seriesNameEqualTo(seriesName.trim())
                .or()
                .nameEqualTo(seriesName.trim()))
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
