import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../widgets/data_page/data_column_spec.dart';
import 'export_exceptions.dart';
import 'file_sink.dart';

/// Outcome of an export, so the caller can report it without knowing anything
/// about files or platforms.
@immutable
class ExportResult {
  const ExportResult._({
    required this.ok,
    required this.message,
    this.path,
    this.cancelled = false,
  });

  const ExportResult.success(String message, {String? path})
    : this._(ok: true, message: message, path: path);

  const ExportResult.failure(String message) : this._(ok: false, message: message);

  /// The user dismissed the save dialog. Not a success and not an error —
  /// reporting it as a failure would put a red banner in front of someone who
  /// simply changed their mind.
  const ExportResult.cancelled()
    : this._(ok: false, message: 'Export cancelled', cancelled: true);

  final bool ok;
  final String message;
  final bool cancelled;

  /// Where the file landed, when the platform reports it. Web downloads and
  /// share sheets have no path to give.
  final String? path;
}

/// Exports any data page's table.
///
/// Both functions take the page's [DataColumnSpec] list, so the export is
/// generated from the same definitions that drive the screen — the same
/// columns, the same order, the same formatting. Rows are passed in already
/// filtered and sorted, which is what makes the file match what the user is
/// looking at rather than the whole table.
abstract final class ExportHelper {
  static final _timestamp = DateFormat('yyyy-MM-dd_HHmm');
  static final _generatedAt = DateFormat('d MMMM y, h:mm a');

  /// Cached so a second export does not re-parse the font file.
  static pw.ThemeData? _pdfTheme;
  static bool _pdfThemeAttempted = false;

  /// Overridable so a test can point at a missing asset and prove the
  /// fallback path really does produce a document.
  @visibleForTesting
  static String fontAssetKey = 'assets/fonts/Inter.ttf';

  /// Loads the app's Inter for the PDF.
  ///
  /// The `pdf` package's built-in Helvetica is Latin-1 only, so anything
  /// outside it — the "·" and "–" in an export subtitle, an accented item
  /// name, a "£" — silently drops out with a "no Unicode support" warning.
  /// Embedding the font the app already ships fixes that for every glyph the
  /// screen can display.
  ///
  /// Returns null when the asset bundle is unavailable (a plain unit test, for
  /// instance); the caller then falls back to the built-in fonts rather than
  /// failing the export outright.
  static Future<pw.ThemeData?> _loadPdfTheme() async {
    if (_pdfThemeAttempted) return _pdfTheme;
    _pdfThemeAttempted = true;

    try {
      final data = await rootBundle.load(fontAssetKey);
      final font = pw.Font.ttf(data);
      // Inter ships as a variable font, so one instance stands in for every
      // weight. Header emphasis comes from the filled row behind it instead.
      _pdfTheme = pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
      );
    } catch (error, stack) {
      // Never silently: a swallowed failure here is invisible except as a
      // "Helvetica has no Unicode support" line from deep inside the pdf
      // package, which says nothing about the actual cause.
      _pdfTheme = null;
      debugPrint(
        'Export: could not load "$fontAssetKey" for the PDF — falling back to '
        'built-in fonts, so non-Latin-1 characters will not render. $error',
      );
      assert(() {
        debugPrintStack(stackTrace: stack, maxFrames: 6);
        return true;
      }());
    }
    return _pdfTheme;
  }

  /// Test seam: forces the next export to re-attempt font loading.
  @visibleForTesting
  static void resetPdfTheme() {
    _pdfTheme = null;
    _pdfThemeAttempted = false;
  }

  // -------------------------------------------------------------------------
  // Document generation — pure, no file system, so it is testable directly.
  // -------------------------------------------------------------------------

  /// Builds a simple tabular PDF: title, generated-date, then the table.
  static Future<Uint8List> buildPdfBytes<T>({
    required List<DataColumnSpec<T>> columns,
    required List<T> rows,
    required String title,
    String? subtitle,
    DateTime? generatedAt,
  }) async {
    final now = generatedAt ?? DateTime.now();
    final theme = await _loadPdfTheme();
    final document = pw.Document(title: title, theme: theme);

    document.addPage(
      pw.MultiPage(
        theme: theme,
        // Data tables are wider than they are tall; portrait would waste the
        // page and squeeze the columns.
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => context.pageNumber == 1
            ? _pdfHeader(title, subtitle, now)
            : pw.SizedBox(),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: [for (final column in columns) column.label],
            data: [
              for (final row in rows)
                [for (final column in columns) column.value(row)],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0B6B57),
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            // Zebra striping survives a monochrome printer, which colour
            // alone would not.
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF3F6F5),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
            headerAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              for (var i = 0; i < columns.length; i++)
                if (columns[i].numeric) i: pw.Alignment.centerRight,
            },
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColors.grey300,
                width: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            '${rows.length} ${rows.length == 1 ? 'row' : 'rows'}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _pdfHeader(String title, String? subtitle, DateTime now) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (subtitle != null)
                pw.Text(
                  subtitle,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
            ],
          ),
          pw.Text(
            'Generated ${_generatedAt.format(now)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  /// Builds an .xlsx with a header row followed by the data rows.
  ///
  /// Numeric columns are written as numbers rather than text, so the sheet can
  /// be summed without the reader having to re-type a column first.
  static Uint8List buildExcelBytes<T>({
    required List<DataColumnSpec<T>> columns,
    required List<T> rows,
    required String title,
  }) {
    final workbook = Excel.createExcel();
    final sheetName = workbook.getDefaultSheet() ?? 'Sheet1';
    final sheet = workbook[sheetName];

    sheet.appendRow([
      for (final column in columns) TextCellValue(column.label),
    ]);

    for (final row in rows) {
      sheet.appendRow([
        for (final column in columns) _cellFor(column, row),
      ]);
    }

    final encoded = workbook.encode();
    if (encoded == null) {
      throw StateError('The spreadsheet could not be encoded');
    }
    return Uint8List.fromList(encoded);
  }

  /// Recovers a number from a formatted string where the column is numeric,
  /// falling back to text when it is not really a number ("42 kg").
  static CellValue _cellFor<T>(DataColumnSpec<T> column, T row) {
    final text = column.value(row);
    if (!column.numeric) return TextCellValue(text);

    final cleaned = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-') return TextCellValue(text);

    final number = double.tryParse(cleaned);
    if (number == null) return TextCellValue(text);

    // Only treat it as numeric if nothing but the formatting was stripped —
    // "42 kg" keeps its unit rather than silently becoming 42. A leading
    // currency symbol ("TSh22", "$22") is formatting, not a unit, so the
    // check runs on the text after it.
    final body = text.replaceFirst(RegExp(r'^[^0-9.\-]+'), '');
    final hasTrailingUnit = RegExp(r'[a-zA-Z]').hasMatch(body);
    if (hasTrailingUnit) return TextCellValue(text);

    return number == number.roundToDouble() && !text.contains('.')
        ? IntCellValue(number.round())
        : DoubleCellValue(number);
  }

  // -------------------------------------------------------------------------
  // Save — the only part that touches the platform.
  // -------------------------------------------------------------------------

  static Future<ExportResult> exportToPdf<T>({
    required List<DataColumnSpec<T>> columns,
    required List<T> rows,
    required String title,
    String? subtitle,
  }) async {
    if (rows.isEmpty) {
      return const ExportResult.failure('Nothing to export — no rows match');
    }

    try {
      final bytes = await buildPdfBytes(
        columns: columns,
        rows: rows,
        title: title,
        subtitle: subtitle,
      );
      return await _save(
        bytes: bytes,
        title: title,
        extension: 'pdf',
        label: 'PDF',
      );
    } catch (error) {
      return ExportResult.failure('Could not build the PDF: $error');
    }
  }

  static Future<ExportResult> exportToExcel<T>({
    required List<DataColumnSpec<T>> columns,
    required List<T> rows,
    required String title,
  }) async {
    if (rows.isEmpty) {
      return const ExportResult.failure('Nothing to export — no rows match');
    }

    try {
      final bytes = buildExcelBytes(
        columns: columns,
        rows: rows,
        title: title,
      );
      return await _save(
        bytes: bytes,
        title: title,
        extension: 'xlsx',
        label: 'Excel',
      );
    } catch (error) {
      return ExportResult.failure('Could not build the spreadsheet: $error');
    }
  }

  /// Puts the file where the user wants it.
  ///
  /// Desktop gets a native "Save as" dialog, so the person exporting chooses
  /// the folder and the name. Phones have no such dialog: the file is written
  /// to the app's own storage and then offered to the share sheet, which is
  /// where "Save to Files" lives on those platforms.
  ///
  /// The directory cascade behind [writeExportFile] stays as the fallback for
  /// when no dialog is available — including the case that started all this,
  /// where `getDownloadsDirectory` throws "Functionality only available on
  /// macOS" because a platform implementation has not registered.
  static Future<ExportResult> _save({
    required Uint8List bytes,
    required String title,
    required String extension,
    required String label,
  }) async {
    final fileName =
        '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}'
        '_${_timestamp.format(DateTime.now())}.$extension';

    try {
      if (supportsSaveDialog) {
        try {
          final chosen = await pickSaveLocation(
            suggestedName: fileName,
            extension: extension,
            typeLabel: label,
          );
          if (chosen == null) return const ExportResult.cancelled();

          await writeBytesTo(chosen, bytes);
          return ExportResult.success('$label saved', path: chosen);
        } on SaveDialogUnavailable {
          // No dialog after all — carry on and choose a location below, but
          // say so, or a missing plugin looks like a missing feature.
          debugPrint(
            'Export: no save dialog available on this platform build — the '
            'file_selector plugin is not registered. Falling back to an '
            'automatic location. A full restart is needed after adding a '
            'plugin; hot restart cannot register one.',
          );
        }
      }

      final path = await writeExportFile(bytes, fileName);

      if (path == null) {
        return ExportResult.failure(
          '$label export is not available on this platform',
        );
      }

      if (sharesAfterSave) {
        // On a phone the app's own directories are not browsable, so the
        // share sheet is the only way the user reaches the file. A failure
        // here is not fatal — the file is already written.
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(path)],
              subject: '$title export',
              text: '$title exported from the POS',
            ),
          );
          return ExportResult.success('$label ready to share', path: path);
        } catch (_) {
          return ExportResult.success('$label saved', path: path);
        }
      }

      return ExportResult.success('$label saved', path: path);
    } catch (error) {
      return ExportResult.failure('Could not save the $label file: $error');
    }
  }
}
