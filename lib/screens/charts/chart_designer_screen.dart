import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/crochet_chart.dart';
import '../../models/stitch_type.dart';
import '../../models/yarn_color.dart';
import 'chart_pdf_export.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class ChartDesignerScreen extends StatefulWidget {
  const ChartDesignerScreen({
    super.key,
    required this.chartId,
    required this.onBack,
    required this.onOpenGuide,
  });

  final String chartId;
  final VoidCallback onBack;
  final VoidCallback onOpenGuide;

  @override
  State<ChartDesignerScreen> createState() => _ChartDesignerScreenState();
}

class _ChartDesignerScreenState extends State<ChartDesignerScreen> {
  late Map<String, ChartCellData> _cells;
  late Map<int, String> _instructions;
  final List<Map<String, ChartCellData>> _undoStack = [];
  final List<Map<String, ChartCellData>> _redoStack = [];
  StitchType? _selectedStitch;
  YarnColor? _selectedColor;
  _EditorTool _tool = _EditorTool.draw;
  String? _selectedCellKey;
  bool _dirty = false;
  bool _initialized = false;
  bool _saving = false;
  String? _draggingSymbolKey;
  double _cellSize = 42;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    if (!_initialized) {
      final chart = state.chartById(widget.chartId);
      _cells = Map.of(chart?.cells ?? const {});
      _instructions = Map.of(chart?.instructions ?? const {});
      _initialized = true;
    }
    _selectedStitch ??= state.stitchTypes.firstOrNull;
    _selectedColor ??= state.yarnColors.firstOrNull;
  }

  @override
  void didUpdateWidget(covariant ChartDesignerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chartId == widget.chartId || !_initialized) return;
    final chart = AppStateScope.of(context).chartById(widget.chartId);
    _cells = Map.of(chart?.cells ?? const {});
    _instructions = Map.of(chart?.instructions ?? const {});
    _undoStack.clear();
    _redoStack.clear();
    _selectedCellKey = null;
    _draggingSymbolKey = null;
    _dirty = false;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final chart = state.chartById(widget.chartId);
    if (chart == null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Không tìm thấy chart',
        message: 'Chart không còn tồn tại hoặc bạn không có quyền truy cập.',
        action: OutlinedButton(
          onPressed: widget.onBack,
          child: const Text('Quay lại'),
        ),
      );
    }
    final stitches = state.stitchTypes;
    final colors = state.yarnColors;
    if (stitches.isEmpty || colors.isEmpty) {
      return EmptyState(
        icon: stitches.isEmpty
            ? Icons.menu_book_outlined
            : Icons.palette_outlined,
        title: stitches.isEmpty
            ? 'Chưa có danh mục mũi móc'
            : 'Chưa có màu len',
        message: stitches.isEmpty
            ? 'Danh mục mũi móc trên Supabase đang trống. Hãy kiểm tra dữ liệu trong bảng stitch_types.'
            : 'Hãy thêm ít nhất một màu len tại Cá nhân → Quản lý màu len trước khi thiết kế.',
        action: OutlinedButton(
          onPressed: widget.onBack,
          child: const Text('Quay lại'),
        ),
      );
    }
    final selectedStitch = _selectedStitch ?? stitches.first;
    final selectedColor = _selectedColor ?? colors.first;

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        if (desktop) {
          return Column(
            children: [
              _TopBar(
                chartName: chart.name,
                dirty: _dirty,
                saving: _saving,
                onBack: _attemptBack,
                onUndo: _undoStack.isEmpty ? null : _undo,
                onRedo: _redoStack.isEmpty ? null : _redo,
                onGuide: widget.onOpenGuide,
                onSave: () => _save(chart),
                onExport: _exportPdf,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DesktopToolbar(
                      tool: _tool,
                      stitch: selectedStitch,
                      color: selectedColor,
                      stitches: stitches,
                      onToolChanged: (value) => setState(() => _tool = value),
                      onStitchChanged: (value) => setState(() {
                        _selectedStitch = value;
                        _tool = _EditorTool.draw;
                      }),
                      onColorChanged: (value) =>
                          setState(() => _selectedColor = value),
                    ),
                    Expanded(child: _buildCanvas(chart, stitches)),
                    _InfoPanel(
                      chart: chart,
                      stitch: selectedStitch,
                      color: selectedColor,
                      usedCodes: _cells.values
                          .map((cell) => cell.stitchCode)
                          .toSet(),
                      onGuide: widget.onOpenGuide,
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _MobileTopBar(
              chartName: chart.name,
              dirty: _dirty,
              saving: _saving,
              onBack: _attemptBack,
              onSave: () => _save(chart),
            ),
            Expanded(child: _buildCanvas(chart, stitches)),
            _MobileToolbar(
              selectedStitch: selectedStitch,
              selectedColor: selectedColor,
              tool: _tool,
              stitches: stitches,
              colors: colors,
              onStitchChanged: (value) => setState(() {
                _selectedStitch = value;
                _tool = _EditorTool.draw;
              }),
              onColorChanged: (value) => setState(() {
                _selectedColor = value;
                _tool = _EditorTool.draw;
              }),
              onSelect: () => setState(() => _tool = _EditorTool.select),
              onDraw: () => setState(() => _tool = _EditorTool.draw),
              onErase: () => setState(() => _tool = _EditorTool.erase),
              onUndo: _undoStack.isEmpty ? null : _undo,
              onOpenTools: _showMobileTools,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCanvas(CrochetChart chart, List<StitchType> stitches) {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    chart.dimensionsLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _editInstruction(chart),
                  icon: const Icon(Icons.notes_rounded),
                  tooltip: chart.chartType == ChartType.circular
                      ? 'Ghi chú vòng'
                      : 'Ghi chú hàng',
                ),
                IconButton(
                  onPressed: _cellSize <= 28
                      ? null
                      : () => setState(() => _cellSize -= 4),
                  icon: const Icon(Icons.zoom_out_rounded),
                  tooltip: 'Thu nhỏ',
                ),
                Text(
                  '${((_cellSize - 22) / 28 * 100).round()}%',
                  style: const TextStyle(fontSize: 12),
                ),
                IconButton(
                  onPressed: _cellSize >= 50
                      ? null
                      : () => setState(() => _cellSize += 4),
                  icon: const Icon(Icons.zoom_in_rounded),
                  tooltip: 'Phóng to',
                ),
              ],
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              minScale: 0.6,
              maxScale: 2.5,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(120),
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: switch (chart.chartType) {
                  ChartType.pixel => _ChartGrid(
                    rows: chart.rowsCount,
                    columns: chart.columnsCount,
                    cellSize: _cellSize,
                    cells: _cells,
                    stitches: stitches,
                    selectedKey: _selectedCellKey,
                    onCellTap: _applyToCell,
                  ),
                  ChartType.stitchSymbols => _FreeformStitchCanvas(
                    key: const ValueKey('stitch-symbol-canvas'),
                    chartType: chart.chartType,
                    rows: chart.rowsCount,
                    columns: chart.columnsCount,
                    cellSize: _cellSize,
                    cells: _cells,
                    stitches: stitches,
                    selectedKey: _selectedCellKey,
                    tool: _tool,
                    onCanvasTap: _placeSymbol,
                    onSymbolTap: _tapSymbol,
                    onSymbolDragStart: _startSymbolDrag,
                    onSymbolDrag: _dragSymbol,
                    onSymbolDragEnd: _endSymbolDrag,
                  ),
                  ChartType.circular => _FreeformStitchCanvas(
                    key: const ValueKey('circular-symbol-canvas'),
                    chartType: chart.chartType,
                    rows: chart.rowsCount,
                    columns: chart.columnsCount,
                    cellSize: _cellSize,
                    cells: _cells,
                    stitches: stitches,
                    selectedKey: _selectedCellKey,
                    tool: _tool,
                    onCanvasTap: _placeSymbol,
                    onSymbolTap: _tapSymbol,
                    onSymbolDragStart: _startSymbolDrag,
                    onSymbolDrag: _dragSymbol,
                    onSymbolDragEnd: _endSymbolDrag,
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyToCell(int row, int column) {
    final stitch = _selectedStitch;
    final color = _selectedColor;
    final chart = AppStateScope.of(context).chartById(widget.chartId);
    if (stitch == null || color == null) return;
    final key = '$row:$column';
    if (_tool == _EditorTool.select) {
      final selectedKey = _selectedCellKey;
      if (chart?.chartType == ChartType.pixel || selectedKey == null) {
        setState(() => _selectedCellKey = key);
        return;
      }
      if (selectedKey == key || _cells.containsKey(key)) {
        setState(() => _selectedCellKey = key);
        return;
      }
      final selectedCell = _cells[selectedKey];
      if (selectedCell == null) return;
      _pushHistory();
      setState(() {
        _cells.remove(selectedKey);
        _cells[key] = ChartCellData(
          row: row,
          column: column,
          stitchCode: selectedCell.stitchCode,
          colorHex: selectedCell.colorHex,
        );
        _selectedCellKey = key;
        _dirty = true;
      });
      return;
    }
    setState(() => _selectedCellKey = key);
    _pushHistory();
    setState(() {
      if (_tool == _EditorTool.erase) {
        _cells.remove(key);
      } else {
        _cells[key] = ChartCellData(
          row: row,
          column: column,
          stitchCode: stitch.code,
          colorHex: color.hexCode,
        );
      }
      _dirty = true;
    });
  }

  void _placeSymbol(int row, double x, double y) {
    if (_tool == _EditorTool.select) {
      setState(() => _selectedCellKey = null);
      return;
    }
    if (_tool != _EditorTool.draw) return;
    final stitch = _selectedStitch;
    final color = _selectedColor;
    if (stitch == null || color == null) return;
    _pushHistory();
    var key = 'symbol-${DateTime.now().microsecondsSinceEpoch}';
    while (_cells.containsKey(key)) {
      key = 'symbol-$key';
    }
    setState(() {
      _cells[key] = ChartCellData(
        row: row,
        column: _cells.values.where((cell) => cell.row == row).length,
        stitchCode: stitch.code,
        colorHex: color.hexCode,
        positionX: x,
        positionY: y,
      );
      _selectedCellKey = key;
      _dirty = true;
    });
  }

  void _tapSymbol(String key) {
    final cell = _cells[key];
    if (cell == null) return;
    if (_tool == _EditorTool.select) {
      setState(() => _selectedCellKey = key);
      return;
    }
    if (_tool == _EditorTool.erase) {
      _pushHistory();
      setState(() {
        _cells.remove(key);
        _selectedCellKey = null;
        _dirty = true;
      });
      return;
    }
    final stitch = _selectedStitch;
    final color = _selectedColor;
    if (stitch == null || color == null) return;
    _pushHistory();
    setState(() {
      _cells[key] = ChartCellData(
        row: cell.row,
        column: cell.column,
        stitchCode: stitch.code,
        colorHex: color.hexCode,
        positionX: cell.positionX,
        positionY: cell.positionY,
      );
      _selectedCellKey = key;
      _dirty = true;
    });
  }

  void _startSymbolDrag(String key) {
    if (_tool != _EditorTool.select || !_cells.containsKey(key)) return;
    _pushHistory();
    setState(() {
      _selectedCellKey = key;
      _draggingSymbolKey = key;
    });
  }

  void _dragSymbol(String key, double x, double y, int row) {
    final cell = _cells[key];
    if (cell == null ||
        _tool != _EditorTool.select ||
        _draggingSymbolKey != key) {
      return;
    }
    final column = row == cell.row
        ? cell.column
        : _cells.entries
              .where((entry) => entry.key != key && entry.value.row == row)
              .length;
    setState(() {
      _cells[key] = ChartCellData(
        row: row,
        column: column,
        stitchCode: cell.stitchCode,
        colorHex: cell.colorHex,
        positionX: x,
        positionY: y,
      );
      _selectedCellKey = key;
      _dirty = true;
    });
  }

  void _endSymbolDrag(String key) {
    if (_draggingSymbolKey == key) _draggingSymbolKey = null;
  }

  void _pushHistory() {
    _undoStack.add(Map.of(_cells));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(Map.of(_cells));
      _cells = _undoStack.removeLast();
      _dirty = true;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(Map.of(_cells));
      _cells = _redoStack.removeLast();
      _dirty = true;
    });
  }

  Future<void> _save(CrochetChart chart) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await AppStateScope.of(context).updateChart(
        chart.copyWith(
          cells: Map.of(_cells),
          instructions: Map.of(_instructions),
        ),
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu chart.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lưu chart: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editInstruction(CrochetChart chart) async {
    final rowIndex = _cells[_selectedCellKey]?.row ?? 0;
    final controller = TextEditingController(
      text: _instructions[rowIndex] ?? '',
    );
    final unit = chart.chartType == ChartType.circular ? 'vòng' : 'hàng';
    final instruction = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ghi chú $unit ${rowIndex + 1}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Nhập hướng dẫn hoặc ghi chú cho $unit này',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lưu ghi chú'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (instruction == null || !mounted) return;
    setState(() {
      if (instruction.trim().isEmpty) {
        _instructions.remove(rowIndex);
      } else {
        _instructions[rowIndex] = instruction.trim();
      }
      _dirty = true;
    });
  }

  Future<void> _attemptBack() async {
    if (!_dirty) {
      widget.onBack();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời trình thiết kế?'),
        content: const Text(
          'Bạn có thay đổi chưa lưu. Nếu rời đi, các thay đổi này sẽ bị mất.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời đi'),
          ),
        ],
      ),
    );
    if (leave == true) widget.onBack();
  }

  Future<void> _exportPdf() async {
    final state = AppStateScope.of(context);
    final chart = state.chartById(widget.chartId);

    if (chart == null) return;

    await showChartPdfExport(
      context,
      chart,
      cells: Map<String, ChartCellData>.of(_cells),
      instructions: Map<int, String>.of(_instructions),
    );
  }

  Future<void> _showMobileTools() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Công cụ thiết kế',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ký hiệu',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppStateScope.of(context).stitchTypes
                      .map(
                        (stitch) => ChoiceChip(
                          selected: _selectedStitch?.code == stitch.code,
                          label: Text('${stitch.symbol} ${stitch.code}'),
                          onSelected: (_) {
                            setState(() {
                              _selectedStitch = stitch;
                              _tool = _EditorTool.draw;
                            });
                            setSheetState(() {});
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Màu len',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: AppStateScope.of(context).yarnColors
                      .map(
                        (color) => _ColorButton(
                          color: color,
                          selected: _selectedColor?.id == color.id,
                          onTap: () {
                            setState(() => _selectedColor = color);
                            setSheetState(() {});
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _exportPdf,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Xuất PDF'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _EditorTool { select, draw, erase }

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.chartName,
    required this.dirty,
    required this.saving,
    required this.onBack,
    required this.onUndo,
    required this.onRedo,
    required this.onGuide,
    required this.onSave,
    required this.onExport,
  });

  final String chartName;
  final bool dirty;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onGuide;
  final VoidCallback onSave;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Quay lại',
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chartName,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  saving
                      ? 'Đang lưu...'
                      : dirty
                      ? 'Có thay đổi chưa lưu'
                      : 'Đã lưu',
                  style: TextStyle(
                    fontSize: 11,
                    color: dirty ? AppColors.danger : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onUndo,
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Hoàn tác',
          ),
          IconButton(
            onPressed: onRedo,
            icon: const Icon(Icons.redo_rounded),
            tooltip: 'Làm lại',
          ),
          OutlinedButton.icon(
            onPressed: onGuide,
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Xem hướng dẫn'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(13),
            ),
            child: const Icon(Icons.check_rounded),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onExport,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Xuất PDF',
          ),
        ],
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.chartName,
    required this.dirty,
    required this.saving,
    required this.onBack,
    required this.onSave,
  });

  final String chartName;
  final bool dirty;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chartName, overflow: TextOverflow.ellipsis),
          Text(
            saving
                ? 'Đang lưu...'
                : dirty
                ? 'Chưa lưu'
                : 'Đã lưu',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      actions: [
        IconButton.filled(
          onPressed: saving ? null : onSave,
          icon: const Icon(Icons.check_rounded),
          tooltip: 'Lưu thiết kế',
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _DesktopToolbar extends StatelessWidget {
  const _DesktopToolbar({
    required this.tool,
    required this.stitch,
    required this.color,
    required this.stitches,
    required this.onToolChanged,
    required this.onStitchChanged,
    required this.onColorChanged,
  });

  final _EditorTool tool;
  final StitchType stitch;
  final YarnColor color;
  final List<StitchType> stitches;
  final ValueChanged<_EditorTool> onToolChanged;
  final ValueChanged<StitchType> onStitchChanged;
  final ValueChanged<YarnColor> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Công cụ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SegmentedButton<_EditorTool>(
              segments: const [
                ButtonSegment(
                  value: _EditorTool.select,
                  icon: Icon(Icons.ads_click_rounded),
                  tooltip: 'Chọn',
                ),
                ButtonSegment(
                  value: _EditorTool.draw,
                  icon: Icon(Icons.edit_rounded),
                  tooltip: 'Vẽ',
                ),
                ButtonSegment(
                  value: _EditorTool.erase,
                  icon: Icon(Icons.auto_fix_off_rounded),
                  tooltip: 'Tẩy',
                ),
              ],
              selected: {tool},
              onSelectionChanged: (values) => onToolChanged(values.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 22),
            const Text(
              'Ký hiệu mũi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final item in stitches)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ChoiceChip(
                  selected: stitch.code == item.code,
                  label: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(item.symbol, textAlign: TextAlign.center),
                      ),
                      const SizedBox(width: 6),
                      Text(item.code),
                    ],
                  ),
                  onSelected: (_) => onStitchChanged(item),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Màu len',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppStateScope.of(context).yarnColors
                  .map(
                    (item) => _ColorButton(
                      color: item,
                      selected: color.id == item.id,
                      onTap: () => onColorChanged(item),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Hãy thêm màu trong mục Cá nhân → Quản lý màu len.',
                  ),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm màu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.chart,
    required this.stitch,
    required this.color,
    required this.usedCodes,
    required this.onGuide,
  });

  final CrochetChart chart;
  final StitchType stitch;
  final YarnColor color;
  final Set<String> usedCodes;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(chart.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              '${chart.category} · ${chart.dimensionsLabel}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const Divider(height: 28),
            const Text(
              'Đang chọn',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Text(stitch.symbol),
              ),
              title: Text(stitch.code),
              subtitle: Text(stitch.name),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _ColorSwatch(hexCode: color.hexCode),
              title: Text(color.name),
              subtitle: Text(color.hexCode),
            ),
            const Divider(height: 28),
            const Text(
              'Ký hiệu đã dùng',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (usedCodes.isEmpty)
              const Text(
                'Lưới đang trống.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: usedCodes
                    .map((code) => Chip(label: Text(code)))
                    .toList(),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onGuide,
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Xem hướng dẫn'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileToolbar extends StatelessWidget {
  const _MobileToolbar({
    required this.selectedStitch,
    required this.selectedColor,
    required this.tool,
    required this.stitches,
    required this.colors,
    required this.onStitchChanged,
    required this.onColorChanged,
    required this.onSelect,
    required this.onDraw,
    required this.onErase,
    required this.onUndo,
    required this.onOpenTools,
  });

  final StitchType selectedStitch;
  final YarnColor selectedColor;
  final _EditorTool tool;
  final List<StitchType> stitches;
  final List<YarnColor> colors;
  final ValueChanged<StitchType> onStitchChanged;
  final ValueChanged<YarnColor> onColorChanged;
  final VoidCallback onSelect;
  final VoidCallback onDraw;
  final VoidCallback onErase;
  final VoidCallback? onUndo;
  final VoidCallback onOpenTools;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 190),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 12,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Mũi',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: stitches
                          .map(
                            (stitch) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                selected: selectedStitch.code == stitch.code,
                                label: Text('${stitch.symbol} ${stitch.code}'),
                                onSelected: (_) => onStitchChanged(stitch),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Text(
                  'Màu',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: colors
                          .map(
                            (color) => Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: _ColorButton(
                                color: color,
                                selected: selectedColor.id == color.id,
                                onTap: () => onColorChanged(color),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton.filledTonal(
                  onPressed: onSelect,
                  icon: Icon(
                    Icons.ads_click_rounded,
                    color: tool == _EditorTool.select
                        ? AppColors.primary
                        : null,
                  ),
                  tooltip: 'Chọn/di chuyển',
                ),
                IconButton.filledTonal(
                  onPressed: onDraw,
                  icon: Icon(
                    Icons.edit_rounded,
                    color: tool == _EditorTool.draw ? AppColors.primary : null,
                  ),
                  tooltip: 'Vẽ',
                ),
                IconButton.filledTonal(
                  onPressed: onErase,
                  icon: Icon(
                    Icons.auto_fix_off_rounded,
                    color: tool == _EditorTool.erase ? AppColors.primary : null,
                  ),
                  tooltip: 'Tẩy',
                ),
                IconButton(
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: 'Hoàn tác',
                ),
                IconButton(
                  onPressed: onOpenTools,
                  icon: const Icon(Icons.more_horiz_rounded),
                  tooltip: 'Thêm công cụ',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final YarnColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: color.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: _ColorSwatch(hexCode: color.hexCode),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.hexCode});

  final String hexCode;

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _hexColor(hexCode),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

class _ChartGrid extends StatelessWidget {
  const _ChartGrid({
    required this.rows,
    required this.columns,
    required this.cellSize,
    required this.cells,
    required this.stitches,
    required this.selectedKey,
    required this.onCellTap,
  });

  final int rows;
  final int columns;
  final double cellSize;
  final Map<String, ChartCellData> cells;
  final List<StitchType> stitches;
  final String? selectedKey;
  final void Function(int row, int column) onCellTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 2, 2),
      color: AppColors.surface,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: columns * cellSize,
            height: rows * cellSize,
            child: Column(
              children: List.generate(
                rows,
                (row) => Row(
                  children: List.generate(columns, (column) {
                    final key = '$row:$column';
                    final cell = cells[key];
                    final stitch = cell == null
                        ? null
                        : stitches
                              .where((item) => item.code == cell.stitchCode)
                              .firstOrNull;
                    return GestureDetector(
                      onTap: () => onCellTap(row, column),
                      child: Container(
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: cell == null
                              ? Colors.white
                              : _hexColor(
                                  cell.colorHex,
                                ).withValues(alpha: 0.42),
                          border: Border.all(
                            color: selectedKey == key
                                ? AppColors.primary
                                : AppColors.border,
                            width: selectedKey == key ? 2.2 : 0.7,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: cell == null
                            ? null
                            : Text(
                                stitch?.symbol ?? cell.stitchCode,
                                style: TextStyle(
                                  fontSize: cellSize * 0.38,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          for (var column = 0; column < columns; column++)
            Positioned(
              left: column * cellSize,
              top: -24,
              width: cellSize,
              child: Text(
                '${column + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          for (var row = 0; row < rows; row++)
            Positioned(
              left: -26,
              top: row * cellSize,
              height: cellSize,
              child: Center(
                child: Text(
                  '${row + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FreeformStitchCanvas extends StatefulWidget {
  const _FreeformStitchCanvas({
    super.key,
    required this.chartType,
    required this.rows,
    required this.columns,
    required this.cellSize,
    required this.cells,
    required this.stitches,
    required this.selectedKey,
    required this.tool,
    required this.onCanvasTap,
    required this.onSymbolTap,
    required this.onSymbolDragStart,
    required this.onSymbolDrag,
    required this.onSymbolDragEnd,
  });

  final ChartType chartType;
  final int rows;
  final int columns;
  final double cellSize;
  final Map<String, ChartCellData> cells;
  final List<StitchType> stitches;
  final String? selectedKey;
  final _EditorTool tool;
  final void Function(int row, double x, double y) onCanvasTap;
  final ValueChanged<String> onSymbolTap;
  final ValueChanged<String> onSymbolDragStart;
  final void Function(String key, double x, double y, int row) onSymbolDrag;
  final ValueChanged<String> onSymbolDragEnd;

  @override
  State<_FreeformStitchCanvas> createState() => _FreeformStitchCanvasState();
}

class _FreeformStitchCanvasState extends State<_FreeformStitchCanvas> {
  final GlobalKey _canvasKey = GlobalKey();
  Offset? _tapPosition;

  bool get _isCircular => widget.chartType == ChartType.circular;

  double get _canvasWidth => _isCircular
      ? _canvasHeight
      : math.max(360, widget.columns * widget.cellSize).toDouble();

  double get _canvasHeight {
    if (!_isCircular) {
      return math.max(280, widget.rows * widget.cellSize).toDouble();
    }
    const ringGap = 48.0;
    const padding = 36.0;
    const minimumRadius = 56.0;
    final firstRadius = math
        .max(minimumRadius, widget.columns * 18 / (2 * math.pi))
        .toDouble();
    return (firstRadius + (widget.rows - 1) * ringGap + padding) * 2;
  }

  double get _firstRadius =>
      math.max(56.0, widget.columns * 18 / (2 * math.pi)).toDouble();

  static const double _ringGap = 48;

  @override
  Widget build(BuildContext context) {
    final size = Size(_canvasWidth, _canvasHeight);
    return Container(
      key: _canvasKey,
      width: size.width,
      height: size.height,
      color: AppColors.surface,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _tapPosition = details.localPosition,
        onTap: _handleCanvasTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _isCircular
                      ? _CircularRoundsPainter(
                          rounds: widget.rows,
                          firstRadius: _firstRadius,
                          ringGap: _ringGap,
                        )
                      : _StitchRowsPainter(rows: widget.rows),
                ),
              ),
            ),
            if (!_isCircular)
              const Positioned(
                left: 8,
                top: 8,
                child: IgnorePointer(
                  child: Text(
                    'Chart ký hiệu · chạm nền để thêm mũi',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            for (final entry in widget.cells.entries)
              _buildSymbol(entry.key, entry.value, size),
          ],
        ),
      ),
    );
  }

  Widget _buildSymbol(String key, ChartCellData cell, Size size) {
    final position = _positionForCell(cell, size);
    final stitch = _stitchFor(cell, widget.stitches);
    final nodeSize = (widget.cellSize * 0.9).clamp(28.0, 40.0).toDouble();
    final selected = widget.selectedKey == key;
    return Positioned(
      left: position.dx - nodeSize / 2,
      top: position.dy - nodeSize / 2,
      width: nodeSize,
      height: nodeSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSymbolTap(key),
        onPanStart: (_) => widget.onSymbolDragStart(key),
        onPanUpdate: (details) {
          final box =
              _canvasKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return;
          final local = box.globalToLocal(details.globalPosition);
          final point = _normalizePoint(local, size);
          widget.onSymbolDrag(key, point.dx, point.dy, point.row);
        },
        onPanEnd: (_) => widget.onSymbolDragEnd(key),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? _hexColor(cell.colorHex).withValues(alpha: 0.2)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Text(
                  stitch?.symbol ?? cell.stitchCode,
                  style: TextStyle(
                    color: _stitchColor(cell.colorHex),
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _positionForCell(ChartCellData cell, Size size) {
    if (cell.positionX != null && cell.positionY != null) {
      return Offset(
        cell.positionX! * size.width,
        cell.positionY! * size.height,
      );
    }
    if (_isCircular) {
      final radius = _firstRadius + cell.row * _ringGap;
      final angle = -math.pi / 2 + 2 * math.pi * cell.column / widget.columns;
      return Offset(
        size.width / 2 + math.cos(angle) * radius,
        size.height / 2 + math.sin(angle) * radius,
      );
    }
    final bandHeight = size.height / widget.rows;
    return Offset(
      24 + (cell.column + 0.5) * (size.width - 36) / widget.columns,
      (cell.row + 0.5) * bandHeight,
    );
  }

  void _handleCanvasTap() {
    final local = _tapPosition;
    if (local == null) return;
    if (widget.tool == _EditorTool.erase) return;
    final point = _normalizePoint(local, Size(_canvasWidth, _canvasHeight));
    widget.onCanvasTap(point.row, point.dx, point.dy);
  }

  _CanvasPoint _normalizePoint(Offset local, Size size) {
    if (_isCircular) {
      final center = Offset(size.width / 2, size.height / 2);
      final delta = local - center;
      final radius = delta.distance;
      final row = ((radius - _firstRadius) / _ringGap)
          .round()
          .clamp(0, widget.rows - 1)
          .toInt();
      final ringRadius = _firstRadius + row * _ringGap;
      final angle = radius == 0 ? -math.pi / 2 : math.atan2(delta.dy, delta.dx);
      return _CanvasPoint(
        row,
        (center.dx + math.cos(angle) * ringRadius) / size.width,
        (center.dy + math.sin(angle) * ringRadius) / size.height,
      );
    }
    final x = (local.dx / size.width).clamp(0.06, 0.94).toDouble();
    final y = (local.dy / size.height).clamp(0.07, 0.93).toDouble();
    final row = (y * widget.rows).floor().clamp(0, widget.rows - 1).toInt();
    return _CanvasPoint(row, x, y);
  }
}

class _CanvasPoint {
  const _CanvasPoint(this.row, this.dx, this.dy);
  final int row;
  final double dx;
  final double dy;
}

class _StitchRowsPainter extends CustomPainter {
  const _StitchRowsPainter({required this.rows});

  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.65)
      ..strokeWidth = 0.8;
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    final bandHeight = size.height / rows;
    for (var row = 0; row < rows; row++) {
      final y = (row + 0.5) * bandHeight;
      canvas.drawLine(Offset(30, y), Offset(size.width, y), linePaint);
      labelPainter.text = TextSpan(
        text: '${row + 1}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(8, y - labelPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_StitchRowsPainter oldDelegate) =>
      rows != oldDelegate.rows;
}

class _CircularRoundsPainter extends CustomPainter {
  const _CircularRoundsPainter({
    required this.rounds,
    required this.firstRadius,
    required this.ringGap,
  });

  final int rounds;
  final double firstRadius;
  final double ringGap;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var row = 0; row < rounds; row++) {
      final radius = firstRadius + row * ringGap;
      canvas.drawCircle(center, radius, ringPaint);
      final label = TextPainter(
        text: TextSpan(
          text: 'V${row + 1}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(center.dx - label.width / 2, center.dy - radius - label.height),
      );
    }
    canvas.drawCircle(center, 4, Paint()..color = AppColors.primary);
    final centerLabel = TextPainter(
      text: const TextSpan(
        text: 'Tâm',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    centerLabel.paint(
      canvas,
      Offset(center.dx - centerLabel.width / 2, center.dy + 8),
    );
  }

  @override
  bool shouldRepaint(_CircularRoundsPainter oldDelegate) =>
      rounds != oldDelegate.rounds ||
      firstRadius != oldDelegate.firstRadius ||
      ringGap != oldDelegate.ringGap;
}

StitchType? _stitchFor(ChartCellData? cell, List<StitchType> stitches) {
  if (cell == null) return null;
  return stitches.where((item) => item.code == cell.stitchCode).firstOrNull;
}

Color _hexColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

Color _stitchColor(String hex) =>
    Color.lerp(Colors.black, _hexColor(hex), 0.65)!;
