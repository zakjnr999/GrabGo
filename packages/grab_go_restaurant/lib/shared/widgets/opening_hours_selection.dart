import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import '../widgets/text_input.dart';
import '../widgets/svg_icon.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';

class OpeningHoursSelection extends StatelessWidget {
  final Map<String, String> openingHours;
  final List<String> days;
  final Function(String) onHoursSelected;
  final Function(String, bool) onClosedToggled;
  final Map<String, bool> closedDays;

  const OpeningHoursSelection({
    super.key,
    required this.openingHours,
    required this.days,
    required this.onHoursSelected,
    required this.onClosedToggled,
    required this.closedDays,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isMobile = Responsive.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Opening Hours *',
          style: GoogleFonts.lato(
            fontSize: Responsive.getFontSize(context, isMobile ? 14 : 16),
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        ...days.map((day) {
          final isClosed = closedDays[day] ?? false;
          return Padding(
            padding: EdgeInsets.only(bottom: isMobile ? 12 : 16),
            child: Row(
              children: [
                SizedBox(
                  width: isMobile ? 80 : 100,
                  child: Text(
                    day,
                    style: GoogleFonts.lato(
                      fontSize: Responsive.getFontSize(context, isMobile ? 12 : 14),
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                // Closed toggle
                GestureDetector(
                  onTap: () => onClosedToggled(day, !isClosed),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? AppColors.errorRed.withValues(alpha: 0.1)
                          : AppColors.accentOrange.withValues(alpha: 0.1),
                      border: Border.all(
                        color: isClosed
                            ? AppColors.errorRed.withValues(alpha: 1)
                            : AppColors.accentOrange.withValues(alpha: 1),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgIcon(
                          svgImage: isClosed ? Assets.icons.boxIso : Assets.icons.check,
                          width: 16,
                          height: 16,
                          color: isClosed ? AppColors.errorRed : AppColors.accentOrange,
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        Text(
                          isClosed ? 'Closed' : 'Open',
                          style: GoogleFonts.lato(
                            fontSize: Responsive.getFontSize(context, isMobile ? 11 : 12),
                            fontWeight: FontWeight.w500,
                            color: isClosed ? AppColors.errorRed : AppColors.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                // Hours input (only show if not closed)
                if (!isClosed) ...[
                  Expanded(
                    child: TextInput(
                      controller: TextEditingController(text: openingHours[day] ?? '09:00 - 22:00'),
                      label: null,
                      hintText: '09:00 - 22:00',
                      borderColor: colors.border,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkBackground
                          : AppColors.white,
                      borderRadius: 8,
                      contentPadding: EdgeInsets.all(isMobile ? 10 : 12),
                      onTap: () => onHoursSelected(day),
                      readOnly: true,
                      suffixIcon: Padding(
                        padding: EdgeInsets.all(isMobile ? 8 : 10),
                        child: SvgIcon(
                          svgImage: Assets.icons.alarm,
                          width: 16,
                          height: 16,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkBackground
                            : AppColors.white,
                        border: Border.all(color: colors.border, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Restaurant Closed',
                        style: GoogleFonts.lato(
                          fontSize: Responsive.getFontSize(context, isMobile ? 11 : 12),
                          color: colors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
