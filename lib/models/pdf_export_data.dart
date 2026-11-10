class PdfExportData {
  final String name;
  final String category;
  final String description;
  final String chartType;
  final int rows;
  final int columns;
  final String notes;

  final List<PdfGridCell> cells;
  final List<PdfChartStitch> stitches;
  final List<PdfYarnColor> yarnColors;
  final List<PdfInstruction> instructions;

  const PdfExportData({
    required this.name,
    required this.category,
    this.description = '',
    required this.chartType,
    this.rows = 0,
    this.columns = 0,
    this.notes = '',
    this.cells = const [],
    this.stitches = const [],
    this.yarnColors = const [],
    this.instructions = const [],
  });
}

class PdfGridCell {
  final int row;
  final int column;
  final String stitchCode;
  final String colorHex;

  const PdfGridCell({
    required this.row,
    required this.column,
    this.stitchCode = '',
    this.colorHex = '#FFFFFF',
  });
}

class PdfChartStitch {
  final String code;
  final String name;
  final String symbol;
  final String description;

  // Tọa độ chuẩn hóa từ 0.0 đến 1.0.
  final double x;
  final double y;

  final int sequence;
  final int round;

  const PdfChartStitch({
    required this.code,
    required this.name,
    required this.symbol,
    this.description = '',
    this.x = 0.5,
    this.y = 0.5,
    this.sequence = 0,
    this.round = 0,
  });
}

class PdfYarnColor {
  final String name;
  final String hexCode;
  final String brand;
  final String yarnCode;

  const PdfYarnColor({
    required this.name,
    required this.hexCode,
    this.brand = '',
    this.yarnCode = '',
  });
}

class PdfInstruction {
  final int order;
  final String title;
  final String content;

  const PdfInstruction({
    required this.order,
    required this.title,
    required this.content,
  });
}
