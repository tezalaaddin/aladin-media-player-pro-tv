import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/aladin_channel_model.dart';
import '../../core/services/aladin_channel_service.dart';
import '../../core/state/aladin_app_state.dart';
import '../../shared/theme/aladin_app_theme.dart';
import '../../shared/widgets/aladin_app_bar.dart';
import '../../shared/widgets/aladin_channel_card.dart';
import '../player/aladin_player_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ChannelModel> _allFavs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initLoad();
  }

  void _initLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<AppState>();
      s.addListener(_onStateChange);
      if (s.active != null) _load(s.active!.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    try { context.read<AppState>().removeListener(_onStateChange); } catch (_) {}
    super.dispose();
  }

  void _onStateChange() {
    final a = context.read<AppState>().active;
    if (a != null && mounted) _load(a.id);
  }

  Future<void> _load(int id) async {
    if (!mounted) return;
    setState(() => _loading = true);
    final rawFavs = await ChannelService.instance.getFavorites(id);
    if (!mounted) return;
    setState(() {
      _allFavs = rawFavs;
      _loading = false;
    });
  }

  void _play(ChannelModel ch, List<ChannelModel> currentList) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          channel: ch, 
          playlist: currentList, 
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AladinAppBar(
        title: s.navFavorites,
        onRefresh: state.active != null ? () => _load(state.active!.id) : null,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textMuted,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: s.all),
            Tab(text: s.liveTv),
            Tab(text: s.movies),
            Tab(text: s.series),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGrid(_allFavs), 
                _buildGrid(_allFavs.where((e) => e.contentType == 'tv').toList()), 
                _buildGrid(_allFavs.where((e) => e.contentType == 'movie').toList()), 
                _buildGrid(_allFavs.where((e) => e.contentType == 'series').toList()), 
              ],
            ),
    );
  }

  Widget _buildGrid(List<ChannelModel> list) {
    if (list.isEmpty) return _buildEmptyState(context.read<AppState>().s);
    
    final double safePadding = MediaQuery.of(context).size.width * 0.04;

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: safePadding, vertical: 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: AppTheme.cardWidth + 20,
        mainAxisSpacing: 25,
        crossAxisSpacing: 15,
        mainAxisExtent: AppTheme.gridHeight,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final ch = list[index];
        return Center(
          child: ChannelCard(
            channel: ch,
            margin: EdgeInsets.zero,
            onTap: () => _play(ch, list),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(dynamic s) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 80, color: AppTheme.textMuted.withValues(alpha:0.2)),
          const SizedBox(height: 16),
          Text(s.noFavorites, style: const TextStyle(color: AppTheme.textMuted, fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
