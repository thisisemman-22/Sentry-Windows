import 'dart:async';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/motion/motion.dart';
import '../core/network/api_envelope.dart';
import '../core/theme/sentry_colors.dart';
import '../core/theme/sentry_theme.dart';
import '../core/widgets/sentry_interactive_logo.dart';
import '../core/widgets/ui/sentry_ui.dart';
import '../shared/models/auth_models.dart';
import 'demo_controls_sheet.dart';
import 'providers.dart';
import 'router.dart';

/// Whether the sidebar is collapsed to an icon rail.
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Authenticated desktop shell.
///
/// Layout: calm sidebar (navigation only) + slim top bar (connection status,
/// clock, demo tools) + routed page with a shared-axis transition.
///
/// Keyboard:
/// - `Ctrl+1…7` jump to a page
/// - `Ctrl+B` collapse / expand the sidebar
/// - `Ctrl+Shift+L` toggle light / dark
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  DesktopNavTab _previousTab = DesktopNavTab.overview;

  void _go(DesktopNavTab tab) {
    _previousTab = ref.read(selectedDesktopTabProvider);
    ref.read(selectedDesktopTabProvider.notifier).state = tab;
  }

  void _toggleTheme() {
    final mode = ref.read(themeModeProvider);
    ref.read(themeModeProvider.notifier).state =
        mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final activeTab = ref.watch(selectedDesktopTabProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);

    // Surface simulator / action feedback as a toast instead of a banner strip.
    ref.listen(sentryScenarioProvider.select((s) => s.lastActionBanner),
        (prev, next) {
      if (next != null && next != prev) {
        final lower = next.toLowerCase();
        final tone = lower.contains('denied') ||
                lower.contains('error') ||
                lower.contains('expired') ||
                lower.contains('conflict')
            ? PillTone.warn
            : PillTone.ok;
        showSentryToast(context, next, tone: tone);
      }
    });

    final shortcuts = <ShortcutActivator, VoidCallback>{
      for (var i = 0; i < DesktopNavTab.values.length; i++)
        SingleActivator(
          LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
          control: true,
        ): () => _go(DesktopNavTab.values[i]),
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
          ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
      const SingleActivator(LogicalKeyboardKey.keyL,
          control: true, shift: true): _toggleTheme,
    };

    final forward = activeTab.index >= _previousTab.index;
    final isMobile = MediaQuery.sizeOf(context).width < 760;

    final pageSwitcher = PageTransitionSwitcher(
      duration: SentryMotion.of(context, const Duration(milliseconds: 520)),
      reverse: !forward,
      transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
        animation: primary,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.vertical,
        fillColor: p.bg,
        child: child,
      ),
      child: KeyedSubtree(
        key: ValueKey(activeTab),
        child: DesktopViewRouter(tab: activeTab),
      ),
    );

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: p.bg,
          drawer: isMobile
              ? Drawer(
                  width: 272,
                  backgroundColor: p.card,
                  child: SafeArea(
                    child: _Sidebar(
                      collapsed: false,
                      activeTab: activeTab,
                      onSelect: (tab) {
                        Navigator.of(context).maybePop();
                        _go(tab);
                      },
                    ),
                  ),
                )
              : null,
          bottomNavigationBar: isMobile
              ? NavigationBar(
                  backgroundColor: p.card,
                  selectedIndex: activeTab.index.clamp(0, 4),
                  onDestinationSelected: (idx) =>
                      _go(DesktopNavTab.values[idx]),
                  destinations: [
                    for (final t in DesktopNavTab.values.take(5))
                      NavigationDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.selectedIcon),
                        label: t.title,
                      ),
                  ],
                )
              : null,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isMobile)
                  _Sidebar(
                    collapsed: collapsed,
                    activeTab: activeTab,
                    onSelect: _go,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        onToggleTheme: _toggleTheme,
                        isMobile: isMobile,
                      ),
                      Expanded(child: pageSwitcher),
                    ],
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

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends ConsumerWidget {
  final bool collapsed;
  final DesktopNavTab activeTab;
  final ValueChanged<DesktopNavTab> onSelect;

  const _Sidebar({
    required this.collapsed,
    required this.activeTab,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final kpis = ref.watch(
        sentryScenarioProvider.select((s) => s.computeDashboardKpis()));
    final profile = ref.watch(authControllerProvider).profile!;
    final width = collapsed ? 88.0 : 256.0;

    return AnimatedContainer(
      duration: SentryMotion.of(context, SentryMotion.medium),
      curve: SentryMotion.emphasized,
      width: width,
      decoration: BoxDecoration(
        color: p.card,
        border: Border(right: BorderSide(color: p.line)),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: width,
          maxWidth: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand
              Padding(
                padding: EdgeInsets.fromLTRB(collapsed ? 24 : 22, 22, 14, 22),
                child: Row(
                  children: [
                    const SentryInteractiveLogo(size: 40),
                    if (!collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: const [
                                  TextSpan(text: 'SENT'),
                                  TextSpan(
                                    text: 'RY',
                                    style:
                                        TextStyle(color: SentryColors.crimson),
                                  ),
                                ],
                                style: SentryTheme.display(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: p.text,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Alangilan Campus',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Navigation
              Expanded(
                child: FocusTraversalGroup(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (final tab in DesktopNavTab.values)
                        _NavItem(
                          key: Key('nav_tab_${tab.name}'),
                          tab: tab,
                          selected: tab == activeTab,
                          collapsed: collapsed,
                          locked: tab == DesktopNavTab.administration &&
                              !profile.role.isAdmin,
                          badge: switch (tab) {
                            DesktopNavTab.liveGateMonitoring =>
                              kpis.activeHoldsAwaitingPassageCount,
                            DesktopNavTab.guardReviews =>
                              kpis.pendingGuardReviewsCount,
                            _ => 0,
                          },
                          badgeTone: tab == DesktopNavTab.guardReviews
                              ? PillTone.err
                              : PillTone.warn,
                          onTap: () => onSelect(tab),
                        ),
                    ],
                  ),
                ),
              ),

              // Collapse toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Align(
                  alignment:
                      collapsed ? Alignment.center : Alignment.centerLeft,
                  child: IconButton(
                    tooltip: collapsed
                        ? 'Expand sidebar (Ctrl+B)'
                        : 'Collapse sidebar (Ctrl+B)',
                    onPressed: () => ref
                        .read(sidebarCollapsedProvider.notifier)
                        .state = !collapsed,
                    icon: AnimatedRotation(
                      turns: collapsed ? 0.5 : 0,
                      duration: SentryMotion.of(context, SentryMotion.medium),
                      curve: SentryMotion.emphasized,
                      child: const Icon(Icons.keyboard_double_arrow_left_rounded),
                    ),
                  ),
                ),
              ),

              // Operator
              _OperatorChip(profile: profile, collapsed: collapsed),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final DesktopNavTab tab;
  final bool selected;
  final bool collapsed;
  final bool locked;
  final int badge;
  final PillTone badgeTone;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.tab,
    required this.selected,
    required this.collapsed,
    required this.locked,
    required this.badge,
    required this.badgeTone,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final sel = widget.selected;
    final fg = sel ? Colors.white : (_hover ? p.text : p.slate);
    final shortcut = 'Ctrl+${widget.tab.index + 1}';
    final t = ToneColors.of(context, widget.badgeTone);

    final badge = widget.badge > 0
        ? AnimatedContainer(
            duration: SentryMotion.of(context, SentryMotion.short),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            constraints: const BoxConstraints(minWidth: 24),
            decoration: BoxDecoration(
              color: sel ? Colors.white : t.solid,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${widget.badge}',
              textAlign: TextAlign.center,
              style: SentryTheme.mono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? SentryColors.crimson : Colors.white,
              ),
            ),
          )
        : null;

    final item = Semantics(
      button: true,
      selected: sel,
      label:
          '${widget.tab.title}${widget.badge > 0 ? ', ${widget.badge} need attention' : ''}${widget.locked ? ', administrators only' : ''}',
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            focusColor: p.crimson.withValues(alpha: 0.14),
            child: AnimatedContainer(
              duration: SentryMotion.of(context, SentryMotion.short),
              curve: SentryMotion.emphasized,
              height: 48,
              padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : 14),
              decoration: BoxDecoration(
                color: sel
                    ? SentryColors.crimson
                    : (_hover ? p.subtle : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: SentryColors.crimson.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          spreadRadius: -8,
                        ),
                      ]
                    : null,
              ),
              child: widget.collapsed
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                            sel ? widget.tab.selectedIcon : widget.tab.icon,
                            size: 22,
                            color: fg),
                        if (widget.badge > 0)
                          Positioned(
                            top: 8,
                            right: 12,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: sel ? Colors.white : t.solid,
                                shape: BoxShape.circle,
                                border: Border.all(color: p.card, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                            sel ? widget.tab.selectedIcon : widget.tab.icon,
                            size: 21,
                            color: fg),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.tab.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w600,
                              color: fg,
                            ),
                          ),
                        ),
                        if (widget.locked)
                          Icon(Icons.lock_outline_rounded,
                              size: 16, color: fg.withValues(alpha: 0.7)),
                        if (badge != null) badge,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: widget.collapsed
            ? '${widget.tab.title}  ·  $shortcut'
            : shortcut,
        waitDuration: const Duration(milliseconds: 700),
        preferBelow: false,
        child: item,
      ),
    );
  }
}

class _OperatorChip extends ConsumerWidget {
  final ProfileDto profile;
  final bool collapsed;
  const _OperatorChip({required this.profile, required this.collapsed});

  String get _initials {
    final parts = profile.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last =
        parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final isAdmin = profile.role.isAdmin;

    final avatar = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isAdmin ? p.text : SentryColors.crimson,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: SentryTheme.display(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: isAdmin ? p.card : Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      child: MenuAnchor(
        alignmentOffset: const Offset(0, -8),
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        ),
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
        builder: (context, controller, _) => Tooltip(
          message: collapsed ? '${profile.fullName} · ${_roleLabel()}' : '',
          child: Material(
            color: p.subtle,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: Padding(
                padding: EdgeInsets.all(collapsed ? 12 : 10),
                child: collapsed
                    ? Center(child: avatar)
                    : Row(
                        children: [
                          avatar,
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  _roleLabel(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.unfold_more_rounded,
                              size: 18, color: p.muted),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel() =>
      profile.role.isAdmin ? 'Administrator' : 'Guard · ${profile.assignedStation}';
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends ConsumerWidget {
  final VoidCallback onToggleTheme;
  final bool isMobile;
  const _TopBar({required this.onToggleTheme, this.isMobile = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final ws = ref.watch(sentryScenarioProvider.select((s) => s.wsState));
    final config = ref.watch(appConfigProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 28),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          if (isMobile) ...[
            Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Open navigation menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: _ConnectionStatus(
              healthy: ws.isHealthy,
              lastSyncUtc: isMobile ? null : ws.lastSyncedAtUtc,
              onResync: () => ref
                  .read(sentryScenarioProvider.notifier)
                  .forceFullSnapshotResync(),
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            const _ManilaClock(),
            const SizedBox(width: 10),
          ],
          if (config.isMock) ...[
            Tooltip(
              message: 'Run demo scenarios and switch roster or role',
              child: isMobile
                  ? IconButton(
                      key: const Key('open_demo_controls_button'),
                      onPressed: () => showDemoControlsSheet(context),
                      icon: const Icon(Icons.science_outlined),
                    )
                  : OutlinedButton.icon(
                      key: const Key('open_demo_controls_button'),
                      onPressed: () => showDemoControlsSheet(context),
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text('Demo tools'),
                    ),
            ),
            const SizedBox(width: 6),
          ],
          IconButton(
            key: const Key('sidebar_theme_toggle'),
            tooltip: themeMode == ThemeMode.dark
                ? 'Light mode (Ctrl+Shift+L)'
                : 'Dark mode (Ctrl+Shift+L)',
            onPressed: onToggleTheme,
            icon: AnimatedSwitcher(
              duration: SentryMotion.of(context, SentryMotion.medium),
              transitionBuilder: (c, a) => RotationTransition(
                turns: Tween(begin: 0.75, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: c),
              ),
              child: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                key: ValueKey(themeMode),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  final bool healthy;
  final DateTime? lastSyncUtc;
  final VoidCallback onResync;

  const _ConnectionStatus({
    required this.healthy,
    required this.lastSyncUtc,
    required this.onResync,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final color = healthy ? p.ok : p.warn;
    final text = healthy ? p.okText : p.warnText;

    return Semantics(
      liveRegion: true,
      label: healthy
          ? 'Live. Data is up to date.'
          : 'Data may be out of date. Resync available.',
      child: AnimatedContainer(
        duration: SentryMotion.of(context, SentryMotion.medium),
        curve: SentryMotion.emphasized,
        padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
        decoration: BoxDecoration(
          color: healthy ? p.okTint : p.warnTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseDot(color: color, pulsing: healthy),
            Text(
              healthy ? 'Live' : 'Out of date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
            if (lastSyncUtc != null) ...[
              const SizedBox(width: 8),
              Text(
                'synced ${ManilaTime.formatTimeOnly(lastSyncUtc)}',
                style: TextStyle(fontSize: 13, color: text.withValues(alpha: 0.8)),
              ),
            ],
            if (!healthy) ...[
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onResync,
                style: TextButton.styleFrom(
                  foregroundColor: text,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Resync'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Isolated clock so the per-second tick only rebuilds this tiny widget.
class _ManilaClock extends StatefulWidget {
  const _ManilaClock();

  @override
  State<_ManilaClock> createState() => _ManilaClockState();
}

class _ManilaClockState extends State<_ManilaClock> {
  Timer? _timer;
  DateTime _now = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    return Tooltip(
      message: 'Philippine Standard Time (Asia/Manila, UTC+8)',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: p.muted),
          const SizedBox(width: 8),
          Text(
            ManilaTime.formatDateTime(_now),
            style: SentryTheme.mono(fontSize: 13.5, color: p.slate),
          ),
        ],
      ),
    );
  }
}
