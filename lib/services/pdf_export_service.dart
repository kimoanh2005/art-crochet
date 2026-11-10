import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/pdf_export_data.dart';

class PdfExportService {
  Future<Uint8List> generate(PdfExportData data) async {
    final regular = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();

    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final isWide = data.chartType == 'pixel'
        ? data.columns > data.rows
        : data.chartType == 'circular';

    final pageFormat = PdfPageFormat.a4;

    document.addPage(
      pw.MultiPage(
        pageFormat: isWide ? pageFormat.landscape : pageFormat,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _header(data),
        footer: (context) => _footer(context),
        build: (context) {
          return [
            _information(data),
            pw.SizedBox(height: 16),
            ..._buildChart(data),
            pw.SizedBox(height: 18),
            _buildLegend(data),
            if (data.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              _buildNotes(data.notes),
            ],
          ];
        },
      ),
    );

    return document.save();
  }

  pw.Widget _header(PdfExportData data) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.pink300, width: 1.2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'ART CROCHET',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.pink700,
            ),
          ),
          pw.Text('CROCHET PATTERN', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Trang ${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _information(PdfExportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          data.name,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.brown800,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Danh mục: ${data.category}'),
        if (data.description.trim().isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(data.description),
        ],
        pw.SizedBox(height: 5),
        pw.Text(
          'Loại biểu đồ: ${_typeName(data.chartType)}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  String _typeName(String type) {
    switch (type) {
      case 'pixel':
        return 'Pixel';
      case 'stitch_symbols':
        return 'Ký hiệu mũi móc';
      case 'circular':
        return 'Biểu đồ tròn';
      default:
        return type;
    }
  }

  List<pw.Widget> _buildChart(PdfExportData data) {
    switch (data.chartType) {
      case 'pixel':
        return _buildPixelChart(data);
      case 'stitch_symbols':
        return [_buildSymbolChart(data)];
      case 'circular':
        return [_buildCircularChart(data)];
      default:
        return [pw.Text('Loại biểu đồ chưa được hỗ trợ.')];
    }
  }

  List<pw.Widget> _buildPixelChart(PdfExportData data) {
    if (data.rows <= 0 || data.columns <= 0) {
      return [pw.Text('Biểu đồ chưa có kích thước hợp lệ.')];
    }

    final cellMap = <String, PdfGridCell>{};

    for (final cell in data.cells) {
      cellMap['${cell.row}_${cell.column}'] = cell;
    }

    final result = <pw.Widget>[];

    result.add(
      pw.Text(
        'Biểu đồ Pixel: ${data.rows} hàng × ${data.columns} cột',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );

    result.add(pw.SizedBox(height: 8));

    const rowsPerSection = 20;

    for (var startRow = 0; startRow < data.rows; startRow += rowsPerSection) {
      final endRow = math.min(startRow + rowsPerSection, data.rows);

      final tableRows = <pw.TableRow>[];

      for (var row = startRow; row < endRow; row++) {
        final cells = <pw.Widget>[];

        cells.add(
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(2),
            child: pw.Text(
              '${row + 1}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
        );

        for (var column = 0; column < data.columns; column++) {
          final cell = cellMap['${row}_${column}'];
          final color = _pdfColor(cell?.colorHex ?? '#FFFFFF');

          cells.add(
            pw.Container(
              height: 18,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: color,
                border: pw.Border.all(color: PdfColors.grey600, width: 0.35),
              ),
              child: pw.Text(
                cell?.stitchCode ?? '',
                style: const pw.TextStyle(fontSize: 5),
              ),
            ),
          );
        }

        tableRows.add(pw.TableRow(children: cells));
      }

      final headerCells = <pw.Widget>[
        pw.Container(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'H',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ];

      for (var column = 0; column < data.columns; column++) {
        headerCells.add(
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(2),
            child: pw.Text(
              '${column + 1}',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ),
        );
      }

      result.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.35),
          columnWidths: {0: const pw.FixedColumnWidth(20)},
          children: [
            pw.TableRow(children: headerCells),
            ...tableRows,
          ],
        ),
      );

      result.add(pw.SizedBox(height: 10));
    }

    return result;
  }

  pw.Widget _buildSymbolChart(PdfExportData data) {
    if (data.stitches.isEmpty) {
      return pw.Text('Biểu đồ chưa có ký hiệu mũi móc.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Biểu đồ ký hiệu mũi móc',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 430,
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500),
          ),
          child: pw.Stack(
            children: data.stitches.map((stitch) {
              final x = stitch.x.clamp(0.0, 1.0);
              final y = stitch.y.clamp(0.0, 1.0);

              return pw.Positioned(
                left: x * 420,
                top: y * 410,
                child: pw.Text(
                  stitch.symbol,
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildCircularChart(PdfExportData data) {
    if (data.stitches.isEmpty) {
      return pw.Text('Biểu đồ tròn chưa có ký hiệu.');
    }

    const chartSize = 420.0;

    final maxRound = data.stitches.fold<int>(
      1,
      (previous, stitch) => math.max(previous, stitch.round),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Biểu đồ tròn - $maxRound vòng',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: chartSize,
          width: chartSize,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500),
          ),
          child: pw.Stack(
            children: [
              for (var round = 1; round <= maxRound; round++)
                pw.Center(
                  child: pw.Container(
                    width: chartSize * round / maxRound,
                    height: chartSize * round / maxRound,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(
                        color: PdfColors.grey400,
                        width: 0.7,
                      ),
                    ),
                  ),
                ),
              ...data.stitches.map((stitch) {
                final x = stitch.x.clamp(0.0, 1.0);
                final y = stitch.y.clamp(0.0, 1.0);

                return pw.Positioned(
                  left: x * chartSize - 6,
                  top: y * chartSize - 6,
                  child: pw.Text(
                    stitch.symbol,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildLegend(PdfExportData data) {
    final children = <pw.Widget>[];

    // 1. Lọc chỉ lấy các màu len thực sự được dùng trong chart
    final usedHexCodes = <String>{};
    for (final cell in data.cells) {
      if (cell.colorHex.trim().isNotEmpty) {
        usedHexCodes.add(cell.colorHex.trim().toLowerCase());
      }
    }

    final filteredYarnColors = data.yarnColors.where((yarn) {
      return usedHexCodes.contains(yarn.hexCode.trim().toLowerCase());
    }).toList();

    if (filteredYarnColors.isNotEmpty) {
      children.add(
        pw.Text(
          'CHÚ GIẢI MÀU LEN',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );

      children.add(pw.SizedBox(height: 7));

      for (final yarn in filteredYarnColors) {
        children.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 16,
                  height: 16,
                  decoration: pw.BoxDecoration(
                    color: _pdfColor(yarn.hexCode),
                    border: pw.Border.all(color: PdfColors.grey600),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    '${yarn.name}'
                    '${yarn.brand.isNotEmpty ? ' - ${yarn.brand}' : ''}'
                    '${yarn.yarnCode.isNotEmpty ? ' (${yarn.yarnCode})' : ''}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 2. Lọc chỉ lấy các ký hiệu mũi móc thực sự được dùng trong chart
    final usedStitchCodes = <String>{};
    for (final cell in data.cells) {
      if (cell.stitchCode.trim().isNotEmpty) {
        usedStitchCodes.add(cell.stitchCode.trim());
      }
    }
    for (final stitch in data.stitches) {
      if (stitch.code.trim().isNotEmpty) {
        usedStitchCodes.add(stitch.code.trim());
      }
    }

    final filteredStitches = data.stitches.where((stitch) {
      return usedStitchCodes.contains(stitch.code.trim());
    }).toList();

    // Đảm bảo không bị trùng lặp mã ký hiệu
    final uniqueStitches = <String, PdfChartStitch>{};
    for (final stitch in filteredStitches) {
      uniqueStitches.putIfAbsent(stitch.code, () => stitch);
    }

    if (uniqueStitches.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(pw.SizedBox(height: 10));
      }
      children.add(
        pw.Text(
          'CHÚ GIẢI KÝ HIỆU',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );

      for (final stitch in uniqueStitches.values) {
        children.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 28,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    stitch.symbol,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    '${stitch.name} (${stitch.code})'
                    '${stitch.description.isNotEmpty ? ' - ${stitch.description}' : ''}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (children.isEmpty) {
      return pw.Text('Chưa có dữ liệu chú giải.');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    );
  }

  pw.Widget _buildNotes(String notes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'GHI CHÚ',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(notes, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  PdfColor _pdfColor(String hex) {
    try {
      var value = hex.replaceAll('#', '').trim();

      if (value.length == 6) {
        value = 'FF$value';
      }

      if (value.length != 8) {
        return PdfColors.white;
      }

      final parsed = int.parse(value, radix: 16);

      return PdfColor(
        ((parsed >> 16) & 255) / 255,
        ((parsed >> 8) & 255) / 255,
        (parsed & 255) / 255,
        ((parsed >> 24) & 255) / 255,
      );
    } catch (_) {
      return PdfColors.white;
    }
  }
}