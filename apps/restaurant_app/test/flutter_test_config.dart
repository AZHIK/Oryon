import 'dart:async';

import 'package:restaurant_pos/config/api_config.dart';

/// Keep the widget/unit suite hermetic: debug builds default to the deployed
/// Oryon Foods APIs, but tests must always use the local service defaults.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ApiConfig.useLocalDefaultsForTests = true;
  await testMain();
}
