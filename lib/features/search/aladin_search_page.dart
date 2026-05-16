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
import '../player/aladin_player_page.dart';

class SearchPage extends StatefulWidget {
  final bool isActive;
  const SearchPage({super.key, this.isActive = false});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  final _textFieldFocusNode = FocusNode(debugLabel: 'search_textfield');
  Timer? _deb;
  List<ChannelModel> _results = [];
  bool _searching = false;
  String _last = '';

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _triggerFocus();
    }
  }

  @override
  void didUpdateWidget(SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _triggerFocus();
    }
  }

  void _triggerFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFieldFocusNode.requestFocus();
        // TV'de klavyeyi bazen manuel tetiklemek gerekebilir
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _textFieldFocusNode.dispose();
    _deb?.cancel();
    super.dispose();
  }

  void _onChange(String q) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query == _last) return;
    _last = query;
    if (query.isEmpty) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    final active = context.read<AppState>().active;
    if (active == null) { setState(() => _searching = false); return; }
    final r = await ChannelService.instance.search(playlistId: active.id, query: query);
    if (mounted) { setState(() { _results = r; _searching = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final double safePadding = MediaQuery.of(context).size.width * 0.04;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AladinAppBar(),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: safePadding, vertical: 10),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  // Kumanda ile Yukarı veya Aşağı basınca textfield'dan çık
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown || 
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _textFieldFocusNode.unfocus();
                    return KeyEventResult.ignored;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _ctrl,
                focusNode: _textFieldFocusNode,
                onChanged: _onChange,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: state.s.searchHint,
                  prefixIcon: const Icon(Icons.search, color: AppTheme.accent),
                  filled: true,
                  fillColor: AppTheme.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : _results.isEmpty
                    ? _buildEmptyState(state.s)
                    : GridView.builder(
                        padding: EdgeInsets.symmetric(horizontal: safePadding, vertical: 10),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: AppTheme.cardWidth + 20,
                          mainAxisSpacing: 25,
                          crossAxisSpacing: 15,
                          mainAxisExtent: AppTheme.gridHeight,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final ch = _results[i];
                          return Center(
                            child: ChannelCard(
                              channel: ch,
                              margin: EdgeInsets.zero,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(channel: ch, playlist: [ch]))),
                            ),
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
          Icon(Icons.search_off_rounded, size: 60, color: AppTheme.textMuted.withValues(alpha:0.2)),
          const SizedBox(height: 16),
          Text(_last.isNotEmpty ? s.noResultsFound : s.typeToSearch, style: const TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
