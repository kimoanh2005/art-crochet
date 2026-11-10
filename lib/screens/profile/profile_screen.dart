import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onOpenYarnColors,
    required this.onSignedOut,
  });

  final VoidCallback onOpenYarnColors;
  final VoidCallback onSignedOut;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final profile = state.profile;

    return SingleChildScrollView(
      padding: responsivePagePadding(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cá nhân',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final avatar = CircleAvatar(
                        radius: 45,
                        backgroundColor: AppColors.sage,
                        child: Text(
                          profile.initial,
                          style: const TextStyle(
                            fontSize: 34,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.email,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (profile.bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              profile.bio,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _showEditProfile(context),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Chỉnh sửa hồ sơ'),
                          ),
                        ],
                      );
                      if (constraints.maxWidth < 470) {
                        return Column(
                          children: [
                            avatar,
                            const SizedBox(height: 14),
                            details,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          avatar,
                          const SizedBox(width: 20),
                          Expanded(child: details),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(
                      Icons.palette_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text('Quản lý màu len'),
                  subtitle: const Text(
                    'Thêm, chỉnh sửa và xóa màu dùng trong thiết kế',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: onOpenYarnColors,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfile(BuildContext context) async {
    final state = AppStateScope.of(context);
    final nameController = TextEditingController(
      text: state.profile.displayName,
    );
    final emailController = TextEditingController(text: state.profile.email);
    final bioController = TextEditingController(text: state.profile.bio);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
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
                    decoration: const InputDecoration(
                      labelText: 'Tên hiển thị',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Vui lòng nhập tên hiển thị.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Email chưa đúng định dạng.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bioController,
                    maxLines: 3,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Giới thiệu ngắn',
                    ),
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
              try {
                await state.updateProfile(
                  displayName: nameController.text,
                  email: emailController.text,
                  bio: bioController.text,
                );
                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: const Text('Đã lưu hồ sơ.')));
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không thể cập nhật hồ sơ: $error')),
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
    emailController.dispose();
    bioController.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ đăng xuất khỏi phiên hiện tại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await AppStateScope.of(context).signOut();
        if (context.mounted) onSignedOut();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể đăng xuất: $error')),
          );
        }
      }
    }
  }
}
