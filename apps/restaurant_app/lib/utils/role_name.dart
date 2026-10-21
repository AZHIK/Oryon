/// Turns a backend role identifier into something people can read.
///
/// Seed roles arrive as snake_case (`restaurant_owner`, `store_manager`), and
/// those underscores should never reach the UI. Names that are already human
/// — `Cashier`, `Shift supervisor`, anything with spaces — are returned
/// unchanged, so a role someone named themselves keeps its own casing.
String humanizeRoleName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return trimmed;
  if (!trimmed.contains('_') && !trimmed.contains('-')) return trimmed;

  return trimmed
      .split(RegExp(r'[_-]+'))
      .where((word) => word.isNotEmpty)
      .map(_capitalize)
      .join(' ');
}

String _capitalize(String word) => word.length == 1
    ? word.toUpperCase()
    : '${word[0].toUpperCase()}${word.substring(1)}';
