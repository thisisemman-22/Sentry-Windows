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
import '../features/authentication/presentation/change_password_dialog.dart';
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
  DesktopNavTab _previousTab = DesktopNavTab.dashboard;

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
    final role = ref.watch(authControllerProvider).role;
    final visibleTabs = DesktopNavTab.values
        .where((t) => t.isVisibleFor(role))
        .toList();
    final effectiveTab =
        visibleTabs.contains(activeTab) ? activeTab : visibleTabs.first;

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

    const shortcutKeys = <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
      LogicalKeyboardKey.digit0,
    ];
    final shortcuts = <ShortcutActivator, VoidCallback>{
      for (var i = 0; i < visibleTabs.length && i < shortcutKeys.length; i++)
        SingleActivator(shortcutKeys[i], control: true): () =>
            _go(visibleTabs[i]),
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

    final forward = effectiveTab.index >= _previousTab.index;
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
        key: ValueKey(effectiveTab),
        child: ColoredBox(
          color: p.bg,
          child: DesktopViewRouter(tab: effectiveTab),
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
                      floating: false,
                      activeTab: effectiveTab,
                      onToggleTheme: _toggleTheme,
                      onSelect: (tab) {
                        Navigator.of(context).maybePop();
                        _go(tab);
                      },
                    ),
                  ),
                )
              : null,
          bottomNavigationBar: isMobile
              ? Builder(builder: (context) {
                  final mobileTabs = visibleTabs.take(5).toList();
                  final idx = mobileTabs.indexOf(effectiveTab);
                  return NavigationBar(
                    backgroundColor: p.card,
                    selectedIndex: idx >= 0 ? idx : 0,
                    onDestinationSelected: (i) => _go(mobileTabs[i]),
                    destinations: [
                      for (final t in mobileTabs)
                        NavigationDestination(
                          icon: Icon(t.icon),
                          selectedIcon: Icon(t.selectedIcon),
                          label: t.title,
                        ),
                    ],
                  );
                })
              : null,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isMobile)
                  _Sidebar(
                    collapsed: collapsed,
                    floating: true,
                    activeTab: effectiveTab,
                    onToggleTheme: _toggleTheme,
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
  final bool floating;
  final DesktopNavTab activeTab;
  final ValueChanged<DesktopNavTab> onSelect;
  final VoidCallback onToggleTheme;

  const _Sidebar({
    required this.collapsed,
    required this.floating,
    required this.activeTab,
    required this.onSelect,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = SentryPalette.of(context);
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final profile = authState.profile;
    if (profile == null) return const SizedBox.shrink();
    final visibleTabs = DesktopNavTab.values
        .where((t) => t.isVisibleFor(profile.role))
        .toList();
    final kpis = ref.watch(
        sentryScenarioProvider.select((s) => s.computeDashboardKpis()));
    final overdueGuestCount = ref.watch(desktopOpsControllerProvider.select(
        (o) => o.guestVisitRequests.where((g) => g.isOverdue()).length));
    final width = collapsed ? 84.0 : 252.0;
    final railColor =
        floating && p.isDark ? const Color(0xEB121215) : p.card;

    return AnimatedContainer(
      key: floating ? const Key('floating_sidebar_rail') : null,
      duration: SentryMotion.of(context, SentryMotion.medium),
      curve: SentryMotion.emphasized,
      margin: floating ? const EdgeInsets.fromLTRB(12, 12, 0, 12) : EdgeInsets.zero,
      width: width,
      decoration: BoxDecoration(
        color: railColor,
        borderRadius: BorderRadius.circular(floating ? 20 : 0),
        border: floating ? Border.all(color: p.line, width: 1) : null,
        boxShadow: floating ? p.shadowSoft : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(floating ? 19 : 0),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: width,
          maxWidth: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand
              Padding(
                padding: EdgeInsets.fromLTRB(collapsed ? 24 : 20, 20, 14, 18),
                child: Row(
                  children: [
                    const SentryInteractiveLogo(size: 32),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < visibleTabs.length; i++) ...[
                          if (_sectionLabelFor(visibleTabs[i],
                                  isAdmin: profile.role.isAdmin) !=
                              null)
                            _NavSectionLabel(
                              label: _sectionLabelFor(
                                visibleTabs[i],
                                isAdmin: profile.role.isAdmin,
                              )!,
                              collapsed: collapsed,
                            ),
                          _NavItem(
                            key: Key('nav_tab_${visibleTabs[i].name}'),
                            tab: visibleTabs[i],
                            shortcutNumber: i + 1,
                            selected: visibleTabs[i] == activeTab,
                            collapsed: collapsed,
                            locked: false,
                            badge: switch (visibleTabs[i]) {
                              DesktopNavTab.monitoring =>
                                kpis.activeHoldsAwaitingPassageCount +
                                    kpis.pendingGuardReviewsCount,
                              DesktopNavTab.guardReviewQueue =>
                                kpis.pendingGuardReviewsCount,
                              DesktopNavTab.guardOverdueGuests =>
                                overdueGuestCount,
                              _ => 0,
                            },
                            badgeTone: visibleTabs[i] ==
                                    DesktopNavTab.guardOverdueGuests
                                ? PillTone.warn
                                : (kpis.pendingGuardReviewsCount > 0
                                    ? PillTone.err
                                    : PillTone.warn),
                            onTap: () => onSelect(visibleTabs[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom rail utilities: Theme toggle + collapse toggle
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? 10 : 12,
                  vertical: 4,
                ),
                child: collapsed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: floating
                                ? const Key('sidebar_theme_toggle')
                                : null,
                            tooltip: themeMode == ThemeMode.dark
                                ? 'Light mode (Ctrl+Shift+L)'
                                : 'OLED Dark mode (Ctrl+Shift+L)',
                            onPressed: onToggleTheme,
                            icon: Icon(
                              themeMode == ThemeMode.dark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 19,
                              color: p.slate,
                            ),
                          ),
                          if (floating)
                            IconButton(
                              key: const Key('sidebar_collapse_toggle'),
                              tooltip: 'Expand sidebar (Ctrl+B)',
                              onPressed: () => ref
                                  .read(sidebarCollapsedProvider.notifier)
                                  .state = !collapsed,
                              icon: AnimatedRotation(
                                turns: 0.5,
                                duration: SentryMotion.of(
                                    context, SentryMotion.medium),
                                curve: SentryMotion.emphasized,
                                child: const Icon(
                                    Icons.keyboard_double_arrow_left_rounded),
                              ),
                            ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: themeMode == ThemeMode.dark
                                  ? 'Switch to Light mode (Ctrl+Shift+L)'
                                  : 'Switch to OLED Dark mode (Ctrl+Shift+L)',
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    key: floating
                                        ? const Key('sidebar_theme_toggle')
                                        : null,
                                    onTap: onToggleTheme,
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: SentryMotion.of(
                                          context,
                                          const Duration(milliseconds: 180)),
                                      curve: Curves.easeOutCubic,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: p.subtle,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: p.line),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedSwitcher(
                                            duration: SentryMotion.of(
                                                context, SentryMotion.medium),
                                            transitionBuilder: (c, a) =>
                                                RotationTransition(
                                              turns: Tween(
                                                      begin: 0.75, end: 1.0)
                                                  .animate(a),
                                              child: FadeTransition(
                                                  opacity: a, child: c),
                                            ),
                                            child: Icon(
                                              themeMode == ThemeMode.dark
                                                  ? Icons.light_mode_outlined
                                                  : Icons.dark_mode_outlined,
                                              key: ValueKey(themeMode),
                                              size: 17,
                                              color: p.slate,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              themeMode == ThemeMode.dark
                                                  ? 'OLED Dark'
                                                  : 'Light mode',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: p.text,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (floating) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              key: const Key('sidebar_collapse_toggle'),
                              tooltip: 'Collapse sidebar (Ctrl+B)',
                              onPressed: () => ref
                                  .read(sidebarCollapsedProvider.notifier)
                                  .state = !collapsed,
                              icon: AnimatedRotation(
                                turns: 0,
                                duration: SentryMotion.of(
                                    context, SentryMotion.medium),
                                curve: SentryMotion.emphasized,
                                child: const Icon(
                                    Icons.keyboard_double_arrow_left_rounded),
                              ),
                            ),
                          ],
                        ],
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

String? _sectionLabelFor(DesktopNavTab tab, {required bool isAdmin}) {
  if (!isAdmin) return null;
  return switch (tab) {
    DesktopNavTab.dashboard => 'OPERATIONS',
    DesktopNavTab.users => 'DIRECTORY & FLEET',
    DesktopNavTab.announcements => 'SYSTEM',
    _ => null,
  };
}

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
    final role = ref.watch(authControllerProvider).role;
    final isAdmin = role.isAdmin;
    final q = _q.trim().toUpperCase();
    final visibleRoleTabs =
        DesktopNavTab.values.where((t) => t.isVisibleFor(role)).toList();
    final views = visibleRoleTabs
        .where((t) => q.isEmpty || t.title.toUpperCase().contains(q))
        .toList();
    final people = (!isAdmin || q.isEmpty)
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
                      trailing: Text(
                          'Ctrl+${visibleRoleTabs.indexOf(t) + 1}',
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
                      onTap: () {
                        ref.read(monitoringSubTabProvider.notifier).state = 2;
                        go(DesktopNavTab.monitoring);
                      },
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
  final int shortcutNumber;
  final bool selected;
  final bool collapsed;
  final bool locked;
  final int badge;
  final PillTone badgeTone;
  final VoidCallback onTap;

  const _NavItem({
    required Key super.key,
    required this.tab,
    required this.shortcutNumber,
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
    final activeCrimson =
        p.isDark ? SentryColors.crimsonDarkAccent : SentryColors.crimson;
    final iconColor = sel ? activeCrimson : (_hover ? p.text : p.slate);
    final textColor = sel ? p.text : (_hover ? p.text : p.slate);
    final shortcut = 'Ctrl+${widget.shortcutNumber}';
    final t = ToneColors.of(context, widget.badgeTone);

    final badge = widget.badge > 0
        ? AnimatedContainer(
            duration: SentryMotion.of(
                context, const Duration(milliseconds: 180)),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            constraints: const BoxConstraints(minWidth: 24),
            decoration: BoxDecoration(
              color: sel ? SentryColors.crimson : t.solid,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${widget.badge}',
              textAlign: TextAlign.center,
              style: SentryTheme.mono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            focusColor: p.crimson.withValues(alpha: 0.14),
            child: AnimatedContainer(
              duration: SentryMotion.of(
                  context, const Duration(milliseconds: 180)),
              curve: Curves.easeOutCubic,
              height: 42,
              padding: EdgeInsets.symmetric(
                  horizontal: widget.collapsed ? 0 : 12),
              decoration: BoxDecoration(
                color: sel
                    ? SentryColors.crimson
                        .withValues(alpha: p.isDark ? 0.18 : 0.10)
                    : (_hover ? p.subtle : Colors.transparent),
                borderRadius: BorderRadius.circular(11),
              ),
              child: widget.collapsed
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                            sel ? widget.tab.selectedIcon : widget.tab.icon,
                            size: 21,
                            color: iconColor),
                        if (widget.badge > 0)
                          Positioned(
                            top: 7,
                            right: 12,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: sel ? SentryColors.crimson : t.solid,
                                shape: BoxShape.circle,
                                border: Border.all(color: p.card, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        AnimatedContainer(
                          duration: SentryMotion.of(
                              context, const Duration(milliseconds: 180)),
                          width: 3,
                          height: sel ? 18 : 0,
                          decoration: BoxDecoration(
                            color: activeCrimson,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        SizedBox(width: sel ? 9 : 12),
                        Icon(
                            sel ? widget.tab.selectedIcon : widget.tab.icon,
                            size: 19,
                            color: iconColor),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            widget.tab.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (widget.locked)
                          Icon(Icons.lock_outline_rounded,
                              size: 16,
                              color: textColor.withValues(alpha: 0.7)),
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
            key: const Key('menu_own_profile'),
            leadingIcon: const Icon(Icons.badge_outlined),
            onPressed: () => showOwnProfileDialog(context, ref),
            child: const Text('My profile'),
          ),
          MenuItemButton(
            key: const Key('menu_change_password'),
            leadingIcon: const Icon(Icons.password_rounded),
            onPressed: () => showChangePasswordDialog(context),
            child: const Text('Change password'),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showAboutSentry(context),
            child: const Text('About SENTRY'),
          ),
          const Divider(height: 8),
          MenuItemButton(
            key: const Key('menu_sign_out'),
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
              key: const Key('operator_account_menu_button'),
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
    final role = ref.watch(authControllerProvider).role;
    final visibleTabs = DesktopNavTab.values
        .where((t) => t.isVisibleFor(role))
        .toList();
    final rawTab = ref.watch(selectedDesktopTabProvider);
    final activeTab = visibleTabs.contains(rawTab) ? rawTab : visibleTabs.first;
    final wide = MediaQuery.sizeOf(context).width >= 1180;

    return Container(
      height: 54,
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
          ] else ...[
            Text(
              activeTab.title,
              style: SentryTheme.display(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            const SizedBox(width: 12),
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
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: p.subtle,
                    ),
                    onPressed: () => showCommandPalette(context, ref),
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: Text(
                      wide ? 'Search  ·  Ctrl+K' : 'Ctrl+K',
                      style: TextStyle(fontSize: 12.5, color: p.slate),
                    ),
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
          if (isMobile) ...[
            const SizedBox(width: 4),
            IconButton(
              key: const Key('sidebar_theme_toggle'),
              tooltip: themeMode == ThemeMode.dark
                  ? 'Light mode (Ctrl+Shift+L)'
                  : 'OLED Dark mode (Ctrl+Shift+L)',
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
        ? 'Live'
        : isReconnecting
            ? 'Connecting'
            : 'Polling';

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
