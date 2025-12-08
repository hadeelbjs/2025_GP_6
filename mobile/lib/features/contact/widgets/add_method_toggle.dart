import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AddMethodToggle extends StatelessWidget {
  final bool phoneSelected;
  final VoidCallback onSelectPhone;
  final VoidCallback onSelectUsername;

  const AddMethodToggle({
    super.key,
    required this.phoneSelected,
    required this.onSelectPhone,
    required this.onSelectUsername,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : const Color(0xFFF0EEF6),
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: selected
                    ? AppTextStyles.buttonMedium.copyWith(color: Colors.white)
                    : AppTextStyles.buttonMedium.copyWith(
                        color: AppColors.primary,
                      ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(
          label: 'برقم الهاتف',
          selected: phoneSelected,
          onTap: onSelectPhone,
        ),
        const SizedBox(width: 10),
        pill(
          label: 'باسم المستخدم',
          selected: !phoneSelected,
          onTap: onSelectUsername,
        ),
      ],
    );
  }
}
