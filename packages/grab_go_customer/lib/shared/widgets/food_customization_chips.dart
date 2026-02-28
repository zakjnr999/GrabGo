import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class FoodCustomizationChips extends StatelessWidget {
  const FoodCustomizationChips({
    super.key,
    required this.item,
    required this.colors,
    this.compact = false,
    this.maxPreferenceLabels = 3,
    this.maxNoteLength = 36,
  });

  final FoodItem item;
  final AppColorsExtension colors;
  final bool compact;
  final int maxPreferenceLabels;
  final int maxNoteLength;

  @override
  Widget build(BuildContext context) {
    final labels = buildFoodCustomizationLabels(
      item,
      maxPreferenceLabels: maxPreferenceLabels,
      maxNoteLength: maxNoteLength,
    );
    if (labels.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: compact ? 4.w : 6.w,
      runSpacing: compact ? 4.h : 6.h,
      children: labels
          .map((label) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 7.w : 9.w,
                vertical: 4.h,
              ),
              decoration: BoxDecoration(
                color: colors.accentOrange.withValues(
                  alpha: compact ? 0.10 : 0.12,
                ),
                borderRadius: BorderRadius.circular(compact ? 7.r : 8.r),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: colors.accentOrange,
                  fontSize: compact ? 9.sp : 10.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  static List<String> buildFoodCustomizationLabels(
    FoodItem item, {
    int maxPreferenceLabels = 3,
    int maxNoteLength = 36,
  }) {
    final labels = <String>[];

    final selectedPortion = item.selectedPortion;
    if (selectedPortion != null) {
      final portionLabel = _readString(selectedPortion['label']);
      if (portionLabel != null && portionLabel.isNotEmpty) {
        labels.add(portionLabel);
      }
    }

    final preferenceLabels = item.selectedPreferences
        .map((entry) => _readString(entry['optionLabel']))
        .whereType<String>()
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    if (preferenceLabels.length > maxPreferenceLabels) {
      labels.addAll(preferenceLabels.take(maxPreferenceLabels));
      labels.add('+${preferenceLabels.length - maxPreferenceLabels} more');
    } else {
      labels.addAll(preferenceLabels);
    }

    final note = item.itemNote?.trim();
    if (note != null && note.isNotEmpty) {
      labels.add('Note: ${_truncate(note, maxNoteLength)}');
    }

    return labels;
  }

  static List<String> buildFoodCustomizationSummaryLines(
    FoodItem item, {
    int maxPreferenceLabels = 2,
    int maxNoteLength = 40,
  }) {
    final lines = <String>[];

    final selectedPortion = item.selectedPortion;
    if (selectedPortion != null) {
      final portionLabel = _readString(selectedPortion['label']);
      if (portionLabel != null && portionLabel.isNotEmpty) {
        lines.add('Portion: $portionLabel');
      }
    }

    final preferenceLabels = item.selectedPreferences
        .map((entry) => _readString(entry['optionLabel']))
        .whereType<String>()
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    if (preferenceLabels.isNotEmpty) {
      if (preferenceLabels.length > maxPreferenceLabels) {
        final visible = preferenceLabels.take(maxPreferenceLabels).join(', ');
        final remaining = preferenceLabels.length - maxPreferenceLabels;
        lines.add('Prefs: $visible +$remaining');
      } else {
        lines.add('Prefs: ${preferenceLabels.join(', ')}');
      }
    }

    final note = item.itemNote?.trim();
    if (note != null && note.isNotEmpty) {
      lines.add('Note: ${_truncate(note, maxNoteLength)}');
    }

    return lines;
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength).trim()}...';
  }
}
