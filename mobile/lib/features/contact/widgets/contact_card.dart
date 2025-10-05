import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';

class ContactCard extends StatelessWidget {
  final String name;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const ContactCard({
    super.key,
    required this.name,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              //  الصورة الشخصية ( افتراضية)
              const CircleAvatar(
                radius: 28,
                backgroundImage: AssetImage(
                  'assets/images/default_profile.png',
                ),
                // TODO: لاحقاً استبدلها بـ NetworkImage(imageUrlFromDatabase)
              ),

              const SizedBox(width: 12),

              // الاسم
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.contactName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // زر الحذف
              IconButton(
                onPressed: () => _showDeleteDialog(context),
                icon: const Icon(Icons.delete_outline),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.primary,
          title: Text(
            'هل أنت متأكد من حذف هذه الجهة؟',
            textAlign: TextAlign.center,
            style: AppTextStyles.dialogTitle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                style: AppTextStyles.dialogContent,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'حذف',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: AppColors.primary,
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
