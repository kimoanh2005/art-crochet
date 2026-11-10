enum ChartStatus { notStarted, inProgress, completed }

enum ChartType { pixel, stitchSymbols, circular }

extension ChartStatusLabel on ChartStatus {
  String get label => switch (this) {
    ChartStatus.notStarted => 'Chưa bắt đầu',
    ChartStatus.inProgress => 'Đang thực hiện',
    ChartStatus.completed => 'Hoàn thành',
  };
}

extension ChartTypeLabel on ChartType {
  String get label => switch (this) {
    ChartType.pixel => 'Pixel',
    ChartType.stitchSymbols => 'Ký hiệu mũi móc',
    ChartType.circular => 'Chart tròn',
  };

  String get description => switch (this) {
    ChartType.pixel => 'Lưới ô vuông',
    ChartType.stitchSymbols => 'Thiết kế theo hàng',
    ChartType.circular => 'Thiết kế theo vòng',
  };

  String get unitLabel => this == ChartType.circular ? 'vòng' : 'hàng';
}

class ChartCellData {
  const ChartCellData({
    required this.row,
    required this.column,
    required this.stitchCode,
    required this.colorHex,
    this.positionX,
    this.positionY,
  });

  final int row;
  final int column;
  final String stitchCode;
  final String colorHex;
  final double? positionX;
  final double? positionY;

  String get key => '$row:$column';
}

class CrochetChart {
  const CrochetChart({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.chartType,
    required this.rowsCount,
    required this.columnsCount,
    required this.status,
    required this.completedRows,
    required this.isFavorite,
    required this.updatedAt,
    this.notes = '',
    this.cells = const {},
    this.instructions = const {},
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final ChartType chartType;
  final int rowsCount;
  final int columnsCount;
  final ChartStatus status;
  final int completedRows;
  final bool isFavorite;
  final DateTime updatedAt;
  final String notes;
  final Map<String, ChartCellData> cells;
  final Map<int, String> instructions;

  double get progress =>
      rowsCount <= 0 ? 0 : (completedRows / rowsCount).clamp(0, 1).toDouble();

  int get currentRow =>
      rowsCount <= 0 ? 0 : (completedRows + 1).clamp(1, rowsCount);

  String get progressUnit => chartType.unitLabel;

  String get dimensionsLabel => switch (chartType) {
    ChartType.pixel => '$rowsCount × $columnsCount ô',
    ChartType.stitchSymbols => '$rowsCount hàng · $columnsCount mũi/hàng',
    ChartType.circular => '$rowsCount vòng · $columnsCount mũi/vòng',
  };

  CrochetChart copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    ChartType? chartType,
    int? rowsCount,
    int? columnsCount,
    ChartStatus? status,
    int? completedRows,
    bool? isFavorite,
    DateTime? updatedAt,
    String? notes,
    Map<String, ChartCellData>? cells,
    Map<int, String>? instructions,
  }) {
    return CrochetChart(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      chartType: chartType ?? this.chartType,
      rowsCount: rowsCount ?? this.rowsCount,
      columnsCount: columnsCount ?? this.columnsCount,
      status: status ?? this.status,
      completedRows: completedRows ?? this.completedRows,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      cells: cells ?? this.cells,
      instructions: instructions ?? this.instructions,
    );
  }
}
