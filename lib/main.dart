import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'core/database/aladin_isar_service.dart';
import 'core/services/aladin_channel_service.dart';
import 'core/state/aladin_app_prefs.dart';
import 'core/state/aladin_app_state.dart';
import 'core/state/aladin_app_strings.dart';
import 'core/services/aladin_metadata_sync_service.dart';
import 'core/services/aladin_epg_engine.dart';
import 'features/aladin_main_page.dart';
import 'shared/theme/aladin_app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔧 TV UYUMLU: Üretim modunda shadow ve render hatalarını sustur
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kReleaseMode || details.exception.toString().contains('blur radius')) {
      return const SizedBox.shrink();
    }
    return ErrorWidget(details.exception);
  };
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  // 🎬 TV PERFORMANS: Image cache'i TV için optimize et
  PaintingBinding.instance.imageCache.maximumSize = 50; 
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB
  
  MediaKit.ensureInitialized();
  runApp(const AladinApp());
}

class AladinApp extends StatefulWidget {
  const AladinApp({super.key});
  @override
  State<AladinApp> createState() => _AladinAppState();
}

class _AladinAppState extends State<AladinApp>
    with SingleTickerProviderStateMixin {
  int _phase = 0; // 0=splash, 1=language, 2=main
  late AnimationController _animCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
    _setupNativeListener();
    _boot();
  }

  void _setupNativeListener() {
    const MethodChannel('aladin/exoplayer').setMethodCallHandler((call) async {
      if (call.method == 'onFavoriteToggled') {
        final url = call.arguments['url'] as String?;
        final isFavorite = call.arguments['isFavorite'] as bool?;
        if (url != null && isFavorite != null) {
          await ChannelService.instance.setFavoriteByUrl(url, isFavorite);
          AppState.instance.refreshFavorites();
        }
      } else if (call.method == 'onProgressUpdate') {
        final url = call.arguments['url'] as String?;
        final pos = call.arguments['position'] as int? ?? 0;
        final dur = call.arguments['duration'] as int? ?? 0;
        if (url != null) {
          await ChannelService.instance.updateProgressByUrl(
            url, 
            (pos / 1000).round(), 
            (dur / 1000).round(),
          );
        }
      }
      return null;
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await AladinPrefs.instance.load();
    await IsarService.instance.init();
    await AppState.instance.init();
    await AppState.instance.loadPlaylists();

    final hasLang = AladinPrefs.instance.getString('lang') != null;
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _phase = hasLang ? 2 : 1);
  }

  void _onLangSelected(String lang) async {
    await AppState.instance.setLang(lang);
    if (mounted) setState(() => _phase = 2);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AppState.instance),
        ChangeNotifierProvider.value(value: MetadataSyncService.instance),
        ChangeNotifierProvider.value(value: AladinEpgEngine.instance),
      ],
      child: MaterialApp(
        title: 'Aladin Media Player Pro TV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: switch (_phase) {
            1 => _LangSelect(onSelect: _onLangSelected),
            2 => const MainPage(),
            _ => _Splash(fade: _fade),
          },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  final Animation<double> fade;
  const _Splash({required this.fade});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.45),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.live_tv, color: Colors.white, size: 52),
              ),
              const SizedBox(height: 26),
              const Column(
                children: [
                  Text(
                    'aladinIPTV Player Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'FOR SMART TV',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangSelect extends StatelessWidget {
  final void Function(String) onSelect;
  const _LangSelect({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final langs = AppStrings.getLanguageNames();
    final flags = {
      'tr': '🇹🇷',
      'en': '🇬🇧',
      'de': '🇩🇪',
      'fr': '🇫🇷',
    };

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.live_tv, color: AppTheme.accent, size: 72),
              const SizedBox(height: 28),
              const Column(
                children: [
                  Text('aladinIPTV Player Pro',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(
                    'FOR SMART TV',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: langs.entries.map((e) => _LangBtn(
                  flag: flags[e.key] ?? '🌐', 
                  label: e.value, 
                  autofocus: e.key == 'tr', 
                  onTap: () => onSelect(e.key)
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangBtn extends StatefulWidget {
  final String flag, label;
  final VoidCallback onTap;
  final bool autofocus;

  const _LangBtn({required this.flag, required this.label, required this.onTap, this.autofocus = false});

  @override
  State<_LangBtn> createState() => _LangBtnState();
}

class _LangBtnState extends State<_LangBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
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
          width: 300,
          height: 60,
          decoration: BoxDecoration(
            color: _focused ? AppTheme.accent : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _focused ? Colors.white : AppTheme.divider, width: _focused ? 3 : 1),
            boxShadow: _focused ? [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.5),
                blurRadius: 8,
              )
            ] : [],
          ),
          transform: Matrix4.identity()..scale(_focused ? 1.05 : 1.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
