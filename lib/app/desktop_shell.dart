import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/motion/motion.dart';
import '../core/network/api_envelope.dart';
import '../core/network/ws_client.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(appConfigProvider).isReal) {
        ref.read(sentryScenarioProvider.notifier).refreshRealSnapshot();
      }
    });
  }

  void _go(DesktopNavTab tab) {
    _previousTab = ref.read(selectedDesktopTabProvider);
    ref.read(selectedDesktopTabProvider.notifier).state = tab;
  }

  void _toggleTheme() {
    final mode = ref.read(themeModeProvider);
    ref.read(themeModeProvider.notifier).state =
        mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void _unlockDevMode() {
    ref.read(devModeUnlockedProvider.notifier).state = true;
    ref.read(sentryScenarioProvider.notifier).enableDeveloperMockMode();
    showSentryToast(context, 'Developer Test Mode Enabled', tone: PillTone.ok);
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
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
          showCommandPalette(context, ref),
      const SingleActivator(
        LogicalKeyboardKey.keyD,
        control: true,
        shift: true,
        alt: true,
      ): _unlockDevMode,
    };

    final forward = activeTab.index >= _previousTab.index;
    final isMobile = MediaQuery.sizeOf(context).width < 760;

    // Fast, calm view transition: 220ms fade + 1.5% horizontal slide.
    final pageSwitcher = AnimatedSwitcher(
      duration: SentryMotion.of(context, const Duration(milliseconds: 220)),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(forward ? 0.015 : -0.015, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, if (current != null) current],
      ),
      child: KeyedSubtree(
        key: ValueKey(activeTab),
        child: ColoredBox(
          color: p.bg,
          child: DesktopViewRouter(tab: activeTab),
        ),
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
    final authState = ref.watch(authControllerProvider);
    final profile = authState.profile;
    if (profile == null) return const SizedBox.shrink();
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
                    const SentryInteractiveLogo(size: 34),
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
                              'BATSTATEU TNEU · ALANGILAN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SentryTheme.eyebrow(color: p.muted)
                                  .copyWith(fontSize: 9.5),
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
                      for (final tab in DesktopNavTab.values) ...[
                        if (_sectionLabelFor(tab) != null)
                          _NavSectionLabel(
                            label: _sectionLabelFor(tab)!,
                            collapsed: collapsed,
                          ),
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

String? _sectionLabelFor(DesktopNavTab tab) => switch (tab) {
      DesktopNavTab.overview => 'OPERATIONS',
      DesktopNavTab.accessLogs => 'RECORDS & HARDWARE',
      DesktopNavTab.administration => 'SYSTEM',
      _ => null,
    };

class _NavSectionLabel extends StatelessWidget {
  final String label;
  final bool collapsed;
  const _NavSectionLabel({required this.label, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        child: Divider(height: 1, color: p.line),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 8, 8),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: SentryTheme.eyebrow(color: p.muted),
      ),
    );
  }
}

/// `Ctrl+K` command palette: jump to any view, a registered driver, or a plate.
Future<void> showCommandPalette(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _CommandPalette(parentRef: ref),
  );
}

class _CommandPalette extends ConsumerStatefulWidget {
  final WidgetRef parentRef;
  const _CommandPalette({required this.parentRef});

  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final sys = ref.watch(sentryScenarioProvider);
    final q = _q.trim().toUpperCase();
    final views = DesktopNavTab.values
        .where((t) => q.isEmpty || t.title.toUpperCase().contains(q))
        .toList();
    final people = q.isEmpty
        ? const []
        : sys.participantDirectory.where((u) {
            final plates = u.vehicles
                .map((v) => (v.plateNumberDisplay ?? '').toUpperCase())
                .join(' ');
            return u.userCode.contains(q) ||
                u.fullName.toUpperCase().contains(q) ||
                plates.contains(q) ||
                plates.replaceAll(' ', '').contains(q.replaceAll(' ', ''));
          }).take(6).toList();

    void go(DesktopNavTab tab) {
      ref.read(selectedDesktopTabProvider.notifier).state = tab;
      Navigator.of(context).pop();
    }

    return Dialog(
      alignment: const Alignment(0, -0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                key: const Key('command_palette_field'),
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  hintText: 'Jump to a view, driver, or license plate…',
                ),
                onChanged: (v) => setState(() => _q = v),
                onSubmitted: (_) {
                  if (views.isNotEmpty) go(views.first);
                },
              ),
            ),
            Divider(height: 1, color: p.line),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final t in views)
                    ListTile(
                      dense: true,
                      leading: Icon(t.icon, size: 20),
                      title: Text(t.title),
                      subtitle: Text(t.subtitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('Ctrl+${t.index + 1}',
                          style: SentryTheme.mono(fontSize: 12, color: p.muted)),
                      onTap: () => go(t),
                    ),
                  for (final u in people)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.badge_outlined, size: 20),
                      title: Text('${u.fullName} (${u.userCode})',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        u.vehicles
                            .map((v) => v.plateNumberDisplay ?? v.vehicleCode)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => go(DesktopNavTab.accessLogs),
                    ),
                  if (views.isEmpty && people.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No matches',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
            ),
          ],
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

  void _showAboutSentry(BuildContext context) {
    final p = SentryPalette.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.line),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SentryInteractiveLogo(size: 72),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(
                children: const [
                  TextSpan(text: 'SENT'),
                  TextSpan(
                    text: 'RY',
                    style: TextStyle(color: SentryColors.crimson),
                  ),
                ],
                style: SentryTheme.display(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'BatStateU TNEU · Alangilan Campus',
              style: SentryTheme.eyebrow(color: p.crimson),
            ),
            const SizedBox(height: 12),
            Text(
              'Smart Campus Access & Real-Time Parking Management System',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: p.slate,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: p.subtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.line),
              ),
              child: Text(
                'v1.0.0 · Production Release · RA 10173 Compliant',
                style: SentryTheme.mono(fontSize: 11.5, color: p.muted),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final isAdmin = profile.role.isAdmin;

    final avatar = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isAdmin ? p.text : SentryColors.crimson,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: SentryTheme.display(
          fontSize: 13,
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
            leadingIcon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showAboutSentry(context),
            child: const Text('About SENTRY'),
          ),
          const Divider(height: 8),
          MenuItemButton(
            leadingIcon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
        builder: (context, controller, _) => Tooltip(
          message: '${profile.fullName} · ${_roleLabel()}',
          child: Material(
            color: p.subtle,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 8 : 10,
                  vertical: collapsed ? 10 : 8,
                ),
                child: collapsed
                    ? Center(child: avatar)
                    : Row(
                        children: [
                          avatar,
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  profile.fullName,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  _roleLabel(),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
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
    final wide = MediaQuery.sizeOf(context).width >= 1180;

    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
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
              wsState: ws,
              isMobile: isMobile,
              onResync: () => ref
                  .read(sentryScenarioProvider.notifier)
                  .forceFullSnapshotResync(),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: 'Quick jump (Ctrl+K)',
            child: isMobile
                ? IconButton(
                    key: const Key('open_command_palette_button'),
                    onPressed: () => showCommandPalette(context, ref),
                    icon: const Icon(Icons.search_rounded),
                  )
                : OutlinedButton.icon(
                    key: const Key('open_command_palette_button'),
                    onPressed: () => showCommandPalette(context, ref),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(wide ? 'Search  ·  Ctrl+K' : 'Ctrl+K'),
                  ),
          ),
          const SizedBox(width: 8),
          // When in Developer Test Mode (isMock), show the DEV pill that opens demo controls.
          // In production mode (real), show only the calm Manila clock with no demo triggers.
          if (config.isMock)
            Tooltip(
              message: 'Developer test mode · open simulator tools',
              child: InkWell(
                key: const Key('open_demo_controls_button'),
                borderRadius: BorderRadius.circular(999),
                onTap: () => showDemoControlsSheet(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.subtle,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: p.warn,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DEV',
                        style: SentryTheme.mono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(width: 10),
                        const _ManilaClock(),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else if (!isMobile)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: p.subtle,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.line),
              ),
              child: const _ManilaClock(),
            ),
          const SizedBox(width: 4),
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
  final WsStreamState wsState;
  final VoidCallback onResync;
  final bool isMobile;

  const _ConnectionStatus({
    required this.wsState,
    required this.onResync,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SentryPalette.of(context);
    final status = wsState.status;
    final isConnected = status == WsConnectionStatus.connected;
    final isReconnecting = status == WsConnectionStatus.reconnecting;
    final color = isConnected
        ? p.ok
        : isReconnecting
            ? p.warn
            : p.err;
    final tint = isConnected
        ? p.okTint
        : isReconnecting
            ? p.warnTint
            : p.errTint;
    final text = isConnected
        ? p.okText
        : isReconnecting
            ? p.warnText
            : p.errText;
    final label = isConnected
        ? 'Connected'
        : isReconnecting
            ? 'Reconnecting'
            : 'Offline';

    return Semantics(
      liveRegion: true,
      label: 'Backend status: $label.',
      child: AnimatedContainer(
        duration: SentryMotion.of(context, SentryMotion.medium),
        curve: SentryMotion.emphasized,
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PulseDot(color: color, pulsing: isConnected),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: text,
                ),
              ),
              if (!isMobile && wsState.lastSyncedAtUtc != null && isConnected) ...[
                const SizedBox(width: 6),
                Text(
                  'synced ${ManilaTime.formatTimeOnly(wsState.lastSyncedAtUtc)}',
                  style: TextStyle(fontSize: 12, color: text.withValues(alpha: 0.8)),
                ),
              ],
              if (!isMobile && !isConnected) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onResync,
                  style: TextButton.styleFrom(
                    foregroundColor: text,
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Resync'),
                ),
              ],
            ],
          ),
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
    return Text(
      ManilaTime.formatTimeOnly(_now),
      style: SentryTheme.mono(fontSize: 12.5, color: p.slate).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
