import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/theme_scope.dart';
import 'common.dart';

typedef TaskSubmitCallback = void Function(
  String title,
  String sub,
  String deadline,
);

class TaskAddModal extends StatefulWidget {
  final TaskSubmitCallback onSubmit;

  const TaskAddModal({super.key, required this.onSubmit});

  @override
  State<TaskAddModal> createState() => _TaskAddModalState();
}

class _TaskAddModalState extends State<TaskAddModal> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController subController = TextEditingController();
  final TextEditingController deadlineController = TextEditingController();
  String? errorMessage;

  @override
  void dispose() {
    titleController.dispose();
    subController.dispose();
    deadlineController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (errorMessage != null) {
      setState(() => errorMessage = null);
    }
  }

  void _submit() {
    final String title = titleController.text.trim();
    final String sub = subController.text.trim();
    final String deadline = deadlineController.text.trim();
    if (title.isEmpty || sub.isEmpty || deadline.isEmpty) {
      setState(() => errorMessage = 'Lengkapi judul, konteks, dan deadline.');
      return;
    }

    widget.onSubmit(title, sub, deadline);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = ThemeScope.of(context).colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.lg),
          ),
          border: Border.all(color: c.border),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: AppSpacing.sheetHandleWidth,
                  height: AppSpacing.sheetHandleHeight,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: c.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.huge),
                  ),
                ),
              ),
              Text('Tambah Tugas', style: AppTypography.titleLarge(c.text)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tugas baru akan langsung tersimpan di tab Tugas.',
                style: AppTypography.caption(c.textSub),
              ),
              const SizedBox(height: AppSpacing.md),
              _taskField(
                controller: titleController,
                label: 'Judul tugas',
                hint: 'Contoh: Submit laporan mingguan',
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),
              _taskField(
                controller: subController,
                label: 'Konteks atau kategori',
                hint: 'Contoh: Akademik',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),
              _taskField(
                controller: deadlineController,
                label: 'Deadline',
                hint: 'Contoh: Besok, 08:00',
                textInputAction: TextInputAction.done,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppErrorMessage(message: errorMessage!),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          AppSpacing.target,
                          AppSpacing.target,
                        ),
                        foregroundColor: c.textMuted,
                      ),
                      child: Text(
                        'Batal',
                        style: AppTypography.label(c.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: PressableScale(
                      onTap: _submit,
                      semanticLabel: 'Simpan tugas baru',
                      tooltip: 'Simpan tugas',
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AppSpacing.target,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.blue,
                          borderRadius: BorderRadius.circular(AppSpacing.sm),
                        ),
                        child: Text(
                          'Simpan Tugas',
                          style: AppTypography.button(c.onAccent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputAction textInputAction,
    bool autofocus = false,
  }) {
    final AppColors c = ThemeScope.of(context).colors;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: textInputAction,
      onChanged: (_) => _clearError(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: AppTypography.body(c.textMuted),
        filled: true,
        fillColor: c.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: BorderSide(color: c.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: BorderSide(color: c.focus, width: 1.5),
        ),
      ),
      style: AppTypography.body(c.text),
    );
  }
}
