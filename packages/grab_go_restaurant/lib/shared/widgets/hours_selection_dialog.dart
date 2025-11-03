import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/shared/utils/constants.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import '../widgets/text_input.dart';

class HoursSelectionDialog extends StatefulWidget {
  final String day;
  final String currentHours;
  final Function(String) onHoursSelected;

  const HoursSelectionDialog({super.key, required this.day, required this.currentHours, required this.onHoursSelected});

  @override
  State<HoursSelectionDialog> createState() => _HoursSelectionDialogState();
}

class _HoursSelectionDialogState extends State<HoursSelectionDialog> {
  late TextEditingController _hoursController;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController(text: widget.currentHours);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius12)),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      title: Text(
        'Set Hours for ${widget.day}',
        style: GoogleFonts.lato(color: isDark ? AppColors.white : AppColors.primary, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select your operating hours', style: GoogleFonts.lato(color: AppColors.grey)),
          SizedBox(height: 16),
          TextInput(
            controller: _hoursController,
            label: 'Hours',
            hintText: 'e.g., 09:00 - 22:00',
            borderColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
            borderRadius: 8,
            contentPadding: EdgeInsets.all(12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.lato(color: AppColors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onHoursSelected(_hoursController.text);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange, foregroundColor: AppColors.white),
          child: Text('Save', style: GoogleFonts.lato(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
