import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/models/aladin_category_model.dart';
import '../core/services/aladin_epg_engine.dart';
import '../core/services/aladin_metadata_sync_service.dart';
import '../core/state/aladin_app_prefs.dart';
import '../core/state/aladin_app_state.dart';
import '../shared/theme/aladin_app_theme.dart';
import 'live_tv/aladin_live_tv_page.dart';
import 'movies/aladin_movies_page.dart';
import 'series/aladin_series_page.dart';
import 'favorites/aladin_favorites_page.dart';
import 'search/aladin_search_page.dart';
import 'settings/aladin_settings_page.dart';
import 'player/aladin_player_page.dart';
import 'content/aladin_category_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _index = 0;
  final FocusScopeNode _mainFocusScope = FocusScopeNode();
  bool _epgDialogShown = false;
  
  CategoryModel? _selectedCategory;

  void _goTo(int i) {
    if (_index == i && _selectedCategory == null) return;
    setState(() {
      _index = i;
      _selectedCategory = null; 
    });
  }

  void _openCategory(CategoryModel cat) {
    setState(() => _selectedCategory = cat);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeId = AppState.instance.active?.id;
      if (activeId != null) {
        MetadataSyncService.instance.startSync(activeId);
      }
    });
  }

  // _checkEpgSync fonksiyonu buradan tamamen kaldırıldı (Ayarlar sayfasına taşındı)

  @override
  void dispose() {
    _mainFocusScope.dispose();
    super.dispose();
  }

  KeyEventResult _handleGlobalKeys(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.colorF0Red || key == LogicalKeyboardKey.f1) {
      _goTo(0);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.colorF1Green || key == LogicalKeyboardKey.f2) {
      _goTo(1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.colorF2Yellow || key == LogicalKeyboardKey.f3) {
      _goTo(2);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.colorF3Blue || key == LogicalKeyboardKey.f4) {
      _goTo(5);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    Widget content;
    if (_selectedCategory != null) {
      content = AladinCategoryPage(
        category: _selectedCategory!,
        playlistId: state.active!.id,
        onChannelTap: (ch) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerPage(
                channel: ch,
                playlist: [ch], // Default for now, though better would be to pass the category list
              ),
            ),
          );
        },
        onBack: () => setState(() => _selectedCategory = null),
      );
    } else {
      final pages = [
        LiveTvPage(
          onGoToSettings: () => _goTo(5),
          onCategoryTap: _openCategory,
        ),
        MoviesPage(onCategoryTap: _openCategory),
        SeriesPage(onCategoryTap: _openCategory),
        const FavoritesPage(),
        SearchPage(isActive: _index == 4),
        SettingsPage(
          onPlaylistSelected: () {
            _goTo(0);
            final activeId = AppState.instance.active?.id;
            if (activeId != null) {
              MetadataSyncService.instance.startSync(activeId);
            }
          },
        ),
      ];
      content = IndexedStack(index: _index, children: pages);
    }

    return FocusScope(
      node: _mainFocusScope,
      autofocus: true,
      child: Focus(
        onKeyEvent: (node, event) => _handleGlobalKeys(event),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            
            if (_selectedCategory != null) {
              setState(() => _selectedCategory = null);
              return;
            }

            if (_index != 0) {
              _goTo(0);
              return;
            }
            final shouldExit = await _showExitConfirmation(s);
            if (shouldExit && mounted) {
              await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: Row(
              children: [
                if (isLandscape) _SideNavBar(
                  currentIndex: _index,
                  onTap: _goTo,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        child: content,
                      ),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(child: RepaintBoundary(child: _SyncProgressBar())),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isLandscape ? null : BottomNavigationBar(
              currentIndex: _index,
              onTap: _goTo,
              selectedItemColor: AppTheme.accent,
              unselectedItemColor: AppTheme.textMuted,
              backgroundColor: AppTheme.surface,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: [
                BottomNavigationBarItem(icon: const Icon(Icons.live_tv), label: s.navLiveTV),
                BottomNavigationBarItem(icon: const Icon(Icons.movie), label: s.navMovies),
                BottomNavigationBarItem(icon: const Icon(Icons.video_library), label: s.navSeries),
                BottomNavigationBarItem(icon: const Icon(Icons.favorite), label: s.navFavorites),
                BottomNavigationBarItem(icon: const Icon(Icons.search), label: s.navSearch),
                BottomNavigationBarItem(icon: const Icon(Icons.settings), label: s.navSettings),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmation(dynamic s) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.card,
            title: Text(s.exitConfirmTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            content: Text(s.exitConfirmMsg, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              _TVDialogButton(
                label: s.no, 
                onPressed: () => Navigator.pop(context, false)
              ),
              _TVDialogButton(
                label: s.yes, 
                isPrimary: true, 
                onPressed: () => Navigator.pop(context, true)
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ── TV UI Components ─────────────────────────────────────────────────────────

class _TVDialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _TVDialogButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  State<_TVDialogButton> createState() => _TVDialogButtonState();
}

class _TVDialogButtonState extends State<_TVDialogButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.isPrimary,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: _focused ? AppTheme.accent : (widget.isPrimary ? AppTheme.card : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _focused ? Colors.white : (widget.isPrimary ? AppTheme.accent : Colors.transparent),
            width: 2,
          ),
          boxShadow: _focused ? [BoxShadow(color: AppTheme.accent.withValues(alpha:0.4), blurRadius: 10)] : null,
        ),
        transform: Matrix4.identity()..scale(_focused ? 1.05 : 1.0),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _focused ? Colors.white : (widget.isPrimary ? AppTheme.accent : AppTheme.textMuted),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _SideNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _SideNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: AppTheme.accent.withValues(alpha:0.4), blurRadius: 10)
                    ]
                  ),
                  child: const Icon(Icons.live_tv, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'aladinIPTV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'FOR SMART TV',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _SideNavItem(
                  icon: Icons.live_tv,
                  label: s.navLiveTV,
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                  colorHint: Colors.red,
                  autofocus: true, 
                ),
                _SideNavItem(
                  icon: Icons.movie,
                  label: s.navMovies,
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                  colorHint: Colors.green,
                ),
                _SideNavItem(
                  icon: Icons.video_library,
                  label: s.navSeries,
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                  colorHint: Colors.yellow,
                ),
                _SideNavItem(
                  icon: Icons.search,
                  label: s.navSearch,
                  isSelected: currentIndex == 4,
                  onTap: () => onTap(4),
                ),
                _SideNavItem(
                  icon: Icons.favorite,
                  label: s.navFavorites,
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
                _SideNavItem(
                  icon: Icons.settings,
                  label: s.navSettings,
                  isSelected: currentIndex == 5,
                  onTap: () => onTap(5),
                  colorHint: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? colorHint;
  final bool autofocus;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.colorHint,
    this.autofocus = false,
  });

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (v) => setState(() => _isFocused = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select || 
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              FocusScope.of(context).focusInDirection(TraversalDirection.right);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _isFocused ? AppTheme.accent : (widget.isSelected ? AppTheme.accent.withValues(alpha:0.15) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: _isFocused ? Border.all(color: Colors.white.withValues(alpha:0.5), width: 1) : null,
              boxShadow: _isFocused ? [
                BoxShadow(color: AppTheme.accent.withValues(alpha:0.3), blurRadius: 10, offset: const Offset(0, 4))
              ] : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: _isFocused ? Colors.white : (widget.isSelected ? AppTheme.accent : AppTheme.textSecondary),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: _isFocused ? Colors.white : (widget.isSelected ? Colors.white : AppTheme.textSecondary),
                      fontSize: 16,
                      fontWeight: widget.isSelected || _isFocused ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (widget.colorHint != null)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.colorHint,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncProgressBar extends StatelessWidget {
  const _SyncProgressBar();

  @override
  Widget build(BuildContext context) {
    final metadataSync = context.watch<MetadataSyncService>();
    final epgSync = context.watch<AladinEpgEngine>();
    final s = context.watch<AppState>().s;
    
    final isSyncing = metadataSync.isSyncing || epgSync.isSyncing;
    if (!isSyncing) return const SizedBox.shrink();

    final double value = epgSync.isSyncing ? epgSync.progress : metadataSync.progress;
    final String label = epgSync.isSyncing 
        ? "${s.epgSyncing} %${(value * 100).toInt()}" 
        : s.syncingData;

    return Container(
      height: 20,
      width: double.infinity,
      color: Colors.black54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            minHeight: 20,
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
