import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    if (details.exception.toString().contains('blur radius')) {
      return const SizedBox.shrink();
    }
    if (kReleaseMode) {
      debugPrint('Flutter Error: ${details.exception}');
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
    // ⚡ PERFORMANS: Başlangıç işlemlerini paralel çalıştırarak açılış hızını artır
    await Future.wait([
      AladinPrefs.instance.load(),
      IsarService.instance.init(),
      AppState.instance.init(),
    ]);
    
    await AppState.instance.loadPlaylists();

    final hasLang = AladinPrefs.instance.getString('lang') != null;
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 1000));
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
                    'Aladin Media Player Pro',
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF000000),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Süsleme amaçlı arka plan deseni (opsiyonel)
            Positioned(
              right: -100,
              top: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: 0.05),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Premium Logo Alanı
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.live_tv, color: AppTheme.accent, size: 84),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Aladin Media Player Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Text(
                      'PREMIUM SMART TV EXPERIENCE',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3.0,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Select Language / Dil Seçiniz',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Buton Izgarası
                    SizedBox(
                      width: 800, // TV genişliği için sınırla
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: langs.entries.map((e) {
                          final parts = e.value.split(' ');
                          final flag = parts[0];
                          final label = parts.skip(1).join(' ');
                          
                          return _LangBtn(
                            flag: flag,
                            label: label,
                            autofocus: e.key == 'en', // Kullanıcının isteği: İngilizce başta ve odaklı
                            onTap: () => onSelect(e.key),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangBtn extends StatefulWidget {
  final String flag, label;
  final VoidCallback onTap;
  final bool autofocus;

  const _LangBtn({
    required this.flag,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_LangBtn> createState() => _LangBtnState();
}

class _LangBtnState extends State<_LangBtn> with SingleTickerProviderStateMixin {
  bool _focused = false;
  late AnimationController _scaleCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onFocus(bool v) {
    setState(() => _focused = v);
    if (v) {
      _scaleCtrl.forward();
    } else {
      _scaleCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _onFocus,
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
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 240, // Biraz daha daraltıp yan yana daha çok sığdıralım
            height: 72,
            decoration: BoxDecoration(
              color: _focused ? Colors.white : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focused ? Colors.white : Colors.white24,
                width: _focused ? 0 : 1,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.flag,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 14),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: _focused ? Colors.black : Colors.white,
                    fontSize: 18,
                    fontWeight: _focused ? FontWeight.w800 : FontWeight.w600,
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
