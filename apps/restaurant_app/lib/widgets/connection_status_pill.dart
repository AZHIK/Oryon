import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';
import '../providers/outbox_status_provider.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';

/// The "am I online, is everything sent?" pill in the top bar.
///
/// Green dot + "Online" when connected, grey dot + "Offline" when not.
/// When rows are still waiting to be sent it grows a count ("2 not sent");
/// tapping it while online sends everything now, tapping while offline
/// explains nothing can be sent yet. Simple words, one glance.
class ConnectionStatusPill extends ConsumerWidget {
  const ConnectionStatusPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final outbox = ref.watch(outboxStatusProvider).valueOrNull;
    final pending = outbox?.total ?? 0;
    final syncing = outbox?.isSyncing ?? false;
    final stale = outbox?.isStale ?? false;
    final days = outbox?.staleDays ?? -1;
    final colors = context.colors;
    final semantic = context.semantic;

    final dot = syncing
        ? const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online
                  ? (stale ? semantic.warning : semantic.success)
                  : colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          );

    final label = !online
        ? 'Offline'
        : syncing
            ? 'Sending…'
            : pending > 0
                ? 'Online · $pending not sent'
                : stale
                    ? (days < 0 ? 'Never synced' : 'Not synced $days d')
                    : 'Online';

    return Tooltip(
      message: 'Tap to see what is sent and what is still waiting.',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.pill),
        onTap: () => showSyncStatusSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.xs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: context.semantic.hairline),
            color: !online
                ? colors.surfaceContainerHigh
                : (pending > 0 || stale)
                    ? semantic.warningContainer.withValues(alpha: 0.6)
                    : colors.surfaceContainerLowest,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot,
              const SizedBox(width: Insets.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: !online ? colors.onSurfaceVariant : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The whole-app sync picture, opened from the top-bar pill:
///
/// connection, per-area waiting counts, when everything last synced —
/// plus the stale warning when the last good sync is more than a day
/// ago (or never). This is the one place that answers "are we synced?".
Future<void> showSyncStatusSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => const SafeArea(
      top: false,
      child: _SyncStatusSheet(),
    ),
  );
}

class _SyncStatusSheet extends ConsumerWidget {
  const _SyncStatusSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final outbox =
        ref.watch(outboxStatusProvider).valueOrNull ?? OutboxStatus.idle;
    final stale = outbox.isStale;
    final colors = context.colors;
    final semantic = context.semantic;

    Widget areaRow(String label, int count) {
      final waiting = count > 0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              waiting ? Icons.cloud_upload_outlined : Icons.check_circle_outline_rounded,
              size: 20,
              color: waiting ? semantic.warning : semantic.success,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(label, style: context.text.bodyLarge),
            ),
            Text(
              waiting ? '$count waiting' : 'Sent',
              style: context.text.bodyMedium?.copyWith(
                color: waiting ? semantic.warning : semantic.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        0,
        Insets.xl,
        Insets.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sync status',
                  style: context.text.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: context.semantic.hairline),
                ),
                child: Text(
                  online ? 'Online' : 'Offline',
                  style: context.text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Last synced: ${lastSyncedLabel(outbox.lastSynced)}',
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Insets.md),
          // The stale warning: more than a day since the last good sync.
          if (stale && !online)
            Container(
              margin: const EdgeInsets.only(bottom: Insets.md),
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: context.semantic.hairline),
              ),
              child: const Text(
                'You are offline, so nothing can be sent right now. '
                'New sales, customers and expenses stay on this device '
                'and send themselves when internet is back.',
              ),
            ),
          if (stale && online)
            Container(
              margin: const EdgeInsets.only(bottom: Insets.md),
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color:
                    semantic.warningContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: semantic.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: semantic.warning,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      outbox.lastSynced == null
                          ? 'Never synced yet. Send now to catch up.'
                          : 'Not synced for ${outbox.staleDays == 1 ? 'over a day' : '${outbox.staleDays} days'}. Send now to catch up.',
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          areaRow('Sales', outbox.pendingSales),
          areaRow('Customers', outbox.pendingCustomers),
          areaRow('Expenses', outbox.pendingExpenses),
          areaRow('Incomes', outbox.pendingIncomes),
          if (!outbox.hasPending)
            Padding(
              padding: const EdgeInsets.only(top: Insets.xs),
              child: Text(
                'Everything is sent.',
                style: context.text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (outbox.lastError != null) ...[
            const SizedBox(height: Insets.sm),
            Text(
              'Last problem: ${outbox.lastError}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
              if (online) ...[
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: outbox.isSyncing
                        ? null
                        : () async {
                            await syncNowAll(ref);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: Text(
                      outbox.isSyncing ? 'Sending…' : 'Send now',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Amber strip above a table: how many of its rows are still waiting.
///
/// Only rendered when [pendingCount] > 0. "Send now" drains every outbox
/// (tap does no harm when the rest is already sent).
class PendingSyncBanner extends ConsumerWidget {
  const PendingSyncBanner({
    super.key,
    required this.pendingCount,
    required this.itemWord,
  });

  /// Rows of this table still on the device only.
  final int pendingCount;

  /// Plain word for one row, e.g. "sale" / "expense" — plural is just + "s".
  final String itemWord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pendingCount <= 0) return const SizedBox.shrink();
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final syncing =
        ref.watch(outboxStatusProvider).valueOrNull?.isSyncing ?? false;
    final colors = context.colors;
    final semantic = context.semantic;

    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: semantic.warningContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: semantic.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 18,
            color: colors.onSurface,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              online
                  ? '$pendingCount $itemWord${pendingCount == 1 ? '' : 's'} on this device only — sending…'
                  : '$pendingCount $itemWord${pendingCount == 1 ? '' : 's'} on this device only — sends when internet is back.',
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (online && !syncing) ...[
            const SizedBox(width: Insets.sm),
            FilledButton.tonal(
              onPressed: () => syncNowAll(ref),
              child: const Text('Send now'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Slim grey strip above a cached table while offline: what you see is
/// the last saved copy, not live data. Only rendered when offline.
class OfflineCacheNote extends ConsumerWidget {
  const OfflineCacheNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    if (online) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: context.semantic.hairline),
      ),
      child: Row(
        children: [
          Icon(
            Icons.save_outlined,
            size: 18,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              'Offline — showing saved data from last time online.',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// Tiny "Sent ✓✓" line under a row's name, for rows safely on the
/// server. The mirror of [NotSentTag]: every offline-writable table shows
/// one or the other, so staff never guess. Shows in table and cards.
class SentTicks extends StatelessWidget {
  const SentTicks({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sent',
          style: context.text.labelSmall?.copyWith(
            color: context.semantic.success,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          Icons.done_all_rounded,
          size: 14,
          color: context.semantic.success,
        ),
      ],
    );
  }
}
/// Tiny "Not sent yet" tag under a row's name, for rows living on the
/// device only. Used inside table cells (sales, finance, customers) so it
/// shows in both the table and the mobile cards.
class NotSentTag extends StatelessWidget {
  const NotSentTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color:
            context.semantic.warningContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        'Not sent yet',
        style: context.text.labelSmall?.copyWith(
          color: context.colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
