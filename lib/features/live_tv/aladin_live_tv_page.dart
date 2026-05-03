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

class LiveTvPage extends StatefulWidget {
  final VoidCallback? onGoToSettings;
  final void Function(CategoryModel)? onCategoryTap;

  const LiveTvPage({super.key, this.onGoToSettings, this.onCategoryTap});

  @override
  State<LiveTvPage> createState() => _LiveTvPageState();
}

class _LiveTvPageState extends State<LiveTvPage> {
  List<CategoryModel> _categories = [];
  List<ChannelModel> _recent = [];
  List<ChannelModel> _favorites = [];
  bool _loading = false;
  int? _loadedId;
  int _reloadCount = 0;

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
    final state = context.read<AppState>();
    final a = state.active;

    if (a == null && mounted) {
      setState(() {
        _categories = [];
        _loadedId = null;
      });
      return;
    }

    if (a == null) return;
    if (a.id != _loadedId) {
      _load(a.id);
    }
  }

  Future<void> _load(int id) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadedId = id;
      _reloadCount++; 
    });

    final cats = await ChannelService.instance
        .getCategories(playlistId: id, contentType: 'tv');
    
    final allRecent = await ChannelService.instance.getRecent(id, limit: 50);
    final vodRecent = allRecent.where((c) => c.contentType != 'tv').toList();
    
    final allFavs = await ChannelService.instance.getFavorites(id);
    final tvFavs = allFavs.where((c) => c.contentType == 'tv').toList();

    if (!mounted) return;
    setState(() {
      _categories = cats;
      _recent = vodRecent;
      _favorites = tvFavs;
      _loading = false;
    });
  }

  void _play(ChannelModel ch, List<ChannelModel> list) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => PlayerPage(channel: ch, playlist: list.isNotEmpty ? list : [ch])));

  Future<void> _toggleFav(ChannelModel ch) async {
    await ChannelService.instance.toggleFavorite(ch.id);
    if (_loadedId != null && mounted) _load(_loadedId!);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (_, state, __) {
      if (state.active == null) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: const AladinAppBar(),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.live_tv, size: 70, color: AppTheme.textMuted),
                const SizedBox(height: 20),
                Text(
                  state.s.noPlaylistSelected,
                  style: AppTheme.headingMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  state.s.addPlaylistHint,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: widget.onGoToSettings,
                  icon: const Icon(Icons.settings),
                  label: Text(state.s.goToSettings),
                ),
              ],
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AladinAppBar(
          onRefresh: () => _load(state.active!.id),
        ),
        body: RefreshIndicator(
          color: AppTheme.accent,
          onRefresh: () => _load(state.active!.id),
          child: _loading && _categories.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent))
              : _categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 50, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            state.s.noPlaylistSelected, 
                            style:
                                const TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: widget.onGoToSettings,
                            icon: const Icon(Icons.add),
                            label: Text(
                                state.s.addPlaylist),
                          ),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.05,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              if (_recent.isNotEmpty)
                                _HorizStrip(
                                  title: '🕒 ${state.s.continueWatching}',
                                  channels: _recent,
                                  onTap: (ch) => _play(ch, _recent),
                                ),

                              if (_favorites.isNotEmpty)
                                _HorizStrip(
                                  title: '⭐ ${state.s.favorites}',
                                  channels: _favorites,
                                  onTap: (ch) => _play(ch, _favorites),
                                ),
                            ]),
                          ),
                        ),

                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.05,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => CategoryRow(
                                key: ValueKey(
                                    '${_categories[i].id}_r$_reloadCount'),
                                category: _categories[i],
                                playlistId: state.active!.id,
                                onChannelTap: (ch, list) => _play(ch, list), // Listeyi de gönderiyoruz
                                onCategoryTap: widget.onCategoryTap,
                                onFavorite: _toggleFav,
                                tvMode: true,
                                showEpg: true, 
                              ),
                              childCount: _categories.length,
                            ),
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
        ),
      );
    });
  }
}

class _HorizStrip extends StatelessWidget {
  final String title;
  final List<ChannelModel> channels;
  final void Function(ChannelModel) onTap;

  const _HorizStrip({
    required this.title,
    required this.channels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
            child: Text(title, style: AppTheme.headingMedium),
          ),
          SizedBox(
            height: 190, // yatay listenin toplam kapladiği alan yuksekligi
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: channels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              clipBehavior: Clip.none,
              itemBuilder: (_, i) => ChannelCard(
                channel: channels[i],
                width: 130, 
                height: 175,
                tvMode: true,
                onTap: () => onTap(channels[i]),
              ),
            ),
          ),
        ],
      );
}
