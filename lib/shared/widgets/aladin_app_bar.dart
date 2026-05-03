import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/aladin_app_state.dart';
import '../theme/aladin_app_theme.dart';

/// Simplified branded app bar — left: "aladinIPTV Player Pro" label, right: refresh
class AladinAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final VoidCallback? onRefresh;
  final List<Widget>? extraActions;
  final PreferredSizeWidget? bottom;

  const AladinAppBar({
    super.key, 
    this.title, 
    this.onRefresh, 
    this.extraActions,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(48 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) return const SizedBox.shrink();

    final s = context.read<AppState>().s;
    final double safePadding = MediaQuery.of(context).size.width * 0.05;

    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      automaticallyImplyLeading: false, // TV'de geri butonu genellikle kumanda ile yönetilir
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.symmetric(horizontal: safePadding),
        child: Row(
          children: [
            // Logo / Branding
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: AppTheme.accent, borderRadius: BorderRadius.circular(5)),
              child: Text(title ?? s.settingsTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ),
            const Spacer(),
            // Butonlar
            if (extraActions != null) ...extraActions!,
            if (onRefresh != null)
              _AppBarButton(
                icon: Icons.refresh,
                onPressed: onRefresh!,
              ),
          ],
        ),
      ),
      bottom: bottom ?? PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider)),
    );
  }
}

/// TV kumandası için odaklanabilir AppBar butonu
class _AppBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _AppBarButton({required this.icon, required this.onPressed});

  @override
  State<_AppBarButton> createState() => _AppBarButtonState();
}

class _AppBarButtonState extends State<_AppBarButton> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: IconButton(
        icon: Icon(widget.icon,
            color: _focused ? AppTheme.accent : AppTheme.textSecondary,
            size: 22),
        onPressed: widget.onPressed,
      ),
    );
  }
}
