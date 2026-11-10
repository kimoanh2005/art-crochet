import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../models/yarn_color.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class YarnColorsScreen extends StatelessWidget {
  const YarnColorsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppStateScope.of(context).yarnColors;
    return Padding(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final addButton = constraints.maxWidth < 460
                      ? IconButton(
                          onPressed: () => _showColorForm(context),
                          tooltip: 'Thêm màu',
                          icon: const Icon(Icons.add_rounded),
                        )
                      : FilledButton.icon(
                          onPressed: () => _showColorForm(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Thêm màu'),
                        );
                  return Row(
                    children: [
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Quản lý màu len',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      addButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: colors.isEmpty
                    ? EmptyState(
                        icon: Icons.palette_outlined,
                        title: 'Chưa có màu len',
                        message: 'Thêm màu đầu tiên cho bảng màu của bạn.',
                        action: PrimaryButton(
                          label: 'Thêm màu',
                          icon: Icons.add_rounded,
                          onPressed: () => _showColorForm(context),
                        ),
                      )
                    : ListView.separated(
                        itemCount: colors.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final color = colors[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: _hexColor(color.hexCode),
                                radius: 24,
                              ),
                              title: Text(
                                color.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                [color.hexCode, color.brand, color.yarnCode]
                                    .where((value) => value.isNotEmpty)
                                    .join(' · '),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _showColorForm(context, color: color);
                                  } else {
                                    _confirmDelete(context, color);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Chỉnh sửa'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.delete_outline,
                                        color: AppColors.danger,
                                      ),
                                      title: Text(
                                        'Xóa',
                                        style: TextStyle(
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Future<void> _confirmDelete(BuildContext context, YarnColor color) async {
    final used = AppStateScope.of(context).charts.any(
      (chart) => chart.cells.values.any(
        (cell) => cell.colorHex.toUpperCase() == color.hexCode.toUpperCase(),
      ),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa màu len?'),
        content: Text(
          used
              ? 'Màu “${color.name}” đang được dùng trong chart. Xóa màu khỏi bảng màu sẽ không đổi các ô đã tô.'
              : 'Bạn có chắc muốn xóa “${color.name}” khỏi bảng màu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await AppStateScope.of(context).deleteYarnColor(color.id);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể xóa màu len: $error')),
          );
        }
      }
    }
  }

  Future<void> _showColorForm(BuildContext context, {YarnColor? color}) async {
    final nameController = TextEditingController(text: color?.name ?? '');
    final hexController = TextEditingController(text: color?.hexCode ?? '#');
    final brandController = TextEditingController(text: color?.brand ?? '');
    final codeController = TextEditingController(text: color?.yarnCode ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(color == null ? 'Thêm màu len' : 'Chỉnh sửa màu len'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tên màu *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Vui lòng nhập tên màu.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: hexController,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[#0-9A-Fa-f]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mã HEX *',
                      hintText: '#F2C6D2',
                    ),
                    validator: (value) =>
                        RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value ?? '')
                        ? null
                        : 'Dùng định dạng #RRGGBB.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: brandController,
                    decoration: const InputDecoration(labelText: 'Thương hiệu'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(labelText: 'Mã sản phẩm'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final state = AppStateScope.of(context);
              final savedColor = YarnColor(
                id: color?.id ?? '',
                name: nameController.text.trim(),
                hexCode: hexController.text.trim().toUpperCase(),
                brand: brandController.text.trim(),
                yarnCode: codeController.text.trim(),
              );
              try {
                if (color == null) {
                  await state.addYarnColor(savedColor);
                } else {
                  await state.updateYarnColor(savedColor);
                }
                if (context.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không thể lưu màu len: $error')),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    nameController.dispose();
    hexController.dispose();
    brandController.dispose();
    codeController.dispose();
  }
}

Color _hexColor(String hex) =>
    Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
