import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/crochet_chart.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.onContinue});

  final ValueChanged<String> onContinue;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _filter = 'Đang thực hiện';

  @override
  Widget build(BuildContext context) {
    final allCharts = AppStateScope.of(context).charts;
    final charts = allCharts.where((chart) {
      if (_filter == 'Tất cả') return true;
      return chart.status.label == _filter;
    }).toList();

    return LayoutBuilder(
      builder: (context, viewport) {
        final mobile = viewport.maxWidth < 600;
        return Padding(
          padding: EdgeInsets.all(mobile ? 16 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tiến độ móc',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Theo dõi tiến độ theo hàng hoặc vòng và tiếp tục nơi bạn đã dừng lại.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  _ProgressFilters(
                    selected: _filter,
                    mobile: mobile,
                    onSelected: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: charts.isEmpty
                        ? const EmptyState(
                            icon: Icons.hourglass_empty_rounded,
                            title: 'Không có chart phù hợp',
                            message: 'Hãy chọn trạng thái khác để xem tiến độ.',
                          )
                        : ListView.separated(
                            itemCount: charts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) => _ProgressCard(
                              chart: charts[index],
                              onContinue: () =>
                                  widget.onContinue(charts[index].id),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressFilters extends StatelessWidget {
  const _ProgressFilters({
    required this.selected,
    required this.mobile,
    required this.onSelected,
  });

  final String selected;
  final bool mobile;
  final ValueChanged<String> onSelected;

  static const _items = <({String value, String shortLabel, IconData icon})>[
    (value: 'Tất cả', shortLabel: 'Tất cả', icon: Icons.apps_rounded),
    (value: 'Đang thực hiện', shortLabel: 'Đang làm', icon: Icons.draw_rounded),
    (
      value: 'Chưa bắt đầu',
      shortLabel: 'Chưa làm',
      icon: Icons.schedule_rounded,
    ),
    (
      value: 'Hoàn thành',
      shortLabel: 'Đã xong',
      icon: Icons.check_circle_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!mobile) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<String>(
          segments: [
            for (final item in _items)
              ButtonSegment(
                value: item.value,
                icon: Icon(item.icon),
                label: Text(item.value),
              ),
          ],
          selected: {selected},
          onSelectionChanged: (values) => onSelected(values.first),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemBuilder: (context, index) {
        final item = _items[index];
        final isSelected = selected == item.value;
        return Material(
          color: isSelected
              ? AppColors.primarySoft.withValues(alpha: 0.72)
              : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            onTap: () => onSelected(item.value),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: 19,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      item.shortLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.chart, required this.onContinue});

  final CrochetChart chart;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final detail = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chart.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${(chart.progress * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${chart.category} · ${chart.status.label}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: chart.progress,
                    minHeight: 9,
                    backgroundColor: AppColors.border,
                    color: chart.status == ChartStatus.completed
                        ? AppColors.sage
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${chart.completedRows}/${chart.rowsCount} ${chart.progressUnit} · '
                  '${chart.progressUnit == 'vòng' ? 'Vòng' : 'Hàng'} hiện tại: '
                  '${chart.currentRow}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (chart.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.sticky_note_2_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          chart.notes,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
            final button = FilledButton.icon(
              onPressed: onContinue,
              icon: Icon(
                chart.status == ChartStatus.completed
                    ? Icons.menu_book_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                chart.status == ChartStatus.completed ? 'Xem lại' : 'Tiếp tục',
              ),
            );
            if (constraints.maxWidth < 650) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [detail, const SizedBox(height: 16), button],
              );
            }
            return Row(
              children: [
                Expanded(child: detail),
                const SizedBox(width: 24),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}
