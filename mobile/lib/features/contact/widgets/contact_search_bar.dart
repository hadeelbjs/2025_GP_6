import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';

class ContactSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onSearch; //  المكبّر / Enter = بحث
  final ValueChanged<String>? onChanged; //   تصفية لحظية أثناء الكتابة
  final VoidCallback? onClear; // X

  const ContactSearchBar({
    super.key,
    this.controller,
    this.onSearch,
    this.onChanged,
    this.onClear,
  });

  @override
  State<ContactSearchBar> createState() => _ContactSearchBarState();
}

class _ContactSearchBarState extends State<ContactSearchBar> {
  late final TextEditingController _ctl;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _ctl = widget.controller ?? TextEditingController();
    _ctl.addListener(() => setState(() {})); //  ظهور زر X
  }

  @override
  void dispose() {
    if (_ownsController) _ctl.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    widget.onSearch?.call(_ctl.text.trim());
  }

  void _clear() {
    _ctl.clear();
    widget.onSearch?.call(''); //  النتائج كاملة
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _ctl,
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.search, //  "بحث" بالكيبورد
        onSubmitted: (_) => _triggerSearch(), // Enter = بحث
        onChanged: widget.onChanged, //  تصفية لحظية أثناء الكتابة
        style: AppTextStyles.searchText,
        decoration: InputDecoration(
          hintText: 'ابحث',
          hintStyle: AppTextStyles.hintLarge,

          // أيقونة المكبّر
          prefixIcon: IconButton(
            icon: Icon(Icons.search, color: AppColors.textHint),
            onPressed: _triggerSearch,
            splashRadius: 20,
          ),

          //  X يظهر فقط إذا فيه نص
          suffixIcon: (_ctl.text.isNotEmpty)
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: _clear,
                  splashRadius: 18,
                )
              : null,

          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
      ),
    );
  }
}
