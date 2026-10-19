import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos/providers/connectivity_provider.dart';
import 'package:restaurant_pos/providers/outbox_status_provider.dart';
import 'package:restaurant_pos/theme/app_theme.dart';
import 'package:restaurant_pos/widgets/connection_status_pill.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool online = true,
  OutboxStatus outbox = OutboxStatus.idle,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        outboxStatusProvider.overrideWith((ref) => Stream.value(outbox)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('OutboxStatus', () {
    test('adds the four outboxes up', () {
      const status = OutboxStatus(
        pendingSales: 2,
        pendingExpenses: 1,
        pendingIncomes: 0,
        pendingCustomers: 3,
      );

      expect(status.total, 6);
      expect(status.hasPending, isTrue);
    });

    test('idle has nothing waiting', () {
      expect(OutboxStatus.idle.total, 0);
      expect(OutboxStatus.idle.hasPending, isFalse);
    });

    test('never synced counts as stale', () {
      expect(OutboxStatus.idle.isStale, isTrue);
      expect(OutboxStatus.idle.staleDays, -1);
    });

    test('a sync an hour ago is fresh', () {
      final status = OutboxStatus(
        lastSynced: DateTime.now().subtract(const Duration(hours: 1)),
      );

      expect(status.isStale, isFalse);
    });

    test('a sync two days ago is stale', () {
      final status = OutboxStatus(
        lastSynced: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(status.isStale, isTrue);
      expect(status.staleDays, 2);
    });
  });

  group('lastSyncedLabel', () {
    test('never synced yet', () {
      expect(lastSyncedLabel(null), 'Never synced yet');
    });

    test('today and yesterday read plainly', () {
      final now = DateTime.now();
      expect(
        lastSyncedLabel(now.subtract(const Duration(hours: 2))),
        startsWith('Today'),
      );
      expect(
        lastSyncedLabel(now.subtract(const Duration(days: 1, hours: 2))),
        startsWith('Yesterday'),
      );
      expect(
        lastSyncedLabel(now.subtract(const Duration(days: 3))),
        startsWith('3 days ago'),
      );
    });
  });

  group('ConnectionStatusPill', () {
    testWidgets('shows Online when connected and all sent', (tester) async {
      await _pump(
        tester,
        const ConnectionStatusPill(),
        outbox: OutboxStatus(
          lastSynced: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('shows Offline when disconnected', (tester) async {
      await _pump(tester, const ConnectionStatusPill(), online: false);

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('shows the waiting count when items are pending',
        (tester) async {
      await _pump(
        tester,
        const ConnectionStatusPill(),
        outbox: const OutboxStatus(pendingSales: 2, pendingCustomers: 1),
      );

      expect(find.text('Online · 3 not sent'), findsOneWidget);
    });

    testWidgets('warns when the last sync is more than a day old',
        (tester) async {
      await _pump(
        tester,
        const ConnectionStatusPill(),
        outbox: OutboxStatus(
          lastSynced: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );

      expect(find.text('Not synced 2 d'), findsOneWidget);
    });

    testWidgets('tapping the pill opens the sync status sheet',
        (tester) async {
      await _pump(tester, const ConnectionStatusPill());

      await tester.tap(find.byType(ConnectionStatusPill));
      await tester.pumpAndSettle();

      expect(find.text('Sync status'), findsOneWidget);
      expect(find.textContaining('Last synced:'), findsOneWidget);
      expect(find.text('Sales'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
    });

    testWidgets('stale sheet warns to catch up', (tester) async {
      await _pump(
        tester,
        const ConnectionStatusPill(),
        outbox: OutboxStatus(
          lastSynced: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );

      await tester.tap(find.byType(ConnectionStatusPill));
      await tester.pumpAndSettle();

      expect(find.textContaining('Not synced for 3 days'), findsOneWidget);
      expect(find.text('Send now'), findsOneWidget);
    });

    testWidgets('offline sheet explains nothing can be sent', (tester) async {
      await _pump(
        tester,
        const ConnectionStatusPill(),
        online: false,
      );

      await tester.tap(find.byType(ConnectionStatusPill));
      await tester.pumpAndSettle();

      expect(find.text('Offline'), findsWidgets);
      expect(find.text('Send now'), findsNothing);
    });
  });

  group('PendingSyncBanner', () {
    testWidgets('renders nothing when everything is sent', (tester) async {
      await _pump(
        tester,
        const PendingSyncBanner(pendingCount: 0, itemWord: 'sale'),
      );

      expect(find.textContaining('on this device only'), findsNothing);
    });

    testWidgets('counts waiting rows in plain words', (tester) async {
      await _pump(
        tester,
        const PendingSyncBanner(pendingCount: 2, itemWord: 'sale'),
      );

      expect(
        find.text('2 sales on this device only — sending…'),
        findsOneWidget,
      );
      expect(find.text('Send now'), findsOneWidget);
    });

    testWidgets('offline says it sends when internet is back', (tester) async {
      await _pump(
        tester,
        const PendingSyncBanner(pendingCount: 1, itemWord: 'expense'),
        online: false,
      );

      expect(
        find.text(
          '1 expense on this device only — sends when internet is back.',
        ),
        findsOneWidget,
      );
      expect(find.text('Send now'), findsNothing);
    });
  });

  group('NotSentTag', () {
    testWidgets('reads "Not sent yet"', (tester) async {
      await _pump(tester, const NotSentTag());

      expect(find.text('Not sent yet'), findsOneWidget);
    });
  });

  group('SentTicks', () {
    testWidgets('reads "Sent" with double ticks', (tester) async {
      await _pump(tester, const SentTicks());

      expect(find.text('Sent'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    });
  });

  group('OfflineCacheNote', () {
    testWidgets('hidden while online', (tester) async {
      await _pump(tester, const OfflineCacheNote());

      expect(find.textContaining('showing saved data'), findsNothing);
    });

    testWidgets('shown while offline', (tester) async {
      await _pump(tester, const OfflineCacheNote(), online: false);

      expect(find.textContaining('showing saved data'), findsOneWidget);
    });
  });
}
