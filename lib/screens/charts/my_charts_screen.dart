import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/crochet_chart.dart';
import '../../state/app_state.dart';
import '../../widgets/chart_card.dart';
import '../../widgets/common_widgets.dart';

class MyChartsScreen extends StatefulWidget {
  const MyChartsScreen({
    super.key,
    required this.onOpenChart,
    required this.onEditChart,
  });

  final ValueChanged<String> onOpenChart;
  final ValueChanged<String> onEditChart;

  @override
  State<MyChartsScreen> createState() => _MyChartsScreenState();
}

class _MyChartsScreenState extends State<MyChartsScreen> {
  String _query = '';
  String _category = 'Tất cả';
  String _status = 'Tất cả';
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final charts = AppStateScope.of(context).charts.where(_matches).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Padding(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chart của tôi',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              const Text(
                'Tìm kiếm và quản lý các thiết kế của bạn.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _Filters(
                category: _category,
                status: _status,
                favoritesOnly: _favoritesOnly,
                onQueryChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                onCategoryChanged: (value) => setState(() => _category = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onFavoritesChanged: (value) =>
                    setState(() => _favoritesOnly = value),
              ),
              const SizedBox(height: 20),
              Text(
                '${charts.length} chart',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: charts.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Không tìm thấy chart',
                        message: 'Hãy thử thay đổi từ khóa hoặc bộ lọc.',
                        action: OutlinedButton(
                          onPressed: () => setState(() {
                            _query = '';
                            _category = 'Tất cả';
                            _status = 'Tất cả';
                            _favoritesOnly = false;
                          }),
                          child: const Text('Xóa bộ lọc'),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1000
                              ? 3
                              : constraints.maxWidth >= 620
                              ? 2
                              : 1;
                          return GridView.builder(
                            itemCount: charts.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: columns == 1 ? 0.95 : 1.05,
                                ),
                            itemBuilder: (context, index) {
                              final chart = charts[index];
                              return ChartCard(
                                chart: chart,
                                onOpen: () => widget.onOpenChart(chart.id),
                                onEdit: () => widget.onEditChart(chart.id),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matches(CrochetChart chart) {
    final matchesQuery =
        _query.isEmpty ||
        chart.name.toLowerCase().contains(_query) ||
        chart.description.toLowerCase().contains(_query);
    final matchesCategory =
        _category == 'Tất cả' || chart.category == _category;
    final matchesStatus = _status == 'Tất cả' || chart.status.label == _status;
    final matchesFavorite = !_favoritesOnly || chart.isFavorite;
    return matchesQuery && matchesCategory && matchesStatus && matchesFavorite;
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.category,
    required this.status,
    required this.favoritesOnly,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onFavoritesChanged,
  });

  final String category;
  final String status;
  final bool favoritesOnly;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onFavoritesChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Tìm theo tên hoặc mô tả...',
              ),
            );
            final controls = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Danh mục'),
                    items: AppConstants.chartCategories
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        value == null ? null : onCategoryChanged(value),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Trạng thái'),
                    items:
                        [
                              'Tất cả',
                              ...ChartStatus.values.map((item) => item.label),
                            ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        value == null ? null : onStatusChanged(value),
                  ),
                ),
                FilterChip(
                  selected: favoritesOnly,
                  onSelected: onFavoritesChanged,
                  avatar: const Icon(Icons.favorite_rounded, size: 18),
                  label: const Text('Yêu thích'),
                ),
              ],
            );
            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 12), controls],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }
}
