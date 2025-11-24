import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DurationPickerSheet extends StatefulWidget {
  static Future<int?> show(
    BuildContext context, {
    int? currentDuration,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DurationPickerSheet(currentDuration: currentDuration),
    );
  }

  final int? currentDuration;
  const DurationPickerSheet({Key? key, this.currentDuration}) : super(key: key);

  @override
  State<DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<DurationPickerSheet> {
  bool _showCustomInput = false;
  final _customController = TextEditingController();
  String _customUnit = 'seconds'; // 'seconds', 'minutes', 'hours', 'days'

  static const Color primaryColor = Color(0xFF2D1B69);
  static const Color secondaryColor = Color(0xFFB8A9E8);
  static const Color accentColor = Color(0xFF6B5B95);

  static final List<Map<String, dynamic>> presetOptions = [
    {'seconds': 5, 'label': '5 ثوانٍ', 'icon': Icons.flash_on},
    {'seconds': 10, 'label': '10 ثوانٍ', 'icon': Icons.flash_on},
    {'seconds': 30, 'label': '30 ثانية', 'icon': Icons.timer_outlined},
    {'seconds': 60, 'label': 'دقيقة', 'icon': Icons.schedule_outlined},
    {'seconds': 300, 'label': '5 دقائق', 'icon': Icons.access_time_outlined},
    {'seconds': 1800, 'label': '30 دقيقة', 'icon': Icons.access_time_outlined},
    {'seconds': 3600, 'label': 'ساعة', 'icon': Icons.watch_later_outlined},
    {'seconds': 21600, 'label': '6 ساعات', 'icon': Icons.watch_later_outlined},
    {'seconds': 43200, 'label': '12 ساعة', 'icon': Icons.watch_later_outlined},
    {'seconds': 86400, 'label': 'يوم', 'icon': Icons.today_outlined},
    {'seconds': 604800, 'label': 'أسبوع', 'icon': Icons.date_range_outlined},
    {'seconds': 2592000, 'label': '30 يوم', 'icon': Icons.calendar_month_outlined},
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  int? _getCustomSeconds() {
    final value = int.tryParse(_customController.text);
    if (value == null || value <= 0) return null;

    switch (_customUnit) {
      case 'seconds':
        return value;
      case 'minutes':
        return value * 60;
      case 'hours':
        return value * 3600;
      case 'days':
        return value * 86400;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),
          
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مدة اختفاء الرسائل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'تُحذف تلقائياً من الطرفين',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          if (!_showCustomInput) ...[
            Container(
              constraints: BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: presetOptions.length,
                itemBuilder: (context, index) {
                  final option = presetOptions[index];
                  final isSelected = widget.currentDuration == option['seconds'];

                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? primaryColor.withOpacity(0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? primaryColor 
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? primaryColor.withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          option['icon'],
                          color: isSelected ? primaryColor : accentColor,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        option['label'],
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 15,
                          color: isSelected ? primaryColor : Colors.grey[800],
                        ),
                      ),
                      trailing: isSelected
                          ? Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            )
                          : null,
                      onTap: () => Navigator.pop(context, option['seconds']),
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: 16),

            OutlinedButton.icon(
              icon: Icon(Icons.tune, size: 20),
              label: Text(
                'مدة مخصصة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor, width: 1.5),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  _showCustomInput = true;
                });
              },
            ),
          ],

          if (_showCustomInput) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(Icons.arrow_forward, size: 18),
                label: Text('الرجوع للخيارات'),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _showCustomInput = false;
                  });
                },
              ),
            ),
            
            SizedBox(height: 12),

            Row(
              children: [
                // حقل الإدخال
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                    decoration: InputDecoration(
                      labelText: 'المدة',
                      labelStyle: TextStyle(color: accentColor),
                      hintText: 'أدخل رقم',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.timer_outlined, color: primaryColor),
                      filled: true,
                      fillColor: primaryColor.withOpacity(0.05),
                    ),
                  ),
                ),
                
                SizedBox(width: 12),

                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _customUnit,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                      items: [
                        DropdownMenuItem(value: 'seconds', child: Text('ثوانٍ')),
                        DropdownMenuItem(value: 'minutes', child: Text('دقائق')),
                        DropdownMenuItem(value: 'hours', child: Text('ساعات')),
                        DropdownMenuItem(value: 'days', child: Text('أيام')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _customUnit = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),


            SizedBox(height: 16),

            // ✨ زر تأكيد - محدّث
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final seconds = _getCustomSeconds();
                  if (seconds != null && seconds > 0) {
                    Navigator.pop(context, seconds);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white),
                            SizedBox(width: 8),
                            Text('الرجاء إدخال مدة صحيحة'),
                          ],
                        ),
                        backgroundColor: Colors.red.shade400,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'تأكيد',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: 16),
        ],
      ),
    );
  }
}