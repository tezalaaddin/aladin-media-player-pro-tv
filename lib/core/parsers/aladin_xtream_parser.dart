import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/aladin_channel_model.dart';
import '../models/aladin_category_model.dart';

class AladinXtreamParser {
  final String server, username, password;
  AladinXtreamParser(
      {required this.server, required this.username, required this.password});

  String get _base =>
      '$server/player_api.php?username=$username&password=$password';

  Future<bool> validate() async {
    try {
      final r =
          await http.get(Uri.parse(_base)).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return j['user_info'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<CategoryModel>> fetchLiveCategories(int pid) =>
      _cats('get_live_categories', 'tv', pid);
  Future<List<CategoryModel>> fetchVodCategories(int pid) =>
      _cats('get_vod_categories', 'movie', pid);
  Future<List<CategoryModel>> fetchSeriesCategories(int pid) =>
      _cats('get_series_categories', 'series', pid);

  Future<List<CategoryModel>> _cats(String action, String type, int pid) async {
    final r = await http
        .get(Uri.parse('$_base&action=$action'))
        .timeout(const Duration(seconds: 15));
    final list = jsonDecode(r.body) as List<dynamic>;
    int order = 0;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return CategoryModel()
        ..name = m['category_name']?.toString() ?? 'Unknown'
        ..contentType = type
        ..playlistId = pid
        ..channelCount = 0
        ..sortOrder = order++;
    }).toList();
  }

  Stream<List<ChannelModel>> fetchLiveStreams(int pid) =>
      _streams('$_base&action=get_live_streams', 'tv', pid);
  Stream<List<ChannelModel>> fetchVodStreams(int pid) =>
      _streams('$_base&action=get_vod_streams', 'movie', pid);
  Stream<List<ChannelModel>> fetchSeriesStreams(int pid) =>
      _streams('$_base&action=get_series', 'series', pid);

  Stream<List<ChannelModel>> _streams(String url, String type, int pid,
      {int batchSize = 200}) async* {
    final r =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    final list = jsonDecode(r.body) as List<dynamic>;
    int order = 0;
    final batch = <ChannelModel>[];

    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final id = m['stream_id']?.toString() ?? m['series_id']?.toString() ?? '';
      final ext = m['container_extension']?.toString() ?? 'ts';
      final streamUrl = type == 'tv'
          ? '$server/live/$username/$password/$id.ts'
          : type == 'movie'
              ? '$server/movie/$username/$password/$id.$ext'
              : '$server/series/$username/$password/$id';

      batch.add(ChannelModel()
        ..playlistId = pid
        ..name = m['name']?.toString() ?? 'Unknown'
        ..url = streamUrl
        ..logoUrl = m['stream_icon']?.toString()
        ..categoryName = m['category_name']?.toString() ?? 'Diğer'
        ..groupTitle = m['category_name']?.toString()
        ..tvgId = id
        ..contentType = type
        ..sortOrder = order++);

      if (batch.length >= batchSize) {
        yield List.of(batch);
        batch.clear();
      }
    }
    if (batch.isNotEmpty) yield batch;
  }
}
