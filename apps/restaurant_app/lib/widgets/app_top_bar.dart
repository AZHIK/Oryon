import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../providers/notifications_provider.dart';
import '../constants/app_strings.dart';
import '../providers/branch_refresh_provider.dart';
import '../providers/preferences_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'chat_dialog.dart';
import 'connection_status_pill.dart';

abstract final class AppTopBarKeys {
  static const accountMenu = Key('appTopBar.accountMenu');
  static const endShift = Key('appTopBar.endShift');
  static const logout = Key('appTopBar.logout');
}

/// Top app bar with notifications, account, and other actions.
class AppTopBar extends ConsumerWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final staff = ref.watch(currentStaffProvider);
    // Watch the provider (not the static L10n flag) so this bar rebuilds
    // on every toggle. L10n.code is kept in sync by AppLanguageNotifier.
    final language = ref.watch(appLanguageProvider);
    final isSw = language == AppLanguage.swahili;
    final surfaceBrightness = ThemeData.estimateBrightnessForColor(
      colors.surface,
    );
    final statusBarIconBrightness = surfaceBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.surface,
        statusBarBrightness: surfaceBrightness,
        statusBarIconBrightness: statusBarIconBrightness,
      ),
      child: Material(
        color: colors.surface,
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.semantic.hairline),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.md,
              ),
              child: Row(
                children: [
                  // Desktop gets an explicit refresh action for the visible tab;
                  // phones and tablets pull down at the top of any list instead.
                  if (context.isDesktop) const _RefreshButton(),
                  if (context.isDesktop) const SizedBox(width: Insets.md),
                  // The trailing cluster takes the rest of the bar and stays
                  // right-aligned. The pill is Flexible so its label ellipsizes
                  // rather than pushing the action buttons off a narrow phone.
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Online/offline + "not sent yet" count, everywhere.
                        const Flexible(child: ConnectionStatusPill()),
                        const SizedBox(width: Insets.md),
                        // Actions on the right
                        _IconButton(
                          icon: Icons.chat_outlined,
                          tooltip: AppStrings.chatWithAssistant,
                          onPressed: () => ChatDialog.show(context),
                        ),
                        const SizedBox(width: Insets.md),
                        _NotificationButton(
                          onPressed: () =>
                              context.goNamed(AppRoute.notificationsName),
                        ),
                        const SizedBox(width: Insets.md),
                        _IconButton(
                          icon: Icons.help_outline_rounded,
                          tooltip: AppStrings.help,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.helpComingSoon),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: Insets.md),
                        _IconButton(
                          icon: isSw
                              ? Icons.terrain_rounded
                              : Icons.language_rounded,
                          tooltip: isSw ? 'Kiingereza' : 'English',
                          onPressed: () {
                            final next = isSw
                                ? AppLanguage.english
                                : AppLanguage.swahili;
                            ref.read(appLanguageProvider.notifier).set(next);
                          },
                        ),
                        const SizedBox(width: Insets.md),
                        PopupMenuButton<String>(
                          key: AppTopBarKeys.accountMenu,
                          tooltip: AppStrings.accountAndOptions,
                          onSelected: (value) async {
                            if (value == 'end_shift') {
                              // Offline session only: lock the till, keep tokens so a
                              // PIN unlock resumes online access without a new OTP.
                              ref.read(sessionProvider.notifier).endShift();
                            } else if (value == 'logout') {
                              // Online + offline: revoke backend session, clear stored
                              // tokens, drop local session. Guard routes to picker/login.
                              await ref.read(sessionProvider.notifier).logout();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              key: AppTopBarKeys.endShift,
                              value: 'end_shift',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: Insets.sm),
                                  Text(AppStrings.endShift),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              key: AppTopBarKeys.logout,
                              value: 'logout',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.logout_rounded,
                                    size: 18,
                                    color: colors.error,
                                  ),
                                  const SizedBox(width: Insets.sm),
                                  Text(
                                    AppStrings.logout,
                                    style: TextStyle(color: colors.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          child: SizedBox(
                            height: 40,
                            width: 40,
                            child: Material(
                              color: colors.primaryContainer,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  staff.characters.first.toUpperCase(),
                                  style: context.text.titleSmall?.copyWith(
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Re-reads whatever the visible tab shows, with a spinner while it runs.
///
/// Desktop-only (the scaffold hides it elsewhere): on phones and tablets the
/// same refresh is a pull-down at the top of any list.
class _RefreshButton extends ConsumerStatefulWidget {
  const _RefreshButton();

  @override
  ConsumerState<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends ConsumerState<_RefreshButton> {
  bool _spinning = false;

  Future<void> _onPressed() async {
    if (_spinning) return;
    setState(() => _spinning = true);
    try {
      await refreshBranch(ref, ref.read(currentBranchIndexProvider));
    } finally {
      if (mounted) setState(() => _spinning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _IconButton(
      icon: Icons.refresh_rounded,
      tooltip: AppStrings.refresh,
      onPressed: _onPressed,
      spinning: _spinning,
    );
  }
}

class _NotificationButton extends ConsumerWidget {
  const _NotificationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationsUnreadCountProvider);

    return _IconButton(
      icon: Icons.notifications_outlined,
      tooltip: AppStrings.notifications,
      badgeCount: unreadCount,
      onPressed: onPressed,
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
    this.spinning = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final button = IconButton(
      padding: EdgeInsets.zero,
      iconSize: 20,
      onPressed: spinning ? null : onPressed,
      icon: spinning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      color: colors.onSurface,
    );

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 40,
        width: 40,
        child: Material(
          color: colors.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: context.semantic.hairline),
          ),
          child: badgeCount > 0
              ? Badge.count(count: badgeCount, child: button)
              : button,
        ),
      ),
    );
  }
}
