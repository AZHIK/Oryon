import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:restaurant_pos/providers/preferences_provider.dart';
import 'package:restaurant_pos/providers/settings_provider.dart';

void main() {
  group('App preference state', () {
    test('theme mode can be set and cycled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);
      container.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).cycle();
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('density changes the table spacing values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(tableDensityProvider), TableDensity.comfortable);
      container.read(tableDensityProvider.notifier).set(TableDensity.compact);

      expect(container.read(tableDensityProvider), TableDensity.compact);
      expect(
        TableDensity.compact.rowPadding,
        lessThan(TableDensity.comfortable.rowPadding),
      );
    });

    test('notification preferences preserve independent values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationPrefsProvider.notifier);
      notifier.setDailySummary(true);

      expect(container.read(notificationPrefsProvider).dailySummary, isTrue);
      expect(container.read(notificationPrefsProvider).lowStock, isTrue);
      expect(container.read(notificationPrefsProvider).orderSounds, isTrue);
    });
  });
}
