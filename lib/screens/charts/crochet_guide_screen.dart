import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/crochet_chart.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class CrochetGuideScreen extends StatefulWidget {
  const CrochetGuideScreen({
    super.key,
    required this.chartId,
    required this.onBack,
    required this.onOpenDesigner,
  });

  final String chartId;
  final VoidCallback onBack;
  final VoidCallback onOpenDesigner;

  @override
  State<CrochetGuideScreen> createState() => _CrochetGuideScreenState();
}

class _CrochetGuideScreenState extends State<CrochetGuideScreen> {
  int? _viewingRow;
  bool _updatingProgress = false;

  @override
  Widget build(BuildContext context) {
    final chart = AppStateScope.of(context).chartById(widget.chartId);
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

    final row = (_viewingRow ?? chart.currentRow).clamp(1, chart.rowsCount);
    final rowCells =
        chart.cells.values.where((cell) => cell.row == row - 1).toList()
          ..sort((a, b) => a.column.compareTo(b.column));
    final unit = chart.progressUnit;
    final unitTitle = unit == 'vòng' ? 'Vòng' : 'Hàng';
    final instruction = chart.instructions[row - 1];

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final title = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hướng dẫn móc',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        chart.name,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  );
                  final backButton = IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  );
                  final designerButton = OutlinedButton.icon(
                    onPressed: widget.onOpenDesigner,
                    icon: const Icon(Icons.draw_rounded),
                    label: const Text('Mở thiết kế'),
                  );
                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            backButton,
                            const SizedBox(width: 8),
                            Expanded(child: title),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: designerButton,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      backButton,
                      const SizedBox(width: 8),
                      Expanded(child: title),
                      designerButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$unitTitle $row / ${chart.rowsCount}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              '${chart.completedRows} $unit đã xong',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: chart.progress,
                          minHeight: 10,
                          backgroundColor: AppColors.border,
                          color: chart.status == ChartStatus.completed
                              ? AppColors.sage
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Thứ tự ký hiệu',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (instruction?.isNotEmpty ?? false) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(instruction!),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (rowCells.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '$unitTitle này chưa có ký hiệu. Hãy mở trình thiết kế để thêm mũi móc.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: rowCells.map((cell) {
                            final stitch = AppStateScope.of(context).stitchTypes
                                .where((item) => item.code == cell.stitchCode)
                                .firstOrNull;
                            return Chip(
                              avatar: CircleAvatar(
                                backgroundColor: _hexColor(cell.colorHex),
                                child: Text(
                                  stitch?.symbol ?? '•',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              label: Text(
                                '${cell.column + 1}. ${cell.stitchCode}',
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final buttons = <Widget>[
                            OutlinedButton.icon(
                              onPressed: row <= 1
                                  ? null
                                  : () => setState(() => _viewingRow = row - 1),
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: Text('$unitTitle trước'),
                            ),
                            FilledButton.icon(
                              onPressed:
                                  row == chart.currentRow &&
                                      chart.completedRows < chart.rowsCount &&
                                      !_updatingProgress
                                  ? () => _markRowComplete(chart.id, row)
                                  : null,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Đánh dấu hoàn thành'),
                            ),
                            OutlinedButton.icon(
                              onPressed: row >= chart.rowsCount
                                  ? null
                                  : () => setState(() => _viewingRow = row + 1),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: Text('$unitTitle tiếp theo'),
                            ),
                          ];
                          if (constraints.maxWidth < 650) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: buttons
                                  .map(
                                    (button) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: button,
                                    ),
                                  )
                                  .toList(),
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: buttons,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markRowComplete(String chartId, int row) async {
    setState(() => _updatingProgress = true);
    try {
      await AppStateScope.of(context).markCurrentRowComplete(chartId);
      if (mounted) {
        setState(
          () => _viewingRow = (row + 1).clamp(
            1,
            AppStateScope.of(context).chartById(chartId)!.rowsCount,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật tiến độ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingProgress = false);
    }
  }
}

Color _hexColor(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
