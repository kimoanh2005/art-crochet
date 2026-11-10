import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/crochet_chart.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class CreateChartScreen extends StatefulWidget {
  const CreateChartScreen({
    super.key,
    required this.onCancel,
    required this.onCreated,
  });

  final VoidCallback onCancel;
  final ValueChanged<String> onCreated;

  @override
  State<CreateChartScreen> createState() => _CreateChartScreenState();
}

class _CreateChartScreenState extends State<CreateChartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rowsController = TextEditingController(
    text: '${AppConstants.defaultChartSize}',
  );
  final _columnsController = TextEditingController(
    text: '${AppConstants.defaultChartSize}',
  );
  String _category = 'Hoa';
  ChartType _chartType = ChartType.pixel;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _rowsController.dispose();
    _columnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tạo chart mới',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Bắt đầu với vài thông tin cơ bản, sau đó bạn sẽ được đưa tới trình thiết kế.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Tên chart *',
                            hintText: 'Ví dụ: Hoa tulip mini',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Vui lòng nhập tên chart.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: const InputDecoration(
                            labelText: 'Danh mục',
                          ),
                          items: AppConstants.chartCategories
                              .skip(1)
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _category = value ?? _category),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Chọn kiểu thiết kế',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cards = ChartType.values
                                .map(
                                  (type) => _ChartTypeCard(
                                    type: type,
                                    selected: _chartType == type,
                                    onTap: () =>
                                        setState(() => _chartType = type),
                                  ),
                                )
                                .toList();
                            if (constraints.maxWidth < 620) {
                              return Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < cards.length;
                                    index++
                                  ) ...[
                                    cards[index],
                                    if (index < cards.length - 1)
                                      const SizedBox(height: 10),
                                  ],
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (
                                  var index = 0;
                                  index < cards.length;
                                  index++
                                ) ...[
                                  Expanded(child: cards[index]),
                                  if (index < cards.length - 1)
                                    const SizedBox(width: 10),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Mô tả',
                            hintText: 'Ghi chú ngắn về ý tưởng của bạn...',
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final rows = _DimensionField(
                              label: _chartType == ChartType.circular
                                  ? 'Số vòng'
                                  : 'Số hàng',
                              controller: _rowsController,
                              suffix: switch (_chartType) {
                                ChartType.pixel => 'hàng',
                                ChartType.stitchSymbols => 'hàng',
                                ChartType.circular => 'vòng',
                              },
                            );
                            final columns = _DimensionField(
                              label: switch (_chartType) {
                                ChartType.pixel => 'Số cột',
                                ChartType.stitchSymbols =>
                                  'Số vị trí mũi mỗi hàng',
                                ChartType.circular => 'Số vị trí mũi mỗi vòng',
                              },
                              controller: _columnsController,
                              suffix: _chartType == ChartType.pixel
                                  ? 'ô'
                                  : 'mũi',
                            );
                            if (constraints.maxWidth < 480) {
                              return Column(
                                children: [
                                  rows,
                                  const SizedBox(height: 16),
                                  columns,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: rows),
                                const SizedBox(width: 16),
                                Expanded(child: columns),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _chartType == ChartType.pixel
                              ? 'Kích thước từ ${AppConstants.minChartSize} đến ${AppConstants.maxChartSize} ô mỗi chiều.'
                              : 'Từ ${AppConstants.minChartSize} đến ${AppConstants.maxChartSize} hàng/vòng; số vị trí mũi tối đa mỗi hàng/vòng cũng trong khoảng này.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: widget.onCancel,
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Hủy'),
                            ),
                            PrimaryButton(
                              label: _submitting ? 'Đang tạo...' : 'Tạo chart',
                              icon: Icons.draw_rounded,
                              onPressed: _submitting ? null : _submit,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final chart = await AppStateScope.of(context).createChart(
        name: _nameController.text.trim(),
        category: _category,
        description: _descriptionController.text.trim(),
        chartType: _chartType,
        rows: int.parse(_rowsController.text),
        columns: int.parse(_columnsController.text),
      );
      if (mounted) widget.onCreated(chart.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể tạo chart: $error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _ChartTypeCard extends StatelessWidget {
  const _ChartTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ChartType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      ChartType.pixel => Icons.grid_on_rounded,
      ChartType.stitchSymbols => Icons.format_list_numbered_rounded,
      ChartType.circular => Icons.radio_button_unchecked_rounded,
    };
    return Material(
      color: selected
          ? AppColors.primarySoft.withValues(alpha: 0.45)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                type.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                type.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({
    required this.label,
    required this.controller,
    this.suffix = 'ô',
  });

  final String label;
  final TextEditingController controller;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) {
        final number = int.tryParse(value ?? '');
        if (number == null) return 'Nhập một số hợp lệ.';
        if (number < AppConstants.minChartSize ||
            number > AppConstants.maxChartSize) {
          return '${AppConstants.minChartSize}–${AppConstants.maxChartSize}';
        }
        return null;
      },
    );
  }
}
