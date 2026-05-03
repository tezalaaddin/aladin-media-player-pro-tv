import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/aladin_category_model.dart';
import '../../core/models/aladin_channel_model.dart';
import '../../core/services/aladin_channel_service.dart';
import '../../core/state/aladin_app_state.dart';
import '../../shared/theme/aladin_app_theme.dart';
import '../../shared/widgets/aladin_app_bar.dart';
import '../../shared/widgets/aladin_category_row.dart';
import '../../shared/widgets/aladin_channel_card.dart';
import '../player/aladin_player_page.dart';

class MoviesPage extends StatefulWidget {
  final void Function(CategoryModel)? onCategoryTap;
  const MoviesPage({super.key, this.onCategoryTap});
  @override
  State<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends State<MoviesPage> {
  List<CategoryModel> _categories = [];
  List<ChannelModel> _favorites = [];
  bool _loading = false;
  int? _loadedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppState>();
      s.addListener(_onState);
      if (s.active != null) _load(s.active!.id);
    });
  }

  @override
  void dispose() {
    try {
      context.read<AppState>().removeListener(_onState);
    } catch (_) {}
    super.dispose();
  }

  void _onState() {
    final a = context.read<AppState>().active;
    if (a != null && a.id != _loadedId) _load(a.id);
  }

  Future<void> _load(int id) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadedId = id;
    });
    final cats = await ChannelService.instance
        .getCategories(playlistId: id, contentType: 'movie');
    final allFavs = await ChannelService.instance.getFavorites(id);
    final movieFavs = allFavs.where((c) => c.contentType == 'movie').toList();

    if (!mounted) return;
    setState(() {
      _categories = cats;
      _favorites = movieFavs;
      _loading = false;
    });
  }

  void _play(ChannelModel ch, List<ChannelModel> list) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => PlayerPage(channel: ch, playlist: list.isNotEmpty ? list : [ch])));

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (_, state, __) {
      final s = state.s;
      final noList = state.active == null;
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AladinAppBar(
            onRefresh:
                state.active != null ? () => _load(state.active!.id) : null),
        body: noList
            ? Center(
                child: Text(
                    s.addPlaylistHint,
                    style: const TextStyle(color: AppTheme.textSecondary)))
            : _loading && _categories.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent))
                : _categories.isEmpty
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Icon(Icons.movie_creation_outlined,
                                size: 50, color: AppTheme.textMuted), // Boş durum ikon boyutu
                            const SizedBox(height: 12), // İkon-Metin arası boşluk
                            Text(s.noMoviesFound,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary)),
                            const SizedBox(height: 16), // Metin-Buton arası boşluk
                            ElevatedButton.icon(
                                onPressed: () => _load(state.active!.id),
                                icon: const Icon(Icons.refresh),
                                label: Text(s.retry)),
                          ]))
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                            SliverPadding(
                              padding: EdgeInsets.symmetric(
                                horizontal: MediaQuery.of(context).size.width * 0.05, // Yan güvenli alan boşluğu
                              ),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  if (_favorites.isNotEmpty)
                                    _MovieFavStrip(
                                      title: '⭐ ${state.s.favorites}',
                                      channels: _favorites,
                                      onTap: (ch) => _play(ch, _favorites),
                                    ),
                                ]),
                              ),
                            ),
                            SliverPadding(
                              padding: EdgeInsets.symmetric(
                                horizontal: MediaQuery.of(context).size.width * 0.05, // Yan güvenli alan boşluğu
                              ),
                              sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                (_, i) => CategoryRow(
                                  key: ValueKey(_categories[i].id),
                                  category: _categories[i],
                                  playlistId: state.active!.id,
                                  onChannelTap: (ch, list) => _play(ch, list),
                                  onCategoryTap: widget.onCategoryTap,
                                ),
                                childCount: _categories.length,
                              )),
                            ),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 40)), // Liste sonu boşluğu
                          ]),
      );
    });
  }
}

class _MovieFavStrip extends StatelessWidget {
  final String title;
  final List<ChannelModel> channels;
  final void Function(ChannelModel) onTap;

  const _MovieFavStrip({
    required this.title,
    required this.channels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 8), // Şerit başlığı dış boşluğu
            child: Text(title, style: AppTheme.headingMedium),
          ),
          SizedBox(
            height: 245, // Şerit yüksekliği (Kart yüksekliği + Boşluk)
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14), // Şerit içi yan boşluklar
              itemCount: channels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12), // Kartlar arası boşluk
              clipBehavior: Clip.none,
              itemBuilder: (_, i) => ChannelCard(
                channel: channels[i],
                width: 130, // Standart genişlik
                height: 175, // Standart yükseklik
                onTap: () => onTap(channels[i]),
              ),
            ),
          ),
        ],
      );
}
