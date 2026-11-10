import 'package:flutter/material.dart';

import '../../models/crochet_chart.dart';
import '../../models/pdf_export_data.dart';
import '../../state/app_state.dart';
import 'pdf_export_screen.dart';

Future<void> showChartPdfExport(
  BuildContext context,
  CrochetChart chart, {
  Map<String, ChartCellData>? cells,
  Map<int, String>? instructions,
}) async {
  try {
    final state = AppStateScope.of(context);
    final chartCells = cells ?? chart.cells;
    final chartInstructions = instructions ?? chart.instructions;
    final chartType = switch (chart.chartType) {
      ChartType.pixel => 'pixel',
      ChartType.stitchSymbols => 'stitch_symbols',
      ChartType.circular => 'circular',
    };

    final pdfCells = chartCells.values
        .map(
          (cell) => PdfGridCell(
            row: cell.row,
            column: cell.column,
            stitchCode: cell.stitchCode,
            colorHex: cell.colorHex,
          ),
        )
        .toList();
    final stitchMap = {
      for (final stitch in state.stitchTypes) stitch.code: stitch,
    };
    final pdfStitches = chartCells.values
        .map((cell) {
          final stitch = stitchMap[cell.stitchCode];
          return PdfChartStitch(
            code: cell.stitchCode,
            name: stitch?.name ?? cell.stitchCode,
            symbol: stitch?.symbol ?? cell.stitchCode,
            description: stitch?.description ?? '',
            x: cell.positionX ?? 0.5,
            y: cell.positionY ?? 0.5,
            sequence: cell.column,
            round: cell.row + 1,
          );
        })
        .toList();
    final pdfColors = state.yarnColors
        .map(
          (color) => PdfYarnColor(
            name: color.name,
            hexCode: color.hexCode,
            brand: color.brand,
            yarnCode: color.yarnCode,
          ),
        )
        .toList();
    final pdfInstructions = chartInstructions.entries
        .map((entry) {
          final order = entry.key + 1;
          return PdfInstruction(
            order: order,
            title: chart.chartType == ChartType.circular
                ? 'Vòng $order'
                : 'Hàng $order',
            content: entry.value,
          );
        })
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final pdfData = PdfExportData(
      name: chart.name,
      category: chart.category,
      description: chart.description,
      chartType: chartType,
      rows: chart.rowsCount,
      columns: chart.columnsCount,
      notes: chart.notes,
      cells: pdfCells,
      stitches: pdfStitches,
      yarnColors: pdfColors,
      instructions: pdfInstructions,
    );

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PdfExportScreen(data: pdfData)),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể xuất PDF: $error')),
    );
  }
}
