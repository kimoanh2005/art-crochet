import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/crochet_chart.dart';
import '../screens/charts/chart_pdf_export.dart';
import '../state/app_state.dart';

class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.chart,
    required this.onOpen,
    required this.onEdit,
  });

  final CrochetChart chart;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ChartThumbnail(chart: chart),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: chart.isFavorite
                            ? 'Bỏ yêu thích'
                            : 'Yêu thích',
                        onPressed: () async {
                          try {
                            await AppStateScope.of(
                              context,
                            ).toggleFavorite(chart.id);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Không thể cập nhật yêu thích: $error',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: Icon(
                          chart.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chart.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      PopupMenuButton<_ChartAction>(
                        tooltip: 'Thao tác',
                        onSelected: (action) => _handleAction(context, action),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _ChartAction.edit,
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Chỉnh sửa'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _ChartAction.export,
                            child: ListTile(
                              leading: Icon(Icons.file_download_outlined),
                              title: Text('Xuất PDF'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _ChartAction.delete,
                            child: ListTile(
                              leading: Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                              ),
                              title: Text(
                                'Xóa',
                                style: TextStyle(color: AppColors.danger),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    chart.category,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: chart.progress,
                            minHeight: 7,
                            backgroundColor: AppColors.border,
                            color: chart.status == ChartStatus.completed
                                ? AppColors.sage
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(chart.progress * 100).round()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StatusChip(status: chart.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, _ChartAction action) async {
    final state = AppStateScope.of(context);
    switch (action) {
      case _ChartAction.edit:
        onEdit();
      case _ChartAction.export:
        await showChartPdfExport(context, chart);
      case _ChartAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa chart?'),
            content: Text(
              'Bạn có chắc muốn xóa “${chart.name}” khỏi tài khoản?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          try {
            await state.deleteChart(chart.id);
          } catch (error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Không thể xóa chart: $error')),
              );
            }
          }
        }
    }
  }
}

enum _ChartAction { edit, export, delete }

class _ChartThumbnail extends StatelessWidget {
  const _ChartThumbnail({required this.chart});

  final CrochetChart chart;

  @override
  Widget build(BuildContext context) {
    final icon = switch (chart.category) {
      'Hoa' => Icons.local_florist_rounded,
      'Túi' => Icons.shopping_bag_rounded,
      'Thú bông' => Icons.pets_rounded,
      'Khăn' => Icons.texture_rounded,
      _ => Icons.auto_awesome_rounded,
    };
    return Container(
      color: chart.category.hashCode.isEven
          ? AppColors.primarySoft.withValues(alpha: 0.45)
          : AppColors.sage.withValues(alpha: 0.62),
      child: Center(
        child: Icon(
          icon,
          size: 64,
          color: AppColors.textPrimary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ChartStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == ChartStatus.completed
        ? AppColors.sage
        : AppColors.primarySoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
