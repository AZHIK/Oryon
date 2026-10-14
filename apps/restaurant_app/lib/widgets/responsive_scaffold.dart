import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/permission.dart';
import '../constants/app_strings.dart';
import '../providers/branch_refresh_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'app_top_bar.dart';
import 'brand_mark.dart';
import 'nav_shell_scope.dart';

@immutable
class NavDestinationSpec {
  const NavDestinationSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.requiredPermission,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Permission code gating this destination, or `null` if every signed-in
  /// staff member should see it (no catalogue permission covers it yet).
  final String? requiredPermission;
}

/// Width of the rail once extended. NavigationRail's API takes this as a
/// concrete number, so the header derives its own width from the same
/// constant rather than guessing.
const double _railExtendedWidth = 212;
const double _railCollapsedWidth = 76;

/// Order matters — these line up index-for-index with the shell branches in
/// [goRouterProvider].
///
/// This is a getter (not a top-level `final`) so `AppStrings.nav*` labels are
/// re-evaluated on every build. A cached list would snapshot the launch
/// language and ignore later toggles.
List<NavDestinationSpec> get _destinations => <NavDestinationSpec>[
  NavDestinationSpec(
    label: AppStrings.navDashboard,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
  NavDestinationSpec(
    label: AppStrings.navPos,
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    requiredPermission: AppPermissions.posAccess,
  ),
  NavDestinationSpec(
    label: AppStrings.navSales,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    // `pos.view`, not the invented `sales.view` — this is what POS Service
    // actually checks on every sales-ledger read.
    requiredPermission: AppPermissions.posView,
  ),
  NavDestinationSpec(
    label: AppStrings.navCustomers,
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt_rounded,
    requiredPermission: AppPermissions.customersView,
  ),
  NavDestinationSpec(
    label: AppStrings.navPurchasing,
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag_rounded,
    requiredPermission: AppPermissions.procurementView,
  ),
  NavDestinationSpec(
    label: AppStrings.navProduction,
    icon: Icons.soup_kitchen_outlined,
    selectedIcon: Icons.soup_kitchen_rounded,
    requiredPermission: AppPermissions.productionView,
  ),
  NavDestinationSpec(
    label: AppStrings.navSuppliers,
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
    requiredPermission: AppPermissions.suppliersView,
  ),
  // Couriers module is hidden from navigation (kept here, not deleted, so
  // these indices stay aligned index-for-index with the shell branches in
  // [goRouterProvider] and the route remains reachable by deep link).
  // See [_hiddenNavIndices] and the Sell group below.
  NavDestinationSpec(
    label: AppStrings.navCouriers,
    icon: Icons.two_wheeler_outlined,
    selectedIcon: Icons.two_wheeler_rounded,
    requiredPermission: AppPermissions.couriersView,
  ),
  NavDestinationSpec(
    label: AppStrings.navFinance,
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    requiredPermission: AppPermissions.financeView,
  ),
  NavDestinationSpec(
    label: AppStrings.navReports,
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    requiredPermission: AppPermissions.reportsView,
  ),
  NavDestinationSpec(
    label: AppStrings.navInsights,
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome_rounded,
    requiredPermission: AppPermissions.insightsView,
  ),
  NavDestinationSpec(
    label: AppStrings.groceriesTab,
    icon: Icons.shopping_basket_outlined,
    selectedIcon: Icons.shopping_basket_rounded,
    requiredPermission: AppPermissions.inventoryView,
  ),
  NavDestinationSpec(
    label: AppStrings.menuItemsTab,
    icon: Icons.restaurant_menu_outlined,
    selectedIcon: Icons.restaurant_menu_rounded,
    requiredPermission: AppPermissions.inventoryView,
  ),
  NavDestinationSpec(
    label: AppStrings.navStaff,
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
    requiredPermission: AppPermissions.staffView,
  ),
  NavDestinationSpec(
    label: AppStrings.navSettings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    requiredPermission: AppPermissions.settingsStore,
  ),
];

/// One sidebar dropdown: related destinations under a single heading.
///
/// [children] are indices into [_destinations], in display order. Branch
/// order never changes — groups are display-only, so deep links, badges
/// and the shell's index mapping are untouched.
@immutable
class NavGroupSpec {
  const NavGroupSpec({
    required this.label,
    required this.icon,
    required this.children,
    this.expandedByDefault = false,
  });

  final String label;
  final IconData icon;
  final List<int> children;

  /// Groups that start open on first build. The counter lives here most
  /// of the day, so Sell opens itself — every other group opens when it
  /// holds the current branch, or when the staff member taps it.
  final bool expandedByDefault;
}

/// Sidebar groups, in display order: Dashboard stays standalone on top,
/// everything else folds into four dropdowns. This is a getter (not a
/// top-level `final`) for the same language-toggle reason as [_destinations].
List<NavGroupSpec> get _groups => <NavGroupSpec>[
  NavGroupSpec(
    label: AppStrings.navGroupSell,
    icon: Icons.shopping_basket_outlined,
    // Couriers (index 7) hidden from the sidebar — module kept, not deleted.
    children: const [1, 2, 3],
    expandedByDefault: true,
  ),
  NavGroupSpec(
    label: AppStrings.navGroupStock,
    icon: Icons.warehouse_outlined,
    children: const [11, 12, 5, 6, 4],
  ),
  NavGroupSpec(
    label: AppStrings.navGroupAnalytics,
    icon: Icons.analytics_outlined,
    children: const [9, 10],
  ),
  NavGroupSpec(
    label: AppStrings.navGroupManage,
    icon: Icons.admin_panel_settings_outlined,
    children: const [13, 14],
  ),
];

/// Standalone destinations, in display order: Finance sits right below
/// the Reports & Insights dropdown.
const _standaloneIndices = <int>[8];

/// One row of the mobile More sheet: either a group header or a
/// destination. Keeps the sheet's order identical to the sidebar's.
@immutable
class _MoreEntry {
  const _MoreEntry.header(this.label) : index = -1;
  const _MoreEntry.destination(this.index) : label = '';

  final String label;
  final int index;

  bool get isHeader => index == -1;
}

/// Dashboard, Sell (+header), Stock (+header), Reports & Insights
/// (+header), Finance, then Manage (+header) — the same sequence as
/// [_SidebarSections].
List<_MoreEntry> _moreSheetEntries(List<int> visible) {
  final entries = <_MoreEntry>[];
  void addGroup(NavGroupSpec group) {
    final children = [
      for (final i in group.children)
        if (visible.contains(i)) i,
    ];
    if (children.isEmpty) return;
    entries.add(_MoreEntry.header(group.label));
    for (final i in children) {
      entries.add(_MoreEntry.destination(i));
    }
  }

  if (visible.contains(0)) entries.add(const _MoreEntry.destination(0));
  addGroup(_groups[0]);
  addGroup(_groups[1]);
  addGroup(_groups[2]);
  for (final i in _standaloneIndices) {
    if (visible.contains(i)) entries.add(_MoreEntry.destination(i));
  }
  addGroup(_groups[3]);
  return entries;
}

/// Destinations hidden from every navigation surface (sidebar rail, drawer,
/// mobile bottom bar / More sheet) without deleting the module: the entry in
/// [_destinations] and its shell branch in [goRouterProvider] stay in place so
/// branch indices never shift. Currently: 7 == Couriers.
const _hiddenNavIndices = <int>{7};

/// Destinations visible to the signed-in staff member, as indices into
/// [_destinations] — a destination with no [NavDestinationSpec.requiredPermission]
/// is always included; otherwise it needs that permission (or the `*`
/// wildcard). Dashboard has no permission of its own, so this is never empty.
final _visibleNavIndicesProvider = Provider<List<int>>((ref) {
  final visible = <int>[];
  for (var i = 0; i < _destinations.length; i++) {
    if (_hiddenNavIndices.contains(i)) continue;
    final permission = _destinations[i].requiredPermission;
    if (permission == null || ref.watch(hasPermissionProvider(permission))) {
      visible.add(i);
    }
  }
  return visible;
});

/// The POS tab carries the open-order badge. Second in the list, since the
/// dashboard took the first slot.
const _cartBadgeIndex = 1;

/// Hosts the shell branches and swaps navigation affordances by width:
/// bottom bar on phones, a hamburger drawer on tablets, and a persistent rail
/// on desktop that extends to labels once there is room. The branch
/// [Navigator]s are untouched in every case, so state survives the switch.
class ResponsiveScaffold extends ConsumerStatefulWidget {
  const ResponsiveScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends ConsumerState<ResponsiveScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onDestinationSelected(int index) {
    // Remember the visible tab for the top bar's refresh button, then
    // switch. Re-tapping the active tab still refreshes: `initialLocation`
    // pops that branch back to its root (the standard "tap to go home"
    // behaviour) and the background re-pull below picks up any server-side
    // changes, so a restart is never needed to see fresh data.
    ref.read(currentBranchIndexProvider.notifier).state = index;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    refreshBranchInBackground(ref, index);
  }

  void _onDrawerDestinationSelected(int index) {
    Navigator.of(context).pop();
    _onDestinationSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final form = Breakpoints.of(constraints.maxWidth);
        final index = widget.navigationShell.currentIndex;

        final body = NavShellScope(
          hasDrawer: form.isTablet,
          openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          child: widget.navigationShell,
        );

        final scaffold = switch (form) {
          FormFactor.mobile => Scaffold(
            key: _scaffoldKey,
            body: body,
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
              ),
              child: _BottomNav(
                currentIndex: index,
                onSelected: _onDestinationSelected,
              ),
            ),
          ),

          // Tablet trades the rail for a drawer: at 600–1024 the ~76px rail is
          // width the item grid and cart panel need more than navigation does.
          FormFactor.tablet => Scaffold(
            key: _scaffoldKey,
            drawer: _NavDrawer(
              currentIndex: index,
              onSelected: _onDrawerDestinationSelected,
            ),
            body: body,
          ),

          FormFactor.desktop => Scaffold(
            key: _scaffoldKey,
            body: SafeArea(
              child: Row(
                children: [
                  if (constraints.maxWidth >= Breakpoints.extendedRail)
                    _GroupedRail(
                      currentIndex: index,
                      onSelected: _onDestinationSelected,
                    )
                  else
                    _SideRail(
                      currentIndex: index,
                      onSelected: _onDestinationSelected,
                      extended: false,
                    ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        };

        return Column(
          children: [
            const AppTopBar(),
            Expanded(child: scaffold),
          ],
        );
      },
    );
  }
}

/// Destinations the phone's bottom bar shows directly, by index into
/// [_destinations]. The rest live behind "More".
///
/// Eight tabs across a 360px bar leaves each one about 45px, which clips the
/// longer labels and puts every target under the comfortable touch size. Five
/// is what the bar can actually hold, so the four a counter uses hourly stay
/// on it and the occasional ones move one tap further away.
///
/// Indices into [_destinations]: Home, POS, Sales, Finance. Any of these the
/// staff member lacks permission for drops out, same as the rest.
const _mobilePrimary = <int>[0, 1, 2, 6];

class _BottomNav extends ConsumerWidget {
  const _BottomNav({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartItemCountProvider);
    final visible = ref.watch(_visibleNavIndicesProvider);
    final primary = [for (final i in _mobilePrimary) if (visible.contains(i)) i];
    final moreSlot = primary.length;

    // A destination reached through "More" keeps that slot highlighted, so the
    // bar never shows nothing selected.
    final slot = primary.indexOf(currentIndex);
    final selected = slot == -1 ? moreSlot : slot;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.semantic.hairline)),
      ),
      child: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (tapped) => tapped == moreSlot
            ? _openMore(context, visible)
            : onSelected(primary[tapped]),
        destinations: [
          for (final i in primary)
            NavigationDestination(
              icon: _badged(Icon(_destinations[i].icon), i, cartCount),
              selectedIcon: _badged(
                Icon(_destinations[i].selectedIcon),
                i,
                cartCount,
              ),
              label: _destinations[i].label,
              tooltip: _destinations[i].label,
            ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: AppStrings.navMore,
            tooltip: AppStrings.navMoreDestinations,
          ),
        ],
      ),
    );
  }

  Future<void> _openMore(BuildContext context, List<int> visible) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                0,
                Insets.xl,
                Insets.sm,
              ),
              child: Text(
                AppStrings.navGoTo,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Every destination the staff member can see, not only the
                    // overflow ones — a menu that hides where you already are
                    // is harder to orient in. Grouped exactly like the
                    // sidebar dropdowns.
                    if (visible.contains(0))
                      ListTile(
                        leading: Icon(
                          currentIndex == 0
                              ? _destinations[0].selectedIcon
                              : _destinations[0].icon,
                        ),
                        title: Text(_destinations[0].label),
                        selected: currentIndex == 0,
                        onTap: () => Navigator.of(sheetContext).pop(0),
                      ),
                    for (final entry in _moreSheetEntries(visible)) ...[
                      if (entry.isHeader)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Insets.xl,
                            Insets.md,
                            Insets.xl,
                            0,
                          ),
                          child: Text(
                            entry.label.toUpperCase(),
                            style: Theme.of(sheetContext)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        )
                      else
                        ListTile(
                          leading: Icon(
                            entry.index == currentIndex
                                ? _destinations[entry.index].selectedIcon
                                : _destinations[entry.index].icon,
                          ),
                          title: Text(_destinations[entry.index].label),
                          selected: entry.index == currentIndex,
                          onTap: () => Navigator.of(
                            sheetContext,
                          ).pop(entry.index),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.md),
              child: _ThemeToggleTile(),
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );

    if (picked != null) onSelected(picked);
  }
}

/// The wide-rail replacement: Dashboard plus four dropdowns instead of
/// fourteen flat rows. Collapsed windows keep the icon-only [_SideRail].
class _GroupedRail extends ConsumerWidget {
  const _GroupedRail({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);

    return SizedBox(
      width: _railExtendedWidth,
      child: Column(
        children: [
          const _RailHeader(extended: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
              children: [
                _SidebarSections(
                  currentIndex: currentIndex,
                  onSelected: onSelected,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.lg, top: Insets.sm),
            child: IconButton(
              tooltip: switch (themeMode) {
                ThemeMode.system => AppStrings.themeFollowSystem,
                ThemeMode.light => AppStrings.themeLight,
                ThemeMode.dark => AppStrings.themeDark,
              },
              onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
              icon: Icon(switch (themeMode) {
                ThemeMode.system => Icons.brightness_auto_rounded,
                ThemeMode.light => Icons.light_mode_rounded,
                ThemeMode.dark => Icons.dark_mode_rounded,
              }),
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDrawer extends ConsumerWidget {
  const _NavDrawer({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                Insets.md,
                Insets.xl,
                Insets.md,
                Insets.sm,
              ),
              child: BrandLockup(),
            ),
            _SidebarSections(
              currentIndex: currentIndex,
              onSelected: onSelected,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                Insets.md,
                Insets.md,
                Insets.md,
                Insets.sm,
              ),
              child: Divider(),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.md),
              child: _ThemeToggleTile(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideRail extends ConsumerWidget {
  const _SideRail({
    required this.currentIndex,
    required this.onSelected,
    required this.extended,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final cartCount = ref.watch(cartItemCountProvider);
    final themeMode = ref.watch(themeModeProvider);
    final visible = ref.watch(_visibleNavIndicesProvider);
    final selected = visible.indexOf(currentIndex);

    return NavigationRail(
      selectedIndex: selected == -1 ? 0 : selected,
      onDestinationSelected: (position) => onSelected(visible[position]),
      extended: extended,
      minWidth: _railCollapsedWidth,
      minExtendedWidth: _railExtendedWidth,
      groupAlignment: -0.9,
      // Lets the destination group scroll on a short window — a 320px-tall
      // terminal would otherwise overflow the rail rather than clip it.
      scrollable: true,
      leading: _RailHeader(extended: extended),
      // No Expanded here: the rail already bottom-aligns `trailing`, and a
      // flex child would split the rail's height with the destinations
      // instead of taking only what it needs.
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: Insets.lg, top: Insets.sm),
        child: IconButton(
          tooltip: switch (themeMode) {
            ThemeMode.system => AppStrings.themeFollowSystem,
            ThemeMode.light => AppStrings.themeLight,
            ThemeMode.dark => AppStrings.themeDark,
          },
          onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
          icon: Icon(switch (themeMode) {
            ThemeMode.system => Icons.brightness_auto_rounded,
            ThemeMode.light => Icons.light_mode_rounded,
            ThemeMode.dark => Icons.dark_mode_rounded,
          }),
          color: colors.onSurfaceVariant,
        ),
      ),
      destinations: [
        for (final i in visible)
          NavigationRailDestination(
            icon: _badged(Icon(_destinations[i].icon), i, cartCount),
            selectedIcon: _badged(
              Icon(_destinations[i].selectedIcon),
              i,
              cartCount,
            ),
            label: Text(_destinations[i].label),
            padding: const EdgeInsets.symmetric(vertical: Insets.xs),
          ),
      ],
    );
  }
}

/// Wraps an icon in the open-order count, but only for the POS destination.
Widget _badged(Widget icon, int index, int cartCount) {
  if (index != _cartBadgeIndex || cartCount == 0) return icon;
  return Badge.count(count: cartCount, child: icon);
}

/// One destination row inside a dropdown (or the standalone Dashboard).
/// Public so widget tests can drive the grouped navigation in isolation.
class NavChildTile extends ConsumerWidget {
  const NavChildTile({
    required this.index,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final int index;
  final bool selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final cartCount = ref.watch(cartItemCountProvider);
    final spec = _destinations[index];
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      selected: selected,
      selectedTileColor: colors.secondaryContainer,
      selectedColor: colors.onSecondaryContainer,
      iconColor: colors.onSurfaceVariant,
      leading: _badged(
        Icon(selected ? spec.selectedIcon : spec.icon),
        index,
        cartCount,
      ),
      title: Text(spec.label),
      onTap: () => onSelected(index),
    );
  }
}

/// The sidebar's section order, shared by the rail and the drawer:
/// Dashboard, Sell, Stock, Reports & Insights, Finance, then Manage.
/// One definition so the two can never drift apart.
class _SidebarSections extends ConsumerWidget {
  const _SidebarSections({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(_visibleNavIndicesProvider);
    // _groups is [Sell, Stock, Reports & Insights, Manage] — Finance
    // stands alone between Reports & Insights and Manage.
    Widget group(int g) => NavGroupTile(
          group: _groups[g],
          currentIndex: currentIndex,
          onSelected: onSelected,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visible.contains(0))
          NavChildTile(
            index: 0,
            selected: currentIndex == 0,
            onSelected: onSelected,
          ),
        group(0),
        group(1),
        group(2),
        for (final i in _standaloneIndices)
          if (visible.contains(i))
            NavChildTile(
              index: i,
              selected: currentIndex == i,
              onSelected: onSelected,
            ),
        group(3),
      ],
    );
  }
}

/// One sidebar dropdown. Expansion follows the active destination: the
/// group holding the current branch opens itself (via the key, so a manual
/// collapse of any other group survives rebuilds), and a group with no
/// visible children renders nothing.
/// Public so widget tests can drive the grouped navigation in isolation.
class NavGroupTile extends ConsumerWidget {
  const NavGroupTile({
    required this.group,
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final NavGroupSpec group;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(_visibleNavIndicesProvider);
    final children = [
      for (final i in group.children)
        if (visible.contains(i)) i,
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    final contains = children.contains(currentIndex);
    return ExpansionTile(
      key: ValueKey('nav-group-${group.label}-$contains'),
      initiallyExpanded: contains || group.expandedByDefault,
      shape: const Border(),
      leading: Icon(group.icon),
      title: Text(
        group.label,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      childrenPadding: const EdgeInsets.only(left: Insets.md),
      children: [
        for (final i in children)
          NavChildTile(
            index: i,
            selected: i == currentIndex,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

class _ThemeToggleTile extends ConsumerWidget {
  const _ThemeToggleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      leading: Icon(switch (themeMode) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      }),
      title: Text(switch (themeMode) {
        ThemeMode.system => AppStrings.followSystem,
        ThemeMode.light => AppStrings.lightTheme,
        ThemeMode.dark => AppStrings.darkTheme,
      }),
      onTap: () => ref.read(themeModeProvider.notifier).cycle(),
    );
  }
}

/// Brand mark at the top of the rail. Collapses to just the mark when the rail
/// is not extended.
class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xl,
        Insets.md,
        Insets.xl,
      ),
      child: extended
          // NavigationRail lays its `leading` out with unbounded width while
          // measuring, so the Row needs a bound of its own before Expanded
          // can mean anything.
          ? const SizedBox(
              width: _railExtendedWidth - Insets.md * 2,
              child: BrandLockup(),
            )
          : const BrandMark(),
    );
  }
}
