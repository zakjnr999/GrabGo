import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/shared/app_colors_extension.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';

class FoodTypeSelection extends StatelessWidget {
  final List<String> selectedFoodTypes;
  final List<String> foodTypes;
  final String? errorText;
  final Function(String) onFoodTypeToggled;

  const FoodTypeSelection({
    super.key,
    required this.selectedFoodTypes,
    required this.foodTypes,
    this.errorText,
    required this.onFoodTypeToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isMobile = Responsive.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Food Types *',
          style: GoogleFonts.lato(
            fontSize: Responsive.getFontSize(context, isMobile ? 14 : 16),
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
        Text(
          'Select all that apply to your restaurant',
          style: GoogleFonts.lato(fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12), color: AppColors.grey),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Wrap(
          spacing: isMobile ? 8 : 12,
          runSpacing: isMobile ? 8 : 12,
          children: foodTypes.map((foodType) {
            final isSelected = selectedFoodTypes.contains(foodType);
            return GestureDetector(
              key: ValueKey(foodType),
              onTap: () => onFoodTypeToggled(foodType),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentOrange
                      : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkBackground : AppColors.white),
                  border: Border.all(
                    color: isSelected ? AppColors.accentOrange : colors.border.withValues(alpha: 1),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  foodType,
                  style: GoogleFonts.lato(
                    fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                    fontWeight: FontWeight.w400,
                    color: isSelected ? AppColors.white : colors.text,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (errorText != null) ...[
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            errorText!,
            style: GoogleFonts.lato(
              fontSize: Responsive.getFontSize(context, 10),
              color: colors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
