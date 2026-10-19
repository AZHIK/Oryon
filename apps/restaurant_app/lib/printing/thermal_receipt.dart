import 'dart:convert';

import '../models/order.dart';
import '../utils/formatters.dart';

/// Fixed-width line model for an 80mm thermal receipt.
///
/// The receipt is built as [ThermalLine]s — not raw ESC/POS bytes — so the
/// same model feeds the on-screen paper preview and, later, a real encoder:
/// `text` maps to print-text commands (with [bold]/[align]), `rule` to a
/// separator, and `qr` to the printer's native QR command (GS ( k), *not* a
/// rasterised image, which is slow and often too wide for the paper).
enum ThermalAlign { left, center, right }

enum ThermalLineKind { text, rule, blank, qr }

/// One printable row.
///
/// For [ThermalLineKind.qr], [text] carries the encoded payload.
///
/// [big] marks double-size rows (e.g. a coupon's items): the preview renders
/// them large, and a printer encoder maps them to the double height/width
/// command. The plain-text renderer re-wraps them to half the columns, since
/// double-size glyphs only fit half a row.
///
/// Immutable by construction — all fields are final.
class ThermalLine {
  const ThermalLine.text(
    this.text, {
    this.align = ThermalAlign.left,
    this.bold = false,
    this.big = false,
  }) : kind = ThermalLineKind.text;

  const ThermalLine.rule() : this._( '', ThermalLineKind.rule);

  const ThermalLine.blank() : this._('', ThermalLineKind.blank);

  const ThermalLine.qr(this.text)
    : kind = ThermalLineKind.qr,
      align = ThermalAlign.center,
      bold = false,
      big = false;

  const ThermalLine._(this.text, this.kind)
    : align = ThermalAlign.left,
      bold = false,
      big = false;

  final String text;
  final ThermalLineKind kind;
  final ThermalAlign align;
  final bool bold;
  final bool big;
}

/// Builds the standard store receipt:
///
/// store name → contacts → order block (with order + receipt numbers) →
/// items → totals → payment → thank-you note → QR (all receipt data except
/// the welcome note).
///
/// [lineWidth] is the paper's fixed column count: 42 for 80mm, 32 for 58mm.
/// Every emitted text line fits it — the unit test pins that.
List<ThermalLine> buildThermalReceipt({
  required Order order,
  required String storeName,
  required String receiptNumber,
  String? phone,
  String? email,
  List<String> addressLines = const [],
  String? taxId,
  String welcomeNote = 'Thank you, welcome again!',
  int lineWidth = ThermalReceipt.lineWidth,
}) {
  final lines = <ThermalLine>[];

  // ——— Store header ———
  for (final wrapped in wrapThermalText(storeName, lineWidth)) {
    lines.add(
      ThermalLine.text(wrapped, align: ThermalAlign.center, bold: true),
    );
  }
  for (final address in addressLines) {
    for (final wrapped in wrapThermalText(address, lineWidth)) {
      lines.add(ThermalLine.text(wrapped, align: ThermalAlign.center));
    }
  }
  if (phone != null && phone.trim().isNotEmpty) {
    lines.add(
      ThermalLine.text('Tel: ${phone.trim()}', align: ThermalAlign.center),
    );
  }
  if (email != null && email.trim().isNotEmpty) {
    lines.add(ThermalLine.text(email.trim(), align: ThermalAlign.center));
  }
  // TIN only when this sale actually charged tax — tax switch off means
  // nothing about tax anywhere on the paper.
  if (taxId != null && taxId.trim().isNotEmpty && order.taxRate > 0) {
    lines.add(
      ThermalLine.text('TIN: ${taxId.trim()}', align: ThermalAlign.center),
    );
  }
  lines.add(const ThermalLine.rule());

  // ——— Order block ———
  lines.add(ThermalLine.text('Order No: ${order.id}'));
  lines.add(ThermalLine.text('Receipt : $receiptNumber'));
  lines.add(ThermalLine.text('Date    : ${Fmt.dayMonthTime(order.placedAt)}'));
  lines.add(ThermalLine.text('Server  : ${order.serverName}'));
  if (order.tableLabel != null && order.tableLabel!.trim().isNotEmpty) {
    lines.add(ThermalLine.text('Table   : ${order.tableLabel!.trim()}'));
  }
  lines.add(ThermalLine.text('Type    : ${order.orderType.label}'));
  lines.add(const ThermalLine.rule());

  // ——— Items ———
  for (final line in order.lines) {
    final name = '${line.name} x${line.quantity}';
    for (final wrapped in wrapThermalText(name, lineWidth)) {
      lines.add(ThermalLine.text(wrapped));
    }
    lines.add(
      ThermalLine.text(
        _pair(
          '  ${line.quantity} x ${Fmt.money(line.unitPrice)}',
          Fmt.money(line.lineTotal),
          lineWidth,
        ),
      ),
    );
  }
  lines.add(const ThermalLine.rule());

  // ——— Totals ———
  lines.add(
    ThermalLine.text(
      _pair('Subtotal', Fmt.money(order.subtotal), lineWidth),
    ),
  );
  if (order.discountRate > 0) {
    lines.add(
      ThermalLine.text(
        _pair(
          'Discount (${Fmt.percent(order.discountRate)})',
          '-${Fmt.money(order.discount)}',
          lineWidth,
        ),
      ),
    );
  }
  if (order.taxRate > 0) {
    lines.add(
      ThermalLine.text(
        _pair(
          'Tax (${Fmt.percent(order.taxRate)})',
          Fmt.money(order.tax),
          lineWidth,
        ),
      ),
    );
  }
  lines.add(
    ThermalLine.text(
      _pair('TOTAL', Fmt.money(order.total), lineWidth),
      bold: true,
    ),
  );
  lines.add(const ThermalLine.rule());

  // ——— Payment ———
  lines.add(ThermalLine.text('Paid by ${order.paymentType.label}'));
  final tendered = order.amountTendered;
  if (tendered != null) {
    lines.add(
      ThermalLine.text(
        _pair('Tendered', Fmt.money(tendered), lineWidth),
      ),
    );
    final change = order.payment.changeFor(order.totals);
    if (change != null && change > 0) {
      lines.add(
        ThermalLine.text(_pair('Change', Fmt.money(change), lineWidth)),
      );
    }
  }
  lines.add(const ThermalLine.rule());

  // ——— Farewell + QR ———
  for (final wrapped in wrapThermalText(welcomeNote, lineWidth)) {
    lines.add(ThermalLine.text(wrapped, align: ThermalAlign.center));
  }
  lines.add(const ThermalLine.blank());
  lines.add(
    ThermalLine.qr(
      thermalReceiptQrPayload(
        order: order,
        storeName: storeName,
        receiptNumber: receiptNumber,
        phone: phone,
        email: email,
        addressLines: addressLines,
        taxId: taxId,
      ),
    ),
  );
  lines.add(const ThermalLine.blank());
  lines.add(
    const ThermalLine.text(
      'Scan to verify receipt',
      align: ThermalAlign.center,
    ),
  );

  return lines;
}

/// The QR payload: every receipt field a verifier needs, machine-readable.
///
/// Deliberately excludes the welcome note — it is decoration, not data.
String thermalReceiptQrPayload({
  required Order order,
  required String storeName,
  required String receiptNumber,
  String? phone,
  String? email,
  List<String> addressLines = const [],
  String? taxId,
}) {
  final tendered = order.amountTendered;
  final change = order.payment.changeFor(order.totals);
  final payment = <String, Object>{'method': order.paymentType.name};
  if (tendered != null) {
    payment['tendered'] = tendered;
    if (change != null && change > 0) payment['change'] = change;
  }
  return jsonEncode({
    'v': 1,
    'store': {
      'name': storeName,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (addressLines.isNotEmpty) 'address': addressLines,
      if (taxId != null && taxId.trim().isNotEmpty) 'taxId': taxId.trim(),
    },
    'order': {
      'orderNo': order.id,
      'receiptNo': receiptNumber,
      'placedAt': order.placedAt.toIso8601String(),
      'server': order.serverName,
      if (order.tableLabel != null && order.tableLabel!.trim().isNotEmpty)
        'table': order.tableLabel!.trim(),
      'type': order.orderType.name,
    },
    'lines': [
      for (final line in order.lines)
        {
          'name': line.name,
          'qty': line.quantity,
          'unit': line.unitPrice,
          'total': line.lineTotal,
        },
    ],
    'totals': {
      'subtotal': order.subtotal,
      'discountRate': order.discountRate,
      'discount': order.discount,
      'taxRate': order.taxRate,
      'tax': order.tax,
      'total': order.total,
    },
    'payment': payment,
  });
}

/// Renders [lines] to fixed-width plain text — what an ESC/POS encoder (or a
/// log) consumes. The `qr` line is emitted as a `{QR:...}` marker carrying
/// the payload; the encoder maps it to the printer's QR command.
String renderThermalText(
  List<ThermalLine> lines, {
  int lineWidth = ThermalReceipt.lineWidth,
}) {
  final out = StringBuffer();
  for (final line in lines) {
    switch (line.kind) {
      case ThermalLineKind.blank:
        out.writeln();
      case ThermalLineKind.rule:
        out.writeln('-' * lineWidth);
      case ThermalLineKind.qr:
        out.writeln('{QR:${line.text}}');
      case ThermalLineKind.text:
        // Double-size glyphs fit half the columns: re-wrap, then centre the
        // short rows across the full paper so they sit where the eye expects.
        final columns = line.big ? lineWidth ~/ 2 : lineWidth;
        for (final row in wrapThermalText(line.text, columns)) {
          out.writeln(_aligned(row, lineWidth, line.align));
        }
    }
  }
  return out.toString();
}

/// Paper geometry. 80mm paper at the common font-A pitch fits 42 readable
/// columns; 58mm fits 32.
abstract final class ThermalReceipt {
  static const int lineWidth = 42;
  static const int narrowLineWidth = 32;
}

/// Left/right pair on one row: label hugs the left, value the right. A label
/// too long to share the row is truncated — callers wrap names beforehand.
String _pair(String left, String right, int width) {
  if (left.length + right.length + 1 <= width) {
    return '$left${' ' * (width - left.length - right.length)}$right';
  }
  final room = width - right.length - 1;
  final trimmed = room > 0 ? left.substring(0, room) : '';
  return '$trimmed $right';
}

String _aligned(String text, int width, ThermalAlign align) {
  final single = text.length > width ? text.substring(0, width) : text;
  switch (align) {
    case ThermalAlign.left:
      return single;
    case ThermalAlign.center:
      final pad = width - single.length;
      final left = pad ~/ 2;
      return '${' ' * left}$single${' ' * (pad - left)}';
    case ThermalAlign.right:
      return '${' ' * (width - single.length)}$single';
  }
}

/// Greedy word wrap; a single over-long word is hard-split so output never
/// exceeds [width].
List<String> wrapThermalText(String text, int width) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final rows = <String>[];
  var current = StringBuffer();
  for (final word in words) {
    var rest = word;
    while (rest.length > width) {
      if (current.isNotEmpty) {
        rows.add(current.toString());
        current = StringBuffer();
      }
      rows.add(rest.substring(0, width));
      rest = rest.substring(width);
    }
    if (current.isEmpty) {
      current.write(rest);
    } else if (current.length + 1 + rest.length <= width) {
      current.write(' $rest');
    } else {
      rows.add(current.toString());
      current = StringBuffer()..write(rest);
    }
  }
  if (current.isNotEmpty) rows.add(current.toString());
  return rows;
}
