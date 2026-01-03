import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/widgets/app_button.dart';
import '../utils/constants.dart';
import '../utils/app_colors_extension.dart';

class CustomDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Function(DateTime) onDateSelected;

  const CustomDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  });

  @override
  State<CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> with SingleTickerProviderStateMixin {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showYearPicker = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);

    _animationController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _animationController.reset();
      _animationController.forward();
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _animationController.reset();
      _animationController.forward();
    });
  }

  bool _canGoToPreviousMonth() {
    final previousMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    return previousMonth.isAfter(DateTime(widget.firstDate.year, widget.firstDate.month - 1));
  }

  bool _canGoToNextMonth() {
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    return nextMonth.isBefore(lastMonth.add(const Duration(days: 1)));
  }

  List<DateTime> _getDaysInMonth() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    final daysInMonth = <DateTime>[];

    final firstWeekday = firstDayOfMonth.weekday % 7;
    if (firstWeekday > 0) {
      final previousMonth = DateTime(_currentMonth.year, _currentMonth.month, 0);
      for (int i = firstWeekday - 1; i >= 0; i--) {
        daysInMonth.add(DateTime(previousMonth.year, previousMonth.month, previousMonth.day - i));
      }
    }

    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      daysInMonth.add(DateTime(_currentMonth.year, _currentMonth.month, day));
    }
    final remainingDays = (7 - (daysInMonth.length % 7)) % 7;
    for (int day = 1; day <= remainingDays; day++) {
      daysInMonth.add(DateTime(_currentMonth.year, _currentMonth.month + 1, day));
    }

    return daysInMonth;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInCurrentMonth(DateTime date) {
    return date.month == _currentMonth.month && date.year == _currentMonth.year;
  }

  bool _isDateEnabled(DateTime date) {
    return !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
  }

  void _showYearPickerDialog() {
    setState(() {
      _showYearPicker = true;
    });
  }

  void _selectYear(int year) {
    setState(() {
      _currentMonth = DateTime(year, _currentMonth.month);
      _showYearPicker = false;
      _animationController.reset();
      _animationController.forward();
    });
  }

  Widget _buildYearPicker(AppColorsExtension colors) {
    final startYear = widget.firstDate.year;
    final endYear = widget.lastDate.year;
    final years = List.generate(endYear - startYear + 1, (index) => startYear + index).reversed.toList();

    return Container(
      key: const ValueKey('year_picker'),
      height: 300.h,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KBorderSize.borderRadius20)),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: KSpacing.sm.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: KSpacing.md.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: KSpacing.md.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showYearPicker = false;
                    });
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: KTextSize.medium.sp, color: colors.textSecondary),
                  ),
                ),
                Text(
                  'Select Year',
                  style: TextStyle(
                    fontSize: KTextSize.large.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(width: 60.w),
              ],
            ),
          ),
          SizedBox(height: KSpacing.sm.h),
          Expanded(
            child: ListView.builder(
              itemCount: years.length,
              itemBuilder: (context, index) {
                final year = years[index];
                final isSelected = year == _currentMonth.year;
                return InkWell(
                  onTap: () => _selectYear(year),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: KSpacing.md.h, horizontal: KSpacing.md.w),
                    color: isSelected ? colors.accentOrange.withValues(alpha: 0.1) : Colors.transparent,
                    child: Center(
                      child: Text(
                        '$year',
                        style: TextStyle(
                          fontSize: KTextSize.medium.sp,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? colors.accentOrange : colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (_showYearPicker) {
      return SafeArea(bottom: false, child: _buildYearPicker(colors));
    }

    final days = _getDaysInMonth();

    return SafeArea(child: _buildCalendarView(colors, days));
  }

  Widget _buildCalendarView(AppColorsExtension colors, List<DateTime> days) {
    return Container(
      key: const ValueKey('calendar_view'),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KBorderSize.borderRadius20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(top: KSpacing.sm.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          SizedBox(height: KSpacing.md.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: KSpacing.md.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _canGoToPreviousMonth() ? _previousMonth : null,
                    customBorder: const CircleBorder(),
                    splashColor: colors.iconSecondary.withAlpha(50),
                    child: Padding(
                      padding: EdgeInsets.all(KSpacing.md12.r),
                      child: SvgPicture.asset(
                        Assets.icons.navArrowLeft,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showYearPickerDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getMonthName(_currentMonth.month),
                        style: TextStyle(
                          fontSize: KTextSize.large.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${_currentMonth.year}',
                        style: TextStyle(
                          fontSize: KTextSize.large.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.accentOrange,
                          decorationColor: colors.accentOrange,
                        ),
                      ),
                      SvgPicture.asset(
                        Assets.icons.navArrowDown,
                        package: 'grab_go_shared',
                        height: 20.h,
                        width: 20.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _canGoToNextMonth() ? _nextMonth : null,
                    customBorder: const CircleBorder(),
                    splashColor: colors.iconSecondary.withAlpha(50),
                    child: Padding(
                      padding: EdgeInsets.all(KSpacing.md12.r),
                      child: SvgPicture.asset(
                        Assets.icons.navArrowRight,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: KSpacing.md.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: KSpacing.md.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: KTextSize.small.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: KSpacing.sm.h),

          SizedBox(
            height: 280.h,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: KSpacing.md.w),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final date = days[index];
                    final isSelected = _isSameDay(date, _selectedDate);
                    final isInMonth = _isInCurrentMonth(date);
                    final isEnabled = _isDateEnabled(date);
                    final isToday = _isSameDay(date, DateTime.now());

                    return GestureDetector(
                      onTap: isEnabled && isInMonth
                          ? () {
                              setState(() {
                                _selectedDate = date;
                              });
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.accentOrange
                              : isToday && isInMonth
                              ? colors.accentOrange.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius8),
                          border: isToday && !isSelected && isInMonth
                              ? Border.all(color: colors.accentOrange.withValues(alpha: 0.3), width: 1)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: KTextSize.medium.sp,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : !isInMonth
                                  ? colors.textSecondary.withValues(alpha: 0.3)
                                  : !isEnabled
                                  ? colors.textSecondary.withValues(alpha: 0.5)
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          SizedBox(height: KSpacing.lg.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: KSpacing.md.w),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                boxShadow: [
                  BoxShadow(
                    color: colors.accentOrange.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: AppButton(
                onPressed: () {
                  widget.onDateSelected(_selectedDate);
                  Navigator.of(context).pop();
                },
                backgroundColor: Colors.transparent,
                borderRadius: KBorderSize.borderRadius15,
                buttonText: "Done",
                textStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16.sp,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          SizedBox(height: KSpacing.lg.h),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
