import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/aladin_channel_model.dart';
import '../../core/models/aladin_epg_model.dart';
import '../../core/services/aladin_epg_service.dart';
import '../theme/aladin_app_theme.dart';
import 'aladin_manual_logos.dart';

class ChannelCard extends StatefulWidget {
  final ChannelModel channel;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final double width;
  final double height;
  final bool showEpg;
  final bool tvMode;
  final double? seriesProgress;
  final EdgeInsets? margin;

  const ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.onFavoriteTap,
    this.width = AppTheme.cardWidth,
    this.height = AppTheme.cardHeight,
    this.showEpg = false,
    this.tvMode = false,
    this.seriesProgress,
    this.margin,
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> {
  bool _focused = false;
  EpgProgramModel? _nowPlaying;
  bool _epgLoaded = false;

  static const _kHeaders = <String, String>{
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  @override
  void initState() {
    super.initState();
    if (widget.showEpg && widget.channel.contentType == 'tv') _loadEpg();
  }

  Future<void> _loadEpg() async {
    final ch = widget.channel;
    final id = (ch.tvgId?.isNotEmpty == true) ? ch.tvgId! : ch.name;
    try {
      final now = await EpgService.instance.getNowPlaying(id, cleanName: ch.name);
      if (mounted) setState(() { _nowPlaying = now; _epgLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _epgLoaded = true);
    }
  }

  String get _displayRating {
    final r = double.tryParse(widget.channel.imdbRating ?? '0') ?? 0.0;
    return r > 0 ? r.toStringAsFixed(1) : '';
  }

  String get _cleanName {
    final name = (widget.channel.contentType == 'series' && widget.channel.seriesName?.isNotEmpty == true)
        ? widget.channel.seriesName!
        : widget.channel.name;
    return name.replaceFirst(RegExp(r'^\d+[\.\-\)\s]+'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = _focused;
    final rating = _displayRating;
    final year = widget.channel.tmdbYear;
    final cleanName = _cleanName;
    
    final double progress = widget.seriesProgress ?? (widget.channel.totalDurationSeconds > 0 
        ? (widget.channel.watchedSeconds / widget.channel.totalDurationSeconds).clamp(0.01, 1.0)
        : 0.0);

    return Focus(
      onFocusChange: (v) {
        setState(() => _focused = v);
        if (v) {
          // Kart odaklandığında ekranın ortasına veya görünür alana gelmesini sağlar
          Scrollable.ensureVisible(
            context,
            alignment: 0.5, // 0.5 değeri kartı ekranın dikey/yatay ortasına getirir
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), // Odaklanma animasyon süresi
          curve: Curves.easeInOut,
          width: widget.width, // AppTheme.cardWidth
          height: widget.height, // AppTheme.cardHeight
          margin: widget.margin ?? const EdgeInsets.only(right: 12), // Kartlar arası boşluk
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()..scaleByDouble(isSelected ? 1.08 : 1.0, isSelected ? 1.08 : 1.0, 1.0, 1.0), // Odaklanınca %8 büyüme
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10), // Kart köşe yuvarlaması
            border: Border.all(
              color: isSelected ? Colors.redAccent : Colors.transparent, // Odak çerçevesi
              width: 3.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha:0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isSelected ? 7 : 10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildContent(), // Afiş veya Logo

                // Alt karartma gradyanı
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha:0.05),
                          Colors.black.withValues(alpha:0.7),
                          Colors.black.withValues(alpha:0.9),
                        ],
                        stops: const [0.0, 0.4, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),

                // IMDb Rozeti
                if (rating.isNotEmpty)
                  Positioned(
                    top: 6, left: 6,
                    child: _Badge(text: rating, label: 'IMDb', color: const Color(0xFFF5C518), textColor: Colors.black),
                  ),

                // Yıl Rozeti
                if (year != null && year.isNotEmpty)
                  Positioned(
                    top: 6, right: 6,
                    child: _Badge(text: year, color: Colors.black54, textColor: Colors.white, isYear: true),
                  ),

                // İsim ve EPG Bilgisi Alanı
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  height: 85, // 4 satır için yükseklik
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NameBar(
                          displayName: cleanName,
                          channel: widget.channel,
                          nowPlaying: _epgLoaded ? _nowPlaying : null,
                        ),
                      ],
                    ),
                  ),
                ),

                // İzleme İlerleme Çubuğu (VOD / Dizi)
                if (progress > 0 && widget.channel.contentType != 'tv')
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      height: 4,
                      alignment: Alignment.centerLeft,
                      color: Colors.white10,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            boxShadow: [
                              BoxShadow(color: Colors.redAccent, blurRadius: 4)
                            ]
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final ch = widget.channel;
    final isTv = ch.contentType == 'tv' || widget.tvMode;
    final fit = isTv ? BoxFit.contain : BoxFit.cover;

    final String? playlistUrl = (ch.logoUrl != null && ch.logoUrl!.isNotEmpty)
        ? ch.logoUrl!.split('|').first.trim()
        : null;
    final String? githubUrl = isTv ? AladinManualLogos.urlFor(ch.name, ch.tvgId) : null;
    final String? vodUrl = isTv ? null : ch.tmdbPoster;

    final color = _getChannelColor(ch.name);

    Widget? imageWidget;
    if (playlistUrl != null && playlistUrl.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: playlistUrl,
        httpHeaders: _kHeaders,
        fit: fit,
        memCacheWidth: 250, memCacheHeight: 350,
        placeholder: (_, __) => _placeholder(color),
        errorWidget: (_, __, ___) {
          if (vodUrl != null && vodUrl.isNotEmpty) return _img(vodUrl, BoxFit.cover);
          if (githubUrl != null) return _img(githubUrl, fit);
          return _placeholder(color);
        },
      );
    } else if (vodUrl != null && vodUrl.isNotEmpty) {
      imageWidget = _img(vodUrl, BoxFit.cover);
    } else if (githubUrl != null) {
      imageWidget = _img(githubUrl, fit);
    }

    if (imageWidget != null) {
      if (isTv) {
        return Container(color: AppTheme.card, padding: const EdgeInsets.fromLTRB(25, 10, 25, 25), child: Center(child: imageWidget)); // TV LOGO BUYUKLUGU
      }
      return imageWidget;
    }
    return _placeholder(color);
  }

  Widget _img(String url, BoxFit fit) => CachedNetworkImage(
    imageUrl: url, httpHeaders: _kHeaders, fit: fit,
    memCacheWidth: 250, memCacheHeight: 350,
    placeholder: (_, __) => _placeholder(_getChannelColor(widget.channel.name)),
    errorWidget: (_, __, ___) => _placeholder(_getChannelColor(widget.channel.name)),
  );

  Color _getChannelColor(String name) {
    const palette = [Color(0xFF378ADD), Color(0xFF1D9E75), Color(0xFFD85A30), Color(0xFFD4537E), Color(0xFF7F77DD), Color(0xFFBA7517)];
    if (name.isEmpty) return palette[0];
    final h = name.codeUnits.fold(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    return palette[h % palette.length];
  }

  Widget _placeholder(Color color) {
    final ch = widget.channel;
    final seriesInfo = (ch.contentType == 'series' && ch.season != null) 
        ? 'S${ch.season} E${ch.episode ?? '?'}' 
        : '';
    return Container(
      color: AppTheme.card,
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _cleanName,
              textAlign: TextAlign.center,
              maxLines: 4, // 4 Satır
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (seriesInfo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(seriesInfo, style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w900)),
            ],
          ],
        ),
      ),
    );
  }
}

class _NameBar extends StatelessWidget {
  final String displayName;
  final ChannelModel channel;
  final EpgProgramModel? nowPlaying;
  const _NameBar({required this.displayName, required this.channel, this.nowPlaying});

  @override
  Widget build(BuildContext context) {
    final hasEpg = nowPlaying != null;
    final seriesInfo = (channel.contentType == 'series' && channel.season != null) 
        ? 'S${channel.season} E${channel.episode ?? '?'}' 
        : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, height: 1.1),
          maxLines: 4, // 4 Satır
          overflow: TextOverflow.ellipsis,
        ),
        if (seriesInfo.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(seriesInfo, style: const TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.w900)),
        ],
        if (hasEpg) ...[
          const SizedBox(height: 2),
          Text(
            nowPlaying!.title,
            style: const TextStyle(color: AppTheme.accent, fontSize: 9, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final String? label;
  final Color color;
  final Color textColor;
  final bool isYear;
  const _Badge({required this.text, this.label, required this.color, required this.textColor, this.isYear = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[Text(label!, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: textColor)), const SizedBox(width: 3)],
        Text(text, style: TextStyle(fontSize: isYear ? 8 : 9, fontWeight: FontWeight.w900, color: textColor)),
      ],
    ),
  );
}
