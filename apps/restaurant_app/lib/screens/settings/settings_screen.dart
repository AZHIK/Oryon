import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/preferences_provider.dart';
import '../../providers/whatsapp_provider.dart';
import '../../constants/app_strings.dart';
import '../../providers/roles_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/store_locations_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/formatters.dart';
import '../../widgets/nav_shell_scope.dart';

/// The settings index: one card per area, each saying what it currently holds
/// so the user can see whether they need to open it at all.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(businessProfileProvider);
    final settings = ref.watch(storeSettingsProvider);
    final locations = ref.watch(locationsSummaryProvider);
    final staff = ref.watch(staffSummaryProvider);
    final roles = ref.watch(rolesProvider).valueOrNull ?? const [];
    final themeMode = ref.watch(themeModeProvider);
    final density = ref.watch(tableDensityProvider);
    final staffName =
        ref.watch(sessionStaffProvider)?.name ?? AppStrings.notSignedIn;
    final whatsapp = ref.watch(whatsappConnectionProvider).valueOrNull;
    final pad = Insets.page(context.formFactor);

    final entries = <_SettingsEntry>[
      _SettingsEntry(
        icon: Icons.storefront_outlined,
        title: AppStrings.businessProfileEntry,
        subtitle: AppStrings.businessProfileBlurb,
        value: profile?.name ?? AppStrings.loadingEllipsis,
        onTap: () => context.goNamed(AppRoute.businessProfileName),
      ),
      _SettingsEntry(
        icon: Icons.percent_rounded,
        title: AppStrings.storeSettingsEntry,
        subtitle: AppStrings.storeSettingsBlurb,
        value: settings.taxEnabled
            ? '${Fmt.percent(settings.taxRate)} '
                '${settings.taxInclusive ? AppStrings.taxInclusive : AppStrings.taxOnTop} · '
                '${settings.currency.code}'
            : 'No tax · ${settings.currency.code}',
        onTap: () => context.goNamed(AppRoute.storeSettingsName),
      ),
      _SettingsEntry(
        icon: Icons.store_mall_directory_outlined,
        title: AppStrings.storeLocationsEntry,
        subtitle: AppStrings.storeLocationsBlurb,
        value: locations.active == locations.total
            ? AppStrings.locationCount(locations.total)
            : AppStrings.locationsActive(locations.active, locations.total),
        onTap: () => context.goNamed(AppRoute.storeManagementName),
      ),
      _SettingsEntry(
        icon: Icons.groups_outlined,
        title: AppStrings.staffRolesEntry,
        subtitle: AppStrings.staffRolesBlurb,
        value: AppStrings.staffRolesValue(staff.total, roles.length),
        onTap: () => context.goNamed(AppRoute.staffName),
      ),
      _SettingsEntry(
        icon: Icons.person_outline_rounded,
        title: AppStrings.accountEntry,
        subtitle: AppStrings.accountBlurb,
        value: staffName,
        onTap: () => context.goNamed(AppRoute.accountName),
      ),
      _SettingsEntry(
        icon: Icons.tune_rounded,
        title: AppStrings.appPrefsEntry,
        subtitle: AppStrings.appPrefsBlurb,
        value:
            '${switch (themeMode) {
              ThemeMode.system => AppStrings.themeSystem,
              ThemeMode.light => AppStrings.themeLight,
              ThemeMode.dark => AppStrings.themeDark,
            }} · ${density.label}',
        onTap: () => context.goNamed(AppRoute.appPreferencesName),
      ),
      _SettingsEntry(
        icon: Icons.chat_outlined,
        title: AppStrings.waSettingsTitle,
        subtitle: AppStrings.waSettingsSubtitle,
        value: whatsapp == null
            ? AppStrings.waNotConnected
            : whatsapp.isConnected
            ? '${AppStrings.waConnected} · ${whatsapp.displayPhoneNumber ?? whatsapp.phoneNumberId}'
            : AppStrings.waConnectionError,
        onTap: () => context.goNamed(AppRoute.whatsappName),
      ),
      _SettingsEntry(
        icon: Icons.print_outlined,
        title: AppStrings.devicesEntry,
        subtitle: AppStrings.devicesBlurb,
        value: AppStrings.notConfigured,
        // Further down the roadmap; the row is here so the index reflects the
        // real shape of Settings rather than only the parts that are built.
        enabled: false,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, Insets.md, pad, pad),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SettingsHeader(),
                    const SizedBox(height: Insets.xl),
                    for (final entry in entries) ...[
                      _SettingsCard(entry: entry),
                      const SizedBox(height: Insets.md),
                    ],
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

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const NavMenuButton(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.settingsTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                AppStrings.settingsSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

@immutable
class _SettingsEntry {
  const _SettingsEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// What this area currently says, shown on the right.
  final String value;

  final VoidCallback? onTap;

  /// False for areas the roadmap has not reached. Rendered muted with a
  /// "Coming soon" marker rather than hidden, so the index stays honest about
  /// what Settings will eventually hold.
  final bool enabled;
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.entry});

  final _SettingsEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final live = entry.enabled && entry.onTap != null;
    final foreground = live
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.45);

    return Material(
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: context.semantic.hairline),
      ),
      child: InkWell(
        onTap: live ? entry.onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Below this the value has no room beside the title and drops
              // under the subtitle instead of squeezing both.
              final inline = constraints.maxWidth >= 480;

              final identity = Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: (live ? colors.primary : colors.onSurfaceVariant)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Icon(
                      entry.icon,
                      size: 19,
                      color: live ? colors.primary : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                        Text(
                          entry.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final value = Text(
                entry.enabled ? entry.value : AppStrings.comingSoon,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: inline ? TextAlign.end : TextAlign.start,
                style: context.text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              );

              final chevron = Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: live
                    ? colors.onSurfaceVariant
                    : colors.onSurfaceVariant.withValues(alpha: 0.4),
              );

              if (inline) {
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: Insets.md),
                    Flexible(child: value),
                    const SizedBox(width: Insets.xs),
                    chevron,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: identity),
                      chevron,
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Padding(
                    padding: const EdgeInsets.only(left: 50),
                    child: value,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
