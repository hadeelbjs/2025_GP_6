import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/app_text_styles.dart';

class ContactPrivacyScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;

  const ContactPrivacyScreen({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
  });

  @override
  State<ContactPrivacyScreen> createState() => _ContactPrivacyScreenState();
}

class _ContactPrivacyScreenState extends State<ContactPrivacyScreen> {
  bool screenshotsAllowed = false;
  String messageTimer = '10s';

  final List<String> _timers = ['Off', '5s', '10s', '30s', '1m', '5m'];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              //  الصورة + الاسم
              const SizedBox(height: 8),
              _Avatar(name: widget.name, avatarUrl: widget.avatarUrl),
              const SizedBox(height: 8),
              Text(
                widget.name,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              //  الإعدادات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // مؤقت الرسائل
                    _SettingCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'مؤقت الرسائل',
                                style: AppTextStyles.bodyLarge,
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () async {
                              final selected =
                                  await showModalBottomSheet<String>(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) {
                                      return _BottomPicker(
                                        title: 'اختر مؤقت الرسائل',
                                        options: _timers,
                                        selected: messageTimer,
                                      );
                                    },
                                  );
                              if (selected != null && mounted) {
                                setState(() => messageTimer = selected);
                                _snack('تم ضبط المؤقت على $messageTimer');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                messageTimer,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // لقطات الشاشة
                    _SettingCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.smartphone_rounded,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'لقطات الشاشة',
                                style: AppTextStyles.bodyLarge,
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: screenshotsAllowed,
                            activeColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) {
                              setState(() => screenshotsAllowed = v);
                              _snack(
                                v
                                    ? 'تم السماح بلقطات الشاشة'
                                    : 'تم منع لقطات الشاشة',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.right),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const _Avatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 98,
          height: 98,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
          ),
        ),
        CircleAvatar(
          radius: 44,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0] : '؟',
                  style: const TextStyle(fontSize: 28),
                )
              : null,
        ),
      ],
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _SettingCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BottomPicker extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;

  const _BottomPicker({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(title, style: AppTextStyles.h3),
            ),
            ...options.map((o) {
              final isSel = o == selected;
              return ListTile(
                onTap: () => Navigator.pop(context, o),
                title: Text(
                  o,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isSel ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
