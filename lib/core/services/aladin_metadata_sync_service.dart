import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../database/aladin_isar_service.dart';
import '../models/aladin_channel_model.dart';
import 'aladin_tmdb_service.dart';
import 'aladin_channel_service.dart';

class MetadataSyncService extends ChangeNotifier {
  MetadataSyncService._();
  static final MetadataSyncService instance = MetadataSyncService._();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  double _progress = 0;
  double get progress => _progress;

  int _syncedCount = 0;
  int _totalToSync = 0;

  Isar get _db => IsarService.instance.db;

  /// Starts the sync process for a playlist.
  /// Finds movies and series with missing metadata and updates them.
  Future<void> startSync(int playlistId, {String lang = 'tr'}) async {
    if (_isSyncing) return;

    debugPrint('[MetadataSync] Checking missing metadata for playlist $playlistId (lang: $lang)...');

    // Find items with missing metadata
    final missingMovies = await _db.channelModels
        .filter()
        .playlistIdEqualTo(playlistId)
        .and()
        .group((q) => q.contentTypeEqualTo('movie').or().contentTypeEqualTo('series'))
        .and()
        .group((q) => q.imdbRatingIsNull().or().imdbRatingEqualTo('0').or().imdbRatingEqualTo('0.0').or().tmdbPosterIsNull())
        .findAll();

    if (missingMovies.isEmpty) {
      debugPrint('[MetadataSync] No items to sync.');
      return;
    }

    _isSyncing = true;
    _progress = 0;
    _syncedCount = 0;
    _totalToSync = missingMovies.length;
    notifyListeners();

    debugPrint('[MetadataSync] Starting sync for $_totalToSync items.');

    // We process in a queue with a delay to respect TMDb rate limits (approx 2 requests/sec)
    _syncQueue(missingMovies, lang: lang);
  }

  Future<void> _syncQueue(List<ChannelModel> items, {String lang = 'tr'}) async {
    for (int i = 0; i < items.length; i++) {
      if (!_isSyncing) break;

      final channel = items[i];
      
      try {
        Map<String, dynamic>? meta;
        if (channel.contentType == 'movie') {
          meta = await TmdbService.instance.searchMovie(
            channel.name, 
            year: channel.tmdbYear,
            lang: lang,
          );
        } else if (channel.contentType == 'series') {
          final sName = channel.seriesName ?? channel.name;
          meta = await TmdbService.instance.searchSeries(
            sName,
            year: channel.tmdbYear,
            lang: lang,
          );
        }

        if (meta != null) {
          await ChannelService.instance.saveTmdbMeta(
            channelId: channel.id,
            tmdbId: meta['tmdbId'],
            imdbRating: meta['imdbRating'],
            poster: meta['poster'],
            overview: meta['overview'],
            year: meta['year'],
            applyToAllEpisodes: true, // Series episodes will inherit metadata
          );
        }
      } catch (e) {
        debugPrint('[MetadataSync] Error syncing ${channel.name}: $e');
      }

      _syncedCount++;
      _progress = _syncedCount / _totalToSync;

      // Update UI every 10 items or at the end
      if (_syncedCount % 10 == 0 || _syncedCount == _totalToSync) {
        notifyListeners();
      }

      // 500ms delay to keep it ~2 requests per second
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isSyncing = false;
    _progress = 0.0; // Reset progress bar when done
    notifyListeners();
    debugPrint('[MetadataSync] Sync completed. Total synced: $_syncedCount');
  }

  void stopSync() {
    _isSyncing = false;
    notifyListeners();
  }
}
