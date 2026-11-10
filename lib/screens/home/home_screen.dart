import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/crochet_chart.dart';
import '../../state/app_state.dart';
import '../../widgets/chart_card.dart';
import '../../widgets/common_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onCreateChart,
    required this.onOpenChart,
    required this.onEditChart,
    required this.onOpenProgress,
  });

  final VoidCallback onCreateChart;
  final ValueChanged<String> onOpenChart;
  final ValueChanged<String> onEditChart;
  final ValueChanged<String> onOpenProgress;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final charts = state.charts;
    final profile = state.profile;
    final inProgress = charts
        .where((chart) => chart.status == ChartStatus.inProgress)
        .toList();
    final completed = charts
        .where((chart) => chart.status == ChartStatus.completed)
        .length;
    final recent = [...charts]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final continueChart = inProgress.isEmpty
        ? null
        : (inProgress..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
              .first;

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                onCreateChart: onCreateChart,
                displayName: profile.displayName,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 32) / 3;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        label: 'Tổng chart',
                        value: charts.length,
                        icon: Icons.grid_view_rounded,
                        width: width,
                      ),
                      _StatCard(
                        label: 'Đang thực hiện',
                        value: inProgress.length,
                        icon: Icons.draw_rounded,
                        width: width,
                      ),
                      _StatCard(
                        label: 'Đã hoàn thành',
                        value: completed,
                        icon: Icons.check_circle_rounded,
                        width: width,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              const SectionTitle(
                title: 'Tiếp tục móc',
                subtitle: 'Quay lại chart dang dở gần nhất',
              ),
              const SizedBox(height: 14),
              if (continueChart == null)
                Card(
                  child: EmptyState(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Chưa có chart đang thực hiện',
                    message:
                        'Tạo chart mới để bắt đầu thế giới móc len của bạn.',
                    action: PrimaryButton(
                      label: 'Tạo chart mới',
                      icon: Icons.add_rounded,
                      onPressed: onCreateChart,
                    ),
                  ),
                )
              else
                _ContinueCard(
                  chart: continueChart,
                  onContinue: () => onOpenProgress(continueChart.id),
                ),
              const SizedBox(height: 32),
              const SectionTitle(
                title: 'Chart gần đây',
                subtitle: 'Các mẫu bạn vừa xem hoặc chỉnh sửa',
              ),
              const SizedBox(height: 14),
              if (recent.isEmpty)
                const SizedBox(
                  height: 260,
                  child: EmptyState(
                    icon: Icons.grid_off_rounded,
                    title: 'Danh sách trống',
                    message: 'Chart mới sẽ xuất hiện ở đây.',
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1000
                        ? 3
                        : constraints.maxWidth >= 620
                        ? 2
                        : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recent.take(3).length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: columns == 1 ? 0.95 : 1.05,
                      ),
                      itemBuilder: (context, index) {
                        final chart = recent[index];
                        return ChartCard(
                          chart: chart,
                          onOpen: () => onOpenChart(chart.id),
                          onEdit: () => onEditChart(chart.id),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreateChart, required this.displayName});

  final VoidCallback onCreateChart;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final greeting = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xin chào, $displayName! 👋',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 5),
            Text(
              'Góc móc len của bạn',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Hôm nay mình cùng tạo điều gì thật xinh nhé ♡',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              greeting,
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Tạo chart mới',
                icon: Icons.add_rounded,
                onPressed: onCreateChart,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: greeting),
            PrimaryButton(
              label: 'Tạo chart mới',
              icon: Icons.add_rounded,
              onPressed: onCreateChart,
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: AppColors.sage,
              child: Text(
                displayName.trim().isEmpty
                    ? '?'
                    : displayName.trim()[0].toUpperCase(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.width,
  });

  final String label;
  final int value;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width < 180 ? double.infinity : width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySoft.withValues(alpha: 0.55),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.chart, required this.onContinue});

  final CrochetChart chart;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chart.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  '${chart.category} · Hàng ${chart.currentRow}/${chart.rowsCount}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: chart.progress,
                    minHeight: 10,
                    backgroundColor: AppColors.border,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(chart.progress * 100).round()}% hoàn thành',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Tiếp tục',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onContinue,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 24),
                PrimaryButton(
                  label: 'Tiếp tục',
                  icon: Icons.play_arrow_rounded,
                  onPressed: onContinue,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
