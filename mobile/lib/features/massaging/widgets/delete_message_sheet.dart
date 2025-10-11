import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/colors.dart';

enum DeleteAction {
  deleteForMe,
  deleteAfterReading,
  deleteAfterMinutes,
  deleteNowForBoth,
}

class DeleteMessageSheet extends StatelessWidget {
  final void Function(DeleteAction action) onSelect;

  const DeleteMessageSheet({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint.withOpacity(.4),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'هل تريد حذف الرسالة؟',
              style: AppTextStyles.h4.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'اختر الطريقة المناسبة للحذف',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            _btn(context, 'حذف لي فقط', DeleteAction.deleteForMe),
            _btn(context, 'حذف بعد المشاهدة', DeleteAction.deleteAfterReading),
            _btn(context, 'حذف بعد 10 دقائق', DeleteAction.deleteAfterMinutes),
            _btn(context, 'حذف الآن للطرفين', DeleteAction.deleteNowForBoth),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext ctx, String title, DeleteAction action) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => onSelect(action),
        child: Text(title, style: AppTextStyles.buttonMedium),
      ),
    );
  }
}
