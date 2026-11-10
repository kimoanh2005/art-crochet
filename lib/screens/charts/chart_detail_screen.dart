import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/crochet_chart.dart';
import 'chart_pdf_export.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class ChartDetailScreen extends StatelessWidget {
  const ChartDetailScreen({
    super.key,
    required this.chartId,
    required this.onBack,
    required this.onOpenDesigner,
    required this.onOpenGuide,
  });

  final String chartId;
  final VoidCallback onBack;
  final VoidCallback onOpenDesigner;
  final VoidCallback onOpenGuide;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final chart = state.chartById(chartId);
    if (chart == null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Không tìm thấy chart',
        message: 'Chart không còn tồn tại hoặc bạn không có quyền truy cập.',
        action: OutlinedButton(
          onPressed: onBack,
          child: const Text('Quay lại'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Quay lại',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chart.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final preview = _ChartPreview(chart: chart);
                  final info = _ChartInfo(
                    chart: chart,
                    onOpenDesigner: onOpenDesigner,
                    onOpenGuide: onOpenGuide,
                  );
                  if (constraints.maxWidth < 760) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [preview, const SizedBox(height: 16), info],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: preview),
                      const SizedBox(width: 20),
                      Expanded(flex: 4, child: info),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Chú giải ký hiệu và màu'),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: state.stitchTypes
                            .map(
                              (stitch) => Chip(
                                avatar: Text(stitch.symbol),
                                label: Text('${stitch.code} · ${stitch.name}'),
                              ),
                            )
                            .toList(),
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
}

class _ChartPreview extends StatelessWidget {
  const _ChartPreview({required this.chart});

  final CrochetChart chart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: AspectRatio(
        aspectRatio: 1.15,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.primarySoft.withValues(alpha: 0.48),
                AppColors.sage.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  switch (chart.chartType) {
                    ChartType.pixel => Icons.grid_on_rounded,
                    ChartType.stitchSymbols =>
                      Icons.format_list_numbered_rounded,
                    ChartType.circular => Icons.radio_button_unchecked_rounded,
                  },
                  size: 90,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  chart.dimensionsLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Bản xem trước',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartInfo extends StatelessWidget {
  const _ChartInfo({
    required this.chart,
    required this.onOpenDesigner,
    required this.onOpenGuide,
  });

  final CrochetChart chart;
  final VoidCallback onOpenDesigner;
  final VoidCallback onOpenGuide;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              chart.category,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              chart.description.isEmpty ? 'Chưa có mô tả.' : chart.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _InfoRow(
              icon: Icons.grid_4x4_rounded,
              label: 'Kích thước',
              value: chart.dimensionsLabel,
            ),
            _InfoRow(
              icon: Icons.flag_outlined,
              label: 'Trạng thái',
              value: chart.status.label,
            ),
            _InfoRow(
              icon: Icons.layers_outlined,
              label:
                  '${chart.progressUnit == 'vòng' ? 'Vòng' : 'Hàng'} đã xong',
              value:
                  '${chart.completedRows}/${chart.rowsCount} ${chart.progressUnit}',
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: chart.progress,
                minHeight: 10,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Mở thiết kế',
              icon: Icons.draw_rounded,
              onPressed: onOpenDesigner,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onOpenGuide,
              icon: const Icon(Icons.menu_book_rounded),
              label: Text(
                chart.completedRows == 0 ? 'Bắt đầu móc' : 'Tiếp tục móc',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => showChartPdfExport(context, chart),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Xuất PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
