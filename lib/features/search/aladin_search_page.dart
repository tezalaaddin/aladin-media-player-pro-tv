import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models/aladin_channel_model.dart';
import '../../core/services/aladin_channel_service.dart';
import '../../core/state/aladin_app_state.dart';
import '../../shared/theme/aladin_app_theme.dart';
import '../../shared/widgets/aladin_app_bar.dart';
import '../../shared/widgets/aladin_channel_card.dart';
import '../../shared/widgets/aladin_input_dialog.dart';
import '../player/aladin_player_page.dart';

class SearchPage extends StatefulWidget {
  final bool isActive;
  const SearchPage({super.key, this.isActive = false});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _textFieldFocusNode = FocusNode(debugLabel: 'search_button_focus');
  String _query = '';
  List<ChannelModel> _results = [];
  bool _searching = false;
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _triggerFocus();
  }

  @override
  void didUpdateWidget(SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _triggerFocus();
  }

  void _triggerFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFieldFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textFieldFocusNode.dispose();
    _deb?.cancel();
    super.dispose();
  }

  Future<void> _openSearchInput() async {
    final state = context.read<AppState>();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AladinInputDialog(
        title: state.s.searchHint,
        initialValue: _query,
        icon: Icons.search,
        confirmLabel: state.s.navSearch,
      ),
    );

    if (result != null) {
      setState(() => _query = result);
      _doSearch(result);
    }
  }

  Future<void> _doSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    final active = context.read<AppState>().active;
    if (active == null) return;
    
    final r = await ChannelService.instance.search(playlistId: active.id, query: query);
    if (mounted) setState(() { _results = r; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AladinAppBar(),
      body: Column(
        children: [
          // Premium Arama Çubuğu (Aslında bir buton)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 20, 40, 20),
            child: _SearchTrigger(
              focusNode: _textFieldFocusNode,
              query: _query,
              hint: s.searchHint,
              onTap: _openSearchInput,
            ),
          ),

          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : _results.isEmpty
                    ? _buildEmptyState(s)
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: AppTheme.cardWidth + 40,
                          mainAxisSpacing: 30,
                          crossAxisSpacing: 20,
                          mainAxisExtent: AppTheme.gridHeight,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final ch = _results[i];
                          return ChannelCard(
                            channel: ch,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: ch, playlist: [ch]))),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic s) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.white10),
          const SizedBox(height: 24),
          Text(_query.isNotEmpty ? s.noResultsFound : s.typeToSearch, 
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 18, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SearchTrigger extends StatefulWidget {
  final FocusNode focusNode;
  final String query;
  final String hint;
  final VoidCallback onTap;

  const _SearchTrigger({required this.focusNode, required this.query, required this.hint, required this.onTap});

  @override
  State<_SearchTrigger> createState() => _SearchTriggerState();
}

class _SearchTriggerState extends State<_SearchTrigger> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: _focused ? Colors.white : AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _focused ? Colors.white : Colors.white10, width: 2),
            boxShadow: _focused ? [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 20)] : null,
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: _focused ? Colors.black : AppTheme.accent, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.query.isEmpty ? widget.hint : widget.query,
                  style: TextStyle(
                    color: _focused ? Colors.black : (widget.query.isEmpty ? AppTheme.textMuted : Colors.white),
                    fontSize: 20,
                    fontWeight: widget.query.isEmpty ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ),
              if (widget.query.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close, color: _focused ? Colors.black45 : Colors.white24),
                  onPressed: () {
                    // Bu buton odaklanılabilir olmamalı, sadece dokunmatik için veya 
                    // ana kutuya tıklanınca zaten input açılacak.
                  },
                ),
              if (widget.query.isEmpty)
                Icon(Icons.keyboard, color: _focused ? Colors.black26 : Colors.white12, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
