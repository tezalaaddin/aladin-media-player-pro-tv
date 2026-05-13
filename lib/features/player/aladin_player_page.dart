import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/aladin_channel_model.dart';
import '../../core/models/aladin_playlist_model.dart';
import '../series/aladin_series_page.dart';

class PlayerPage extends StatefulWidget {
  final ChannelModel channel;
  final List<ChannelModel> playlist; // Tüm kanal listesi
  final PlaylistModel? playlistModel; // Xtream yönlendirmesi için
  
  const PlayerPage({
    super.key, 
    required this.channel, 
    required this.playlist,
    this.playlistModel,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static const MethodChannel _exoChannel = MethodChannel('aladin/exoplayer');

  @override
  void initState() {
    super.initState();
    _launch();
  }

  Future<void> _launch() async {
    // ── GUARD: Xtream dizisinde url boş olabilir (ana seri kaydı).
    // Bu durumda native player yerine dizi detay sayfasına yönlendir.
    if (widget.channel.url.trim().isEmpty) {
      if (!mounted) return;
      // initState'ten Navigator kullanmak için bir frame bekle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AladinSeriesDetailPage(
              playlistId: widget.channel.playlistId,
              seriesName: widget.channel.seriesName ?? widget.channel.name,
              seriesId: widget.channel.tvgId,
              playlistModel: widget.playlistModel,
            ),
          ),
        );
      });
      return;
    }
    await _launchNativePlayer();
  }

  Future<void> _launchNativePlayer() async {
    try {
      final index = widget.playlist.indexOf(widget.channel);
      // Playlist'teki boş URL'leri filtrele — native player'a sadece oynatılabilir içerik gönder
      final playable = widget.playlist.where((e) => e.url.trim().isNotEmpty).toList();
      final filteredIndex = playable.indexOf(widget.channel).clamp(0, playable.length - 1);

      final urls         = playable.map((e) => e.url).toList();
      final names        = playable.map((e) => e.name).toList();
      final descriptions = playable.map((e) => e.tmdbOverview ?? '').toList();
      final posters      = playable.map((e) => e.tmdbPoster ?? '').toList();
      final ratings      = playable.map((e) => e.imdbRating ?? '').toList();
      final years        = playable.map((e) => e.tmdbYear ?? '').toList();
      final types        = playable.map((e) => e.contentType).toList();

      await _exoChannel.invokeMethod('playNative', {
        'urls':         urls,
        'names':        names,
        'descriptions': descriptions,
        'posters':      posters,
        'ratings':      ratings,
        'years':        years,
        'types':        types,
        'index':        filteredIndex >= 0 ? filteredIndex : 0,
      });
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Native Player Hatası: $e");
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // url boşsa yönlendirme devam ediyor; yükleniyor göstergesi göster
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );
  }
}
