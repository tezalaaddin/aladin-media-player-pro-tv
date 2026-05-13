import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../../core/models/aladin_playlist_model.dart';
import '../../../core/services/aladin_playlist_service.dart';
import '../../core/services/aladin_epg_engine.dart';
import '../../../core/state/aladin_app_prefs.dart';
import '../../../core/state/aladin_app_state.dart';
import '../../../core/state/aladin_app_strings.dart';
import '../../../shared/theme/aladin_app_theme.dart';
import '../../../shared/widgets/aladin_folder_explorer.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onPlaylistSelected;
  final bool isActive;
  const SettingsPage({super.key, this.onPlaylistSelected, this.isActive = false});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  final _m3uUrl = TextEditingController();
  final _m3uName = TextEditingController();
  final _xtSrv = TextEditingController();
  final _xtUser = TextEditingController();
  final _xtPass = TextEditingController();
  final _xtName = TextEditingController();
  final _locName = TextEditingController();
  String? _localPath;

  // Focus Nodes
  final _fnM3uUrl = FocusNode();
  final _fnM3uName = FocusNode();
  final _fnM3uBtn = FocusNode();

  final _fnXtSrv = FocusNode();
  final _fnXtUser = FocusNode();
  final _fnXtPass = FocusNode();
  final _fnXtName = FocusNode();
  final _fnXtBtn = FocusNode();

  final _fnLocName = FocusNode();
  final _fnLocBtn = FocusNode();
  final _fnEpgBtn = FocusNode();

  bool _importing = false;
  bool _epgSyncing = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    final ctrls = [_m3uUrl, _m3uName, _xtSrv, _xtUser, _xtPass, _xtName, _locName];
    for (final c in ctrls) {
      c.dispose();
    }
    final nodes = [_fnM3uUrl, _fnM3uName, _fnM3uBtn, _fnXtSrv, _fnXtUser, _fnXtPass, _fnXtName, _fnXtBtn, _fnLocName, _fnLocBtn, _fnEpgBtn];
    for (final n in nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : AppTheme.accent,
        duration: const Duration(seconds: 3)));
  }

  String _pt(ImportProgress p, int c) {
    final state = context.read<AppState>();
    final s = state.s;
    return switch (p) {
      ImportProgress.downloading => s.downloadingDots,
      ImportProgress.parsing => s.parsing,
      ImportProgress.saving => '${c} ${s.channelsSaved}',
      ImportProgress.done => '✅ ${s.done}! $c ${s.channels}',
      ImportProgress.error => '❌ ${s.error}',
      ImportProgress.idle => '',
    };
  }

  Future<void> _importM3U() async {
    final state = context.read<AppState>();
    final s = state.s;
    String url = _m3uUrl.text.trim();
    final name = _m3uName.text.trim();

    if (url.isEmpty) {
      _snack(s.enterM3uUrl, error: true);
      return;
    }

    url = url.replaceAll(RegExp(r'[\u200b-\u200d\ufeff]'), '').trim();

    final existing = await PlaylistService.instance.findByUrl(url);
    if (existing != null && mounted) {
      final ok = await _confirmUpdate(existing.name, s);
      if (!ok) return;
    }
    setState(() {
      _importing = true;
      _status = s.connecting;
    });
    try {
      final importedPlaylist = await PlaylistService.instance.importM3U(
          url: url,
          name: name.isEmpty ? 'Playlist' : name,
          onProgress: (p, c) {
            if (mounted) setState(() => _status = _pt(p, c));
          });
      
      _m3uUrl.clear();
      _m3uName.clear();
      await state.refresh();
      
      if (mounted) {
        _showActivationDialog(importedPlaylist, s, state);
      }
    } catch (e) {
      _showErrorDialog(e.toString(), s);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importXtream() async {
    final state = context.read<AppState>();
    final s = state.s;
    final srv = _xtSrv.text.trim();
    final usr = _xtUser.text.trim();
    final pas = _xtPass.text.trim();
    final nm = _xtName.text.trim();

    if (srv.isEmpty || usr.isEmpty || pas.isEmpty) {
      _snack(s.fillAllFields, error: true);
      return;
    }
    setState(() {
      _importing = true;
      _status = s.validating;
    });
    try {
      final importedPlaylist = await PlaylistService.instance.importXtream(
          server: srv,
          username: usr,
          password: pas,
          name: nm.isEmpty ? usr : nm,
          onProgress: (p, c) {
            if (mounted) setState(() => _status = _pt(p, c));
          });
      
      _xtSrv.clear();
      _xtUser.clear();
      _xtPass.clear();
      _xtName.clear();
      await state.refresh();
      
      if (mounted) {
        _showActivationDialog(importedPlaylist, s, state);
      }
    } catch (e) {
      _showErrorDialog(e.toString(), s);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _pickFile() async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AladinFolderExplorer()),
    );

    if (path != null && mounted) {
      setState(() {
        _localPath = path;
        if (_locName.text.isEmpty) {
          _locName.text = path.split('/').last.replaceAll(RegExp(r'\.\w+$'), '');
        }
      });
    }
  }

  Future<void> _importLocal() async {
    final state = context.read<AppState>();
    final s = state.s;

    if (_localPath == null) {
      _snack(s.selectAFile, error: true);
      return;
    }
    setState(() {
      _importing = true;
      _status = s.reading;
    });
    try {
      final importedPlaylist = await PlaylistService.instance.importM3U(
          url: _localPath!,
          name: _locName.text.isEmpty ? s.local : _locName.text,
          isLocalFile: true,
          onProgress: (p, c) {
            if (mounted) setState(() => _status = _pt(p, c));
          });
      _locName.clear();
      setState(() => _localPath = null);
      await state.refresh();
      
      if (mounted) {
        _showActivationDialog(importedPlaylist, s, state);
      }
    } catch (e) {
      _showErrorDialog(e.toString(), s);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showErrorDialog(String error, AppStrings s) {
    String message = s.errorUrlMsg;
    if (error.contains('HandshakeException') || error.contains('WRONG_VERSION_NUMBER')) {
      message = "Bağlantı Kurulamadı! Sunucu güvenli bağlantıyı (HTTPS) desteklemiyor olabilir.\n\nLütfen adresin başındaki 'https://' kısmını 'http://' yaparak tekrar deneyin.";
    } else if (error.contains('SocketException')) {
      message = "İnternet Bağlantı Hatası!\n\nLütfen cihazınızın internete bağlı olduğundan emin olun.";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(s.errorUrlTitle, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          _TVDialogButton(
            label: 'Tamam',
            isPrimary: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showActivationDialog(PlaylistModel p, AppStrings s, AppState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.accent),
            const SizedBox(width: 10),
            Text(s.playlistLoadedTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(s.playlistLoadedMsg, style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          _TVDialogButton(label: s.cancel, isPrimary: false, onPressed: () => Navigator.pop(context)),
          _TVDialogButton(
            label: s.activateNow,
            isPrimary: true,
            onPressed: () {
              Navigator.pop(context);
              state.selectPlaylist(p);
              Future.delayed(const Duration(milliseconds: 300), () {
                widget.onPlaylistSelected?.call();
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _forceEpgSync() async {
    setState(() {
      _epgSyncing = true;
      _status = 'EPG senkronizasyonu başlatılıyor...';
    });
    
    _snack('EPG senkronizasyonu arka planda başlatıldı.');

    try {
      await AladinEpgEngine.instance.forceSync();
    } catch (e) {
      debugPrint('EPG Sync Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _epgSyncing = false;
          _status = '';
        });
        final s = context.read<AppState>().s;
        _snack('${s.epgUpdated} (${AladinEpgEngine.instance.syncStatus})');
      }
    }
  }

  Future<bool> _confirmUpdate(String name, AppStrings s) async =>
      await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.card,
                  title: Text(s.playlistExists, style: const TextStyle(color: AppTheme.textPrimary)),
                  content: Text('"$name" ${s.playlistExistsQ}', style: const TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    _TVDialogButton(label: s.cancel, isPrimary: false, onPressed: () => Navigator.pop(context, false)),
                    _TVDialogButton(label: s.update, isPrimary: true, onPressed: () => Navigator.pop(context, true)),
                  ])) ?? false;

  Future<void> _delete(PlaylistModel p) async {
    final state = context.read<AppState>();
    final s = state.s;
    final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                    backgroundColor: AppTheme.card,
                    title: Text(s.delete, style: const TextStyle(color: AppTheme.textPrimary)),
                    content: Text('"${p.name}" ${s.playlistDeleteQ}', style: const TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      _TVDialogButton(label: s.cancel, isPrimary: false, onPressed: () => Navigator.pop(context, false)),
                      _TVDialogButton(label: s.delete, isPrimary: true, isDanger: true, onPressed: () => Navigator.pop(context, true)),
                    ])) ?? false;
    if (ok) {
      await PlaylistService.instance.delete(p.id);
      await context.read<AppState>().refresh();
    }
  }

  Future<void> _rename(PlaylistModel p) async {
    final state = context.read<AppState>();
    final s = state.s;
    final ctrl = TextEditingController(text: p.name);
    final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                    backgroundColor: AppTheme.card,
                    title: Text(s.playlistRename, style: const TextStyle(color: AppTheme.textPrimary)),
                    content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(labelText: s.newName)),
                    actions: [
                      _TVDialogButton(label: s.cancel, isPrimary: false, onPressed: () => Navigator.pop(context, false)),
                      _TVDialogButton(label: s.save, isPrimary: true, onPressed: () => Navigator.pop(context, true)),
                    ])) ?? false;
    if (ok && ctrl.text.trim().isNotEmpty) {
      await PlaylistService.instance.rename(p.id, ctrl.text.trim());
      await context.read<AppState>().refresh();
    }
  }

  Future<void> _update(PlaylistModel p) async {
    final state = context.read<AppState>();
    final s = state.s;
    setState(() {
      _importing = true;
      _status = '${p.name} ${s.updating}...';
    });
    try {
      if (p.type == 'xtream') {
        await PlaylistService.instance.importXtream(
            server: p.xtreamServer!,
            username: p.xtreamUsername!,
            password: p.xtreamPassword!,
            name: p.name,
            onProgress: (_, c) {
              if (mounted) setState(() => _status = _pt(_, c));
            });
      } else {
        await PlaylistService.instance.importM3U(
            url: p.url,
            name: p.name,
            isLocalFile: p.type == 'local',
            onProgress: (_, c) {
              if (mounted) setState(() => _status = _pt(_, c));
            });
      }
      await context.read<AppState>().refresh();
      _snack('✅ ${p.name} ${s.updated}');
    } catch (e) {
      _snack('❌ $e', error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FocusScope(
        child: landscape ? _landscape(state, s) : _portrait(state, s),
      ),
    );
  }

  Widget _landscape(AppState state, AppStrings s) => Row(children: [
        Expanded(
            flex: 5,
            child: Column(children: [
              _tabBar(s),
              Expanded(
                child: TabBarView(controller: _tabs, children: [
                  _m3uForm(state, s),
                  _xtForm(state, s),
                  _locForm(state, s)
                ]),
              ),
              if (_status.isNotEmpty) _statusRow(),
              const SizedBox(height: 10),
            ])),
        const VerticalDivider(width: 1, color: AppTheme.divider),
        Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(s.savedPlaylists, style: AppTheme.headingMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(child: _playlistList(state, s)),
        ])),
      ]);

  Widget _portrait(AppState state, AppStrings s) => Column(children: [
        _tabBar(s),
        Expanded(
          flex: 0,
          child: SizedBox(
            height: 350,
            child: TabBarView(controller: _tabs, children: [
              _m3uForm(state, s),
              _xtForm(state, s),
              _locForm(state, s)
            ]),
          ),
        ),
        if (_status.isNotEmpty) _statusRow(),
        const Divider(height: 20),
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(s.savedPlaylists, style: AppTheme.headingMedium))),
        Expanded(child: _playlistList(state, s)),
      ]);

  Widget _tabBar(AppStrings s) => Container(
        margin: const EdgeInsets.fromLTRB(14, 20, 14, 10),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(12)),
        child: TabBar(
            controller: _tabs,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textMuted,
            indicator: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(10)),
            indicatorPadding: const EdgeInsets.all(4),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: s.tabM3U),
              Tab(text: s.tabXtream),
              Tab(text: s.tabLocal),
            ]),
      );

  Widget _statusRow() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        if (_importing) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
        if (_importing) const SizedBox(width: 10),
        Expanded(child: Text(_status, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
      ]));

  Widget _langRow(AppState state, AppStrings s) {
    final langs = AppStrings.getLanguageNames();
    return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: _TVFocusWrapper(
          onTap: () => _showLanguageDialog(state, s, langs),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.language, size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(child: Text(s.langTitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
              Text(
                langs[state.lang] ?? state.lang,
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.edit, size: 14, color: AppTheme.accent),
            ]),
          ),
        ));
  }

  void _showLanguageDialog(AppState state, AppStrings s, Map<String, String> langs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(s.langTitle, style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: langs.entries.map((e) => _TVFocusWrapper(
              onTap: () {
                state.setLang(e.key);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(e.value, style: const TextStyle(color: Colors.white)),
                    const Spacer(),
                    if (state.lang == e.key) const Icon(Icons.check, color: AppTheme.accent),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
        actions: [
          _TVDialogButton(label: s.close, isPrimary: true, onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _epgRow(AppState state, AppStrings s) {
    final days = AladinEpgEngine.instance.daysSinceSync;
    final label = days >= 999 ? s.epgNeverSynced : s.epgLastSync(days);
    return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
            _TVButton(
              focusNode: _fnEpgBtn,
              onPressed: _epgSyncing ? null : _forceEpgSync,
              icon: _epgSyncing ? null : Icons.sync,
              label: _epgSyncing ? s.epgSyncing : s.epgUpdate,
              isLoading: _epgSyncing,
              small: true,
            ),
          ]),
        ));
  }

  Widget _aboutRow(AppState state, AppStrings s) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: _TVFocusWrapper(
          onTap: () => _showAboutDialog(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(child: Text(s.about, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
              const Icon(Icons.chevron_right, size: 14, color: AppTheme.accent),
            ]),
          ),
        ));
  }

  void _showAboutDialog(AppStrings s) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.about, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('aladinIPTV Player Pro', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Version 2.2.0', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            Text(s.developer, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 8),
            _TVFocusWrapper(
              onTap: () => url_launcher.launchUrl(Uri.parse('https://github.com/tezalaaddin')),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('https://github.com/tezalaaddin', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 13)),
              ),
            ),
          ],
        ),
        actions: [
          _TVDialogButton(label: s.close, isPrimary: true, onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _playlistList(AppState state, AppStrings s) {
    if (state.playlists.isEmpty) {
      return Center(child: Text(s.noPlaylistsAdded, style: const TextStyle(color: AppTheme.textMuted)));
    }
    return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: state.playlists.length,
        itemBuilder: (_, i) {
          final p = state.playlists[i];
          return _PTile(
            p: p,
            active: state.active?.id == p.id,
            onSelect: () {
              state.selectPlaylist(p);
              _snack('✅ "${p.name}" ${s.playlistSelected}');
              Future.delayed(const Duration(milliseconds: 600), () => widget.onPlaylistSelected?.call());
            },
            onUpdate: () => _update(p),
            onRename: () => _rename(p),
            onDelete: () => _delete(p),
          );
        });
  }

  Widget _m3uForm(AppState state, AppStrings s) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: Column(children: [
      _TVTextField(
        controller: _m3uUrl,
        focusNode: _fnM3uUrl,
        autofocus: true, // Açılışta ilk alan odaklı gelsin
        label: 'M3U URL',
        hint: 'http://...',
        action: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_fnM3uName),
      ),
      const SizedBox(height: 12),
      _TVTextField(
        controller: _m3uName,
        focusNode: _fnM3uName,
        label: s.playlistName,
        action: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_fnM3uBtn),
      ),
      const SizedBox(height: 20),
      _TVButton(
        focusNode: _fnM3uBtn,
        onPressed: _importing ? null : _importM3U,
        icon: Icons.download,
        label: s.load,
        isLoading: _importing,
      ),
      const SizedBox(height: 24),
      const Divider(color: AppTheme.divider),
      const SizedBox(height: 12),
      _langRow(state, s),
      _epgRow(state, s),
      _aboutRow(state, s),
    ]),
  );

  Widget _xtForm(AppState state, AppStrings s) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: Column(children: [
      _TVTextField(
        controller: _xtSrv,
        focusNode: _fnXtSrv,
        label: s.server,
        hint: 'http://...',
        action: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_fnXtUser),
      ),
      const SizedBox(height: 10),
      _TVTextField(
        controller: _xtUser,
        focusNode: _fnXtUser,
        label: s.username,
        action: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_fnXtPass),
      ),
      const SizedBox(height: 10),
      _TVTextField(
        controller: _xtPass,
        focusNode: _fnXtPass,
        label: s.password,
        obscure: true,
        action: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_fnXtName),
      ),
      const SizedBox(height: 10),
      _TVTextField(
        controller: _xtName,
        focusNode: _fnXtName,
        label: s.playlistName,
        action: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_fnXtBtn),
      ),
      const SizedBox(height: 20),
      _TVButton(
        focusNode: _fnXtBtn,
        onPressed: _importing ? null : _importXtream,
        icon: Icons.cloud_download,
        label: s.connect,
        isLoading: _importing,
      ),
      const SizedBox(height: 24),
      const Divider(color: AppTheme.divider),
      const SizedBox(height: 12),
      _langRow(state, s),
      _epgRow(state, s),
      _aboutRow(state, s),
    ]),
  );

  Widget _locForm(AppState state, AppStrings s) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    child: Column(children: [
      _TVFocusWrapper(
        onTap: _pickFile,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.folder_open, color: AppTheme.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(_localPath ?? s.selectM3UFile, style: TextStyle(color: _localPath != null ? Colors.white : AppTheme.textMuted, fontSize: 14), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _TVTextField(
        controller: _locName,
        focusNode: _fnLocName,
        label: s.playlistName,
        action: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).requestFocus(_fnLocBtn),
      ),
      const SizedBox(height: 20),
      _TVButton(
        focusNode: _fnLocBtn,
        onPressed: _importing ? null : _importLocal,
        icon: Icons.upload_file,
        label: s.import,
        isLoading: _importing,
      ),
      const SizedBox(height: 24),
      const Divider(color: AppTheme.divider),
      const SizedBox(height: 12),
      _langRow(state, s),
      _epgRow(state, s),
      _aboutRow(state, s),
    ]),
  );
}

// ── TV UI Components ─────────────────────────────────────────────────────────

class _TVDialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDanger;

  const _TVDialogButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDanger = false,
  });

  @override
  State<_TVDialogButton> createState() => _TVDialogButtonState();
}

class _TVDialogButtonState extends State<_TVDialogButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.isPrimary, // Onay butonu otomatik odaklanacak
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _focused 
              ? (widget.isDanger ? Colors.redAccent : AppTheme.accent) 
              : (widget.isPrimary ? AppTheme.card : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _focused ? Colors.white : (widget.isPrimary ? AppTheme.accent : Colors.transparent),
            width: 2,
          ),
          boxShadow: _focused ? [BoxShadow(color: (widget.isDanger ? Colors.red : AppTheme.accent).withValues(alpha:0.4), blurRadius: 10)] : null,
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _focused ? Colors.white : (widget.isDanger ? Colors.redAccent : (widget.isPrimary ? AppTheme.accent : AppTheme.textMuted)),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _TVFocusWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _TVFocusWrapper({required this.child, this.onTap});

  @override
  State<_TVFocusWrapper> createState() => _TVFocusWrapperState();
}

class _TVFocusWrapperState extends State<_TVFocusWrapper> {
  bool _isFocused = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _isFocused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _isFocused ? AppTheme.accent : Colors.transparent, width: 3),
            boxShadow: _isFocused ? [BoxShadow(color: AppTheme.accent.withValues(alpha:0.3), blurRadius: 10)] : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _TVTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final bool obscure;
  final bool autofocus;
  final TextInputAction action;
  final ValueChanged<String>? onSubmitted;

  const _TVTextField({
    required this.controller,
    this.focusNode,
    required this.label,
    this.hint,
    this.obscure = false,
    this.autofocus = false,
    required this.action,
    this.onSubmitted,
  });

  @override
  State<_TVTextField> createState() => _TVTextFieldState();
}

class _TVTextFieldState extends State<_TVTextField> {
  late FocusNode _internalNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _internalNode = widget.focusNode ?? FocusNode();
    _internalNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _internalNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _internalNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _internalNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // TV OK / ENTER -> Aktif et ve klavyeyi aç
          if (event.logicalKey == LogicalKeyboardKey.select || 
              event.logicalKey == LogicalKeyboardKey.enter) {
            _internalNode.requestFocus();
            return KeyEventResult.ignored; // TextField'ın kendi işlemesine izin ver
          }
          // YUKARI / AŞAĞI -> Text alanından çıkış yap
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            FocusScope.of(context).focusInDirection(TraversalDirection.up);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            FocusScope.of(context).focusInDirection(TraversalDirection.down);
            return KeyEventResult.handled;
          }
          // GERİ -> Odağı bırak ve klavyeyi kapat
          if (event.logicalKey == LogicalKeyboardKey.backspace || 
              event.logicalKey == LogicalKeyboardKey.escape) {
            _internalNode.unfocus();
            SystemChannels.textInput.invokeMethod('TextInput.hide');
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _isFocused ? AppTheme.accent : Colors.transparent, width: 3),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _internalNode,
          autofocus: widget.autofocus,
          obscureText: widget.obscure,
          textInputAction: widget.action,
          onSubmitted: (val) {
            widget.onSubmitted?.call(val);
          },
          scrollPadding: const EdgeInsets.only(bottom: 150),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            filled: true,
            fillColor: AppTheme.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }
}

class _TVButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final IconData? icon;
  final String label;
  final bool isLoading;
  final bool small;

  const _TVButton({
    required this.onPressed,
    this.focusNode,
    this.icon,
    required this.label,
    this.isLoading = false,
    this.small = false,
  });

  @override
  State<_TVButton> createState() => _TVButtonState();
}

class _TVButtonState extends State<_TVButton> {
  bool _isFocused = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _isFocused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: widget.small ? 16 : 24, vertical: widget.small ? 8 : 14),
          decoration: BoxDecoration(
            color: _isFocused ? AppTheme.accent : AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _isFocused ? Colors.white : Colors.transparent, width: 2),
            boxShadow: _isFocused ? [BoxShadow(color: AppTheme.accent.withValues(alpha:0.4), blurRadius: 10)] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else if (widget.icon != null)
                Icon(widget.icon, size: widget.small ? 16 : 20, color: Colors.white),
              if (widget.icon != null || widget.isLoading) const SizedBox(width: 10),
              Text(widget.label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: widget.small ? 13 : 15)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _PTile ────────────────────────────────────────────────────────────────────

class _PTile extends StatefulWidget {
  final PlaylistModel p;
  final bool active;
  final VoidCallback onSelect, onUpdate, onRename, onDelete;
  const _PTile({required this.p, required this.active, required this.onSelect, required this.onUpdate, required this.onRename, required this.onDelete});

  @override
  State<_PTile> createState() => _PTileState();
}

class _PTileState extends State<_PTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Focus(
        onFocusChange: (v) => setState(() => _isFocused = v),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
              widget.p.totalCount > 0 ? widget.onSelect() : _promptImport(context, s, state);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.contextMenu || event.logicalKey == LogicalKeyboardKey.f10) {
              _showOptions(context, s);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => widget.p.totalCount > 0 ? widget.onSelect() : _promptImport(context, s, state),
          onLongPress: () => _showOptions(context, s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isFocused ? AppTheme.accent : (widget.active ? AppTheme.accent.withValues(alpha:0.5) : Colors.transparent), width: 3),
              boxShadow: _isFocused ? [BoxShadow(color: AppTheme.accent.withValues(alpha:0.2), blurRadius: 8)] : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: widget.active ? AppTheme.accent : AppTheme.surface,
                        child: Icon(_icon(), color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.p.name, 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            widget.p.totalCount > 0
                                ? Text('${widget.p.totalCount} ${s.channelsShort}  📺 ${widget.p.tvCount}  🎬 ${widget.p.movieCount}', 
                                    style: AppTheme.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(s.demoDownloadHint, 
                                    style: AppTheme.caption.copyWith(color: AppTheme.accent, fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: AppTheme.divider),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TileBtn(icon: Icons.refresh, label: s.update, color: AppTheme.textMuted, onTap: widget.onUpdate),
                      _TileBtn(icon: Icons.edit, label: s.playlistRename, color: AppTheme.textMuted, onTap: widget.onRename),
                      _TileBtn(icon: Icons.delete, label: s.delete, color: Colors.redAccent.withValues(alpha: 0.8), onTap: widget.onDelete),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext ctx, AppStrings s) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.refresh, color: AppTheme.textPrimary),
              title: Text(s.update, style: const TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); widget.onUpdate(); },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.textPrimary),
              title: Text(s.playlistRename, style: const TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); widget.onRename(); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: Text(s.delete, style: const TextStyle(color: Colors.redAccent)),
              onTap: () { Navigator.pop(ctx); widget.onDelete(); },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _promptImport(BuildContext ctx, AppStrings s, AppState state) =>
      showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.card,
                  title: Text(widget.p.name, style: const TextStyle(color: Colors.white)),
                  content: Text(s.demoDownloadPrompt, style: const TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    _TVDialogButton(label: s.cancel, isPrimary: false, onPressed: () => Navigator.pop(ctx)),
                    _TVDialogButton(label: s.download, isPrimary: true, onPressed: () { Navigator.pop(ctx); widget.onUpdate(); }),
                  ]));

  IconData _icon() => widget.p.type == 'xtream' ? Icons.cloud : widget.p.type == 'local' ? Icons.folder : Icons.link;
}

class _TileBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TileBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _MI extends StatelessWidget {
  final IconData i;
  final String l;
  final bool red;
  const _MI(this.i, this.l, {this.red = false});
  @override
  Widget build(BuildContext c) => Row(children: [
        Icon(i, color: red ? AppTheme.accent : AppTheme.textPrimary, size: 18),
        const SizedBox(width: 10),
        Text(l, style: TextStyle(color: red ? AppTheme.accent : AppTheme.textPrimary)),
      ]);
}
