import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/models/aladin_category_model.dart';
import '../core/services/aladin_metadata_sync_service.dart';
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
  final List<FocusNode> _navNodes = List.generate(6, (index) => FocusNode());
  final FocusNode _contentFocusNode = FocusNode();
  bool _epgDialogShown = false;
  DateTime? _lastKeyEventTime;
  
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
      final state = AppState.instance;
      final activeId = state.active?.id;
      if (activeId != null) {
        MetadataSyncService.instance.startSync(activeId, lang: state.lang);
      }
    });
  }

  @override
  void dispose() {
    _mainFocusScope.dispose();
    _contentFocusNode.dispose();
    for (final n in _navNodes) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleGlobalKeys(KeyEvent event) {
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // ── KESİN ÇÖZÜM: Yazı alanı kontrolü
    final primaryFocus = FocusManager.instance.primaryFocus;
    bool isEditable = false;
    
    if (primaryFocus != null) {
      final context = primaryFocus.context;
      final dbg = primaryFocus.debugLabel?.toLowerCase() ?? '';
      isEditable = context?.widget is EditableText ||
                   context?.findAncestorWidgetOfExactType<TextField>() != null ||
                   dbg.contains('editable') ||
                   dbg.contains('field') ||
                   dbg.contains('input');
    }

    final now = DateTime.now();
    if (_lastKeyEventTime != null && now.difference(_lastKeyEventTime!) < const Duration(milliseconds: 150)) {
      return KeyEventResult.handled;
    }
    _lastKeyEventTime = now;

    final key = event.logicalKey;
    final label = event.logicalKey.keyLabel;

    // Navigasyon Haritası
    final Map<String, int> navMap = {
      '1': 0, // Live TV
      '2': 1, // Movies
      '3': 2, // Series
      '4': 4, // Search
      '5': 3, // Favorites
      '6': 5, // Settings
    };

    // Arama (4) ve Ayarlar (5) sayfalarında sayı kısayollarını tamamen devre dışı bırakıyoruz.
    // Ayrıca herhangi bir sayfada metin alanındaysak da engelliyoruz.
    if ((_index == 4 || _index == 5 || isEditable) && navMap.containsKey(label)) {
      return KeyEventResult.ignored;
    }

    int? targetIndex;
    if (key == LogicalKeyboardKey.colorF0Red || key == LogicalKeyboardKey.f1) targetIndex = 0;
    else if (key == LogicalKeyboardKey.colorF1Green || key == LogicalKeyboardKey.f2) targetIndex = 1;
    else if (key == LogicalKeyboardKey.colorF2Yellow || key == LogicalKeyboardKey.f3) targetIndex = 2;
    else if (key == LogicalKeyboardKey.colorF3Blue || key == LogicalKeyboardKey.f4) targetIndex = 5;
    else if (navMap.containsKey(label)) targetIndex = navMap[label];

    if (targetIndex != null) {
      _goTo(targetIndex);
      // Navigasyon barındaki ilgili butona odaklan
      _navNodes[targetIndex].requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    final reqIdx = state.requestedIndex;
    if (reqIdx != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          state.clearNavigationRequest(); // Önce temizle (side effect frame sonunda)
          _goTo(reqIdx);
          if (reqIdx < _navNodes.length) {
            _navNodes[reqIdx].requestFocus();
          }
        }
      });
    }

    final s = state.s;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    Widget content;
    if (_selectedCategory != null) {
      content = AladinCategoryPage(
        category: _selectedCategory!,
        playlistId: state.active!.id,
        onChannelTap: (ch, list) {
          if (ch.contentType == 'series') {
            final name = ch.seriesName?.trim().isNotEmpty == true ? ch.seriesName! : ch.name;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AladinSeriesDetailPage(
                  seriesName: name,
                  playlistId: state.active!.id,
                  seriesId: ch.parentSeriesId ?? ch.tvgId,
                  playlistModel: state.active,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerPage(
                  channel: ch,
                  playlist: list,
                ),
              ),
            );
          }
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
            final state = AppState.instance;
            final activeId = state.active?.id;
            if (activeId != null) {
              MetadataSyncService.instance.startSync(activeId, lang: state.lang);
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
            
            _navNodes[_index].requestFocus();

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
            } else {
              _navNodes[_index].requestFocus();
            }
          },
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: Row(
              children: [
                if (isLandscape) _SideNavBar(
                  currentIndex: _index,
                  onTap: _goTo,
                  nodes: _navNodes,
                  onRightPressed: () => _contentFocusNode.requestFocus(),
                ),
                Expanded(
                  child: Focus(
                    focusNode: _contentFocusNode,
                    skipTraversal: true,
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: content,
                    ),
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
      child: GestureDetector(
        onTap: widget.onPressed,
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
      ),
    );
  }
}

class _SideNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FocusNode> nodes;
  final VoidCallback onRightPressed;

  const _SideNavBar({required this.currentIndex, required this.onTap, required this.nodes, required this.onRightPressed});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    return Container(
      width: 280, // Biraz daha geniş ve ferah
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(right: BorderSide(color: Colors.white12, width: 1)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surface,
            AppTheme.background.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.appNameShort,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        s.forSmartTv,
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _SideNavItem(
                    focusNode: nodes[0],
                    icon: Icons.live_tv,
                    label: s.navLiveTV,
                    isSelected: currentIndex == 0,
                    onTap: () => onTap(0),
                    onRightPressed: onRightPressed,
                    colorHint: Colors.red,
                    numberHint: '1',
                    autofocus: currentIndex == 0, 
                  ),
                  _SideNavItem(
                    focusNode: nodes[1],
                    icon: Icons.movie,
                    label: s.navMovies,
                    isSelected: currentIndex == 1,
                    onTap: () => onTap(1),
                    onRightPressed: onRightPressed,
                    colorHint: Colors.green,
                    numberHint: '2',
                  ),
                  _SideNavItem(
                    focusNode: nodes[2],
                    icon: Icons.video_library,
                    label: s.navSeries,
                    isSelected: currentIndex == 2,
                    onTap: () => onTap(2),
                    onRightPressed: onRightPressed,
                    colorHint: Colors.yellow,
                    numberHint: '3',
                  ),
                  _SideNavItem(
                    focusNode: nodes[4],
                    icon: Icons.search,
                    label: s.navSearch,
                    isSelected: currentIndex == 4,
                    onTap: () => onTap(4),
                    onRightPressed: onRightPressed,
                    colorHint: Colors.blue,
                    numberHint: '4',
                  ),
                  _SideNavItem(
                    focusNode: nodes[3],
                    icon: Icons.favorite,
                    label: s.navFavorites,
                    isSelected: currentIndex == 3,
                    onTap: () => onTap(3),
                    onRightPressed: onRightPressed,
                    numberHint: '5',
                  ),
                  _SideNavItem(
                    focusNode: nodes[5],
                    icon: Icons.settings,
                    label: s.navSettings,
                    isSelected: currentIndex == 5,
                    onTap: () => onTap(5),
                    onRightPressed: onRightPressed,
                    numberHint: '6',
                  ),
                ],
              ),
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
  final VoidCallback? onRightPressed;
  final Color? colorHint;
  final String? numberHint;
  final bool autofocus;
  final FocusNode? focusNode;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onRightPressed,
    this.colorHint,
    this.numberHint,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _isFocused = false;
  // Madde 4: static OLMAMALI — static olunca tüm nav item'lar aynı zamayıcıyı
  // paylaşır; bir butona basmak diğerlerini 250ms kilitler.
  DateTime? _lastNavTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: (v) => setState(() => _isFocused = v),
        onKeyEvent: (node, event) {
          if (event is KeyRepeatEvent) return KeyEventResult.handled;
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          final now = DateTime.now();
          if (_lastNavTime != null && now.difference(_lastNavTime!) < const Duration(milliseconds: 250)) {
            final k = event.logicalKey;
            if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowUp || 
                k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter) {
              return KeyEventResult.handled;
            }
          }
          _lastNavTime = now;

          if (event.logicalKey == LogicalKeyboardKey.select || 
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (FocusScope.of(context).focusInDirection(TraversalDirection.right)) {
              return KeyEventResult.handled;
            }
            widget.onRightPressed?.call();
            return KeyEventResult.handled;
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
                if (widget.numberHint != null)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: widget.colorHint ?? AppTheme.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.numberHint!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
}
