import 'package:isar/isar.dart';
import '../database/aladin_isar_service.dart';
import '../models/aladin_epg_model.dart';
import 'aladin_epg_engine.dart';

/// EpgService — query layer only. Sync is handled by [AladinEpgEngine].
///
/// Matching uses 3 layers (all powered by the improved [AladinEpgEngine.normalizeId]):
///   Layer 1 — Exact:      programme.channelId == channelId (tvg-id)
///   Layer 2 — Normalized: normalizeId(channelId) == normalizeId(programme.channelId)
///   Layer 3 — Name:       normalizeId(cleanName) == normalizeId(programme.channelId)
///
/// [cleanName] should be [ChannelModel.name] (the parser-cleaned title,
/// e.g. "TRT 1" rather than the raw "TR | TRT 1 HD").
class EpgService {
  EpgService._();
  static final EpgService instance = EpgService._();

  Isar get _db => IsarService.instance.db;

  bool _isPaused = false;
  bool get isPaused => _isPaused;
  void pauseQueries() => _isPaused = true;
  void resumeQueries() {
    _isPaused = false;
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Returns the programme currently on air for a channel.
  ///
  /// [channelId] — channel.tvgId (or channel.name when tvgId is empty)
  /// [cleanName] — channel.name (parser-cleaned, no prefix/quality tags)
  Future<EpgProgramModel?> getNowPlaying(
    String channelId, {
    String? cleanName,
    // kept for API compatibility — treated as cleanName if cleanName is null
    String? channelName,
  }) async {
    if (_isPaused) return null;
    final now = DateTime.now();
    final candidates = await _db.epgProgramModels
        .filter()
        .startTimeLessThan(now)
        .and()
        .endTimeGreaterThan(now)
        .findAll();

    final effectiveClean = cleanName ?? channelName;
    return _bestMatch(candidates, channelId, effectiveClean);
  }

  /// Returns upcoming programmes for a channel, sorted by start time.
  ///
  /// [channelId] — channel.tvgId (or channel.name when tvgId is empty)
  /// [cleanName] — channel.name (parser-cleaned)
  Future<List<EpgProgramModel>> getUpcoming(
    String channelId, {
    String? cleanName,
    String? channelName,
    int limit = 8,
  }) async {
    if (_isPaused) return [];
    final now = DateTime.now();
    final candidates = await _db.epgProgramModels
        .filter()
        .startTimeGreaterThan(now)
        .sortByStartTime()
        .findAll();

    final effectiveClean = cleanName ?? channelName;
    final normId = AladinEpgEngine.normalizeId(channelId);
    final normClean = effectiveClean != null
        ? AladinEpgEngine.normalizeId(effectiveClean)
        : null;

    return candidates
        .where((p) => _matches(p.channelId, channelId, normId, normClean))
        .take(limit)
        .toList();
  }

  // ── Matching helpers ──────────────────────────────────────────────────────

  EpgProgramModel? _bestMatch(
    List<EpgProgramModel> candidates,
    String channelId,
    String? cleanName,
  ) {
    final normId = AladinEpgEngine.normalizeId(channelId);
    final normClean =
        cleanName != null ? AladinEpgEngine.normalizeId(cleanName) : null;

    // Layer 1: exact tvg-id match
    for (final p in candidates) {
      if (p.channelId == channelId) return p;
    }

    // Layer 2: normalized tvg-id match
    //   e.g. normalizeId("TRT1.tr") == normalizeId("TRT1.tr") → "trt1"
    //   e.g. normalizeId("TR | TRT 1 HD") → "trt1" == normalizeId("TRT1.tr") → "trt1"
    if (normId.length >= 2) {
      for (final p in candidates) {
        if (AladinEpgEngine.normalizeId(p.channelId) == normId) return p;
      }
    }

    // Layer 3: clean channel name match
    //   e.g. normalizeId("TRT 1") → "trt1" == normalizeId("TRT1.tr") → "trt1"
    if (normClean != null && normClean.length >= 2 && normClean != normId) {
      for (final p in candidates) {
        if (AladinEpgEngine.normalizeId(p.channelId) == normClean) return p;
      }
    }

    return null;
  }

  bool _matches(
    String epgCid,
    String channelId,
    String normId,
    String? normClean,
  ) {
    if (epgCid == channelId) return true;
    final normEpg = AladinEpgEngine.normalizeId(epgCid);
    if (normEpg == normId) return true;
    if (normClean != null && normClean.length >= 2 && normClean != normId) {
      if (normEpg == normClean) return true;
    }
    return false;
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<int> totalProgrammes() => _db.epgProgramModels.count();
}
