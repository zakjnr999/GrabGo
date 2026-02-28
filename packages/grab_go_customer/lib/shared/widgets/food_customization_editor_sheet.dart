import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/price_tag_widget.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class FoodCustomizationEditorSheet extends StatefulWidget {
  const FoodCustomizationEditorSheet({super.key, required this.item});

  final FoodItem item;

  static Future<FoodItem?> show({required BuildContext context, required FoodItem item}) {
    final colors = context.appColors;
    return showModalBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.86,
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(KBorderSize.borderRadius20)),
          ),
          child: FoodCustomizationEditorSheet(item: item),
        );
      },
    );
  }

  @override
  State<FoodCustomizationEditorSheet> createState() => _FoodCustomizationEditorSheetState();
}

class _FoodCustomizationEditorSheetState extends State<FoodCustomizationEditorSheet> {
  static const String _selectionDelimiter = '::';
  static const String _removeSelectionSentinel = '__REMOVE_PREFERENCE_SELECTION__';

  final TextEditingController _noteController = TextEditingController();
  String? _selectedPortionId;
  final Map<String, Set<String>> _selectedPreferenceOptionIdsByGroup = {};

  List<Map<String, dynamic>> get _portionOptions => widget.item.portionOptions
      .where((entry) => _parseBool(entry['isActive'], defaultValue: true))
      .toList(growable: false);

  List<Map<String, dynamic>> get _preferenceGroups =>
      widget.item.preferenceGroups.whereType<Map<String, dynamic>>().toList();

  bool get _hasCustomizationOptions => _portionOptions.isNotEmpty || _preferenceGroups.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _initializeSelections() {
    final existingPortionId = widget.item.selectedPortionId?.trim();
    if (existingPortionId != null && existingPortionId.isNotEmpty) {
      _selectedPortionId = existingPortionId;
    } else if (_portionOptions.isNotEmpty) {
      final defaultOption = _portionOptions.firstWhere(
        (entry) => _parseBool(entry['isDefault'], defaultValue: false),
        orElse: () => _portionOptions.first,
      );
      _selectedPortionId = _readOptionId(defaultOption);
    }

    for (final selected in widget.item.selectedPreferences) {
      final groupId = selected['groupId']?.toString().trim();
      final optionId = selected['optionId']?.toString().trim();
      if (groupId == null || groupId.isEmpty || optionId == null || optionId.isEmpty) {
        continue;
      }
      _selectedPreferenceOptionIdsByGroup.putIfAbsent(groupId, () => <String>{}).add(optionId);
    }

    for (final group in _preferenceGroups) {
      final groupId = _readOptionId(group);
      if (groupId == null) continue;
      if (_selectedPreferenceOptionIdsByGroup.containsKey(groupId)) continue;

      final options = ((group['options'] as List?) ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where((entry) => _parseBool(entry['isActive'], defaultValue: true))
          .toList(growable: false);
      if (options.isEmpty) continue;

      final maxSelections = _parseInt(group['maxSelections'], defaultValue: 1).clamp(1, 99);
      final defaults = options
          .where((entry) => _parseBool(entry['isDefault'], defaultValue: false))
          .map((entry) => _defaultSelectionKeyForOption(entry))
          .whereType<String>()
          .take(maxSelections)
          .toSet();
      if (defaults.isNotEmpty) {
        _selectedPreferenceOptionIdsByGroup[groupId] = defaults;
      }
    }

    _noteController.text = widget.item.itemNote?.trim() ?? '';
  }

  String? _readOptionId(Map<String, dynamic> option) {
    final raw = option['id'] ?? option['code'] ?? option['key'] ?? option['value'];
    final id = raw?.toString().trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  String _readOptionLabel(Map<String, dynamic> option, {String fallback = ''}) {
    return option['label']?.toString() ?? option['name']?.toString() ?? option['title']?.toString() ?? fallback;
  }

  bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return defaultValue;
  }

  int _parseInt(dynamic value, {required int defaultValue}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? defaultValue;
    return defaultValue;
  }

  double _parseDouble(dynamic value, {required double defaultValue}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? defaultValue;
    return defaultValue;
  }

  String _formatMoney(double value) => 'GHS ${value.toStringAsFixed(2)}';

  String _formatDeltaLabel(double delta) {
    if (delta == 0) return 'Included';
    final sign = delta > 0 ? '+' : '-';
    return '$sign${_formatMoney(delta.abs())}';
  }

  String _buildSelectionKey(String optionId, {String? sizeOptionId}) {
    final normalizedOptionId = optionId.trim();
    final normalizedSizeId = sizeOptionId?.trim();
    if (normalizedSizeId == null || normalizedSizeId.isEmpty) {
      return normalizedOptionId;
    }
    return '$normalizedOptionId$_selectionDelimiter$normalizedSizeId';
  }

  Map<String, String?> _parseSelectionKey(String key) {
    final normalized = key.trim();
    if (!normalized.contains(_selectionDelimiter)) {
      return {'optionId': normalized, 'sizeOptionId': null};
    }

    final index = normalized.indexOf(_selectionDelimiter);
    final optionId = normalized.substring(0, index).trim();
    final sizeOptionId = normalized.substring(index + _selectionDelimiter.length).trim();
    return {'optionId': optionId.isEmpty ? null : optionId, 'sizeOptionId': sizeOptionId.isEmpty ? null : sizeOptionId};
  }

  List<Map<String, dynamic>> _readPreferenceSizeOptions(Map<String, dynamic> option) {
    final raw = option['sizeOptions'] ?? option['sizes'] ?? option['priceTiers'] ?? option['variants'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((entry) => _parseBool(entry['isActive'], defaultValue: true))
        .toList(growable: false);
  }

  String? _findSelectionForOption({required String groupId, required String optionId}) {
    final selected = _selectedPreferenceOptionIdsByGroup[groupId];
    if (selected == null || selected.isEmpty) return null;

    for (final key in selected) {
      final parsed = _parseSelectionKey(key);
      if (parsed['optionId'] == optionId) return key;
    }
    return null;
  }

  Map<String, dynamic>? _resolveSelectedPortionSnapshot() {
    if (_selectedPortionId == null || _selectedPortionId!.trim().isEmpty) {
      return null;
    }
    final option = _portionOptions.firstWhere(
      (entry) => _readOptionId(entry) == _selectedPortionId,
      orElse: () => const <String, dynamic>{},
    );
    if (option.isEmpty) return null;

    final explicitPrice = _parseDouble(option['price'], defaultValue: double.nan);
    final basePrice = widget.item.price;
    final priceDelta = _parseDouble(option['priceDelta'], defaultValue: 0);
    return {
      'id': _readOptionId(option),
      'label': _readOptionLabel(option, fallback: _selectedPortionId!),
      'quantityLabel':
          option['quantityLabel']?.toString() ?? option['quantity']?.toString() ?? option['size']?.toString(),
      'price': explicitPrice.isFinite ? explicitPrice : (basePrice + priceDelta),
      'priceDelta': priceDelta,
    };
  }

  Map<String, dynamic>? _resolveSelectedSizeOption({
    required List<Map<String, dynamic>> sizeOptions,
    required String? selectedSizeId,
  }) {
    if (sizeOptions.isEmpty) return null;
    if (selectedSizeId != null && selectedSizeId.trim().isNotEmpty) {
      for (final size in sizeOptions) {
        if (_readOptionId(size) == selectedSizeId.trim()) return size;
      }
    }

    final defaultSize = sizeOptions.firstWhere(
      (size) => _parseBool(size['isDefault'], defaultValue: false),
      orElse: () => sizeOptions.length == 1 ? sizeOptions.first : const {},
    );
    if (defaultSize.isEmpty) return null;
    return defaultSize;
  }

  List<Map<String, dynamic>> _resolveSelectedPreferenceSnapshots() {
    final selected = <Map<String, dynamic>>[];

    for (final group in _preferenceGroups) {
      final groupId = _readOptionId(group);
      if (groupId == null) continue;
      final groupLabel = _readOptionLabel(group, fallback: groupId);
      final selectedKeys = _selectedPreferenceOptionIdsByGroup[groupId] ?? {};
      if (selectedKeys.isEmpty) continue;

      final options = ((group['options'] as List?) ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);

      for (final selectionKey in selectedKeys) {
        final parsed = _parseSelectionKey(selectionKey);
        final optionId = parsed['optionId'];
        if (optionId == null) continue;

        final option = options.firstWhere(
          (entry) => _readOptionId(entry) == optionId,
          orElse: () => const <String, dynamic>{},
        );
        if (option.isEmpty) continue;

        final sizeOptions = _readPreferenceSizeOptions(option);
        final selectedSize = _resolveSelectedSizeOption(
          sizeOptions: sizeOptions,
          selectedSizeId: parsed['sizeOptionId'],
        );
        final selectedSizeId = selectedSize == null ? null : _readOptionId(selectedSize);
        final selectedSizeLabel = selectedSize == null ? null : _readOptionLabel(selectedSize, fallback: '');
        final baseDelta = _parseDouble(option['priceDelta'], defaultValue: 0);
        final sizeDelta = selectedSize == null ? 0 : _parseDouble(selectedSize['priceDelta'], defaultValue: 0);
        final totalDelta = baseDelta + sizeDelta;
        final resolvedOptionId = _buildSelectionKey(optionId, sizeOptionId: selectedSizeId);
        final optionLabel = _readOptionLabel(option, fallback: optionId);

        selected.add({
          'groupId': groupId,
          'groupLabel': groupLabel,
          'optionId': resolvedOptionId,
          'optionBaseId': optionId,
          'optionLabel': selectedSizeLabel != null && selectedSizeLabel.isNotEmpty
              ? '$optionLabel ($selectedSizeLabel)'
              : optionLabel,
          'sizeOptionId': selectedSizeId,
          'sizeOptionLabel': selectedSizeLabel,
          'basePriceDelta': baseDelta,
          'sizePriceDelta': sizeDelta,
          'priceDelta': totalDelta,
        });
      }
    }

    selected.sort((a, b) {
      final groupCompare = (a['groupId']?.toString() ?? '').compareTo(b['groupId']?.toString() ?? '');
      if (groupCompare != 0) return groupCompare;
      return (a['optionId']?.toString() ?? '').compareTo(b['optionId']?.toString() ?? '');
    });

    return selected;
  }

  String? _buildCustomizationKey({
    required String foodId,
    String? portionId,
    required List<String> preferenceOptionIds,
    String? note,
  }) {
    final normalizedPortionId = portionId?.trim();
    final normalizedPreferences =
        preferenceOptionIds.map((entry) => entry.trim()).where((entry) => entry.isNotEmpty).toSet().toList()..sort();
    final normalizedNote = (note ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

    if ((normalizedPortionId == null || normalizedPortionId.isEmpty) &&
        normalizedPreferences.isEmpty &&
        normalizedNote.isEmpty) {
      return null;
    }

    return 'food:$foodId|portion:${normalizedPortionId ?? '-'}|prefs:${normalizedPreferences.join(',').isEmpty ? '-' : normalizedPreferences.join(',')}|note:${normalizedNote.isEmpty ? '-' : normalizedNote}';
  }

  double _resolvePrice() {
    var unitPrice = widget.item.price;
    final selectedPortion = _resolveSelectedPortionSnapshot();
    if (selectedPortion != null) {
      unitPrice = _parseDouble(selectedPortion['price'], defaultValue: unitPrice);
    }

    final selectedPreferences = _resolveSelectedPreferenceSnapshots();
    final preferenceDelta = selectedPreferences.fold<double>(0, (sum, entry) {
      return sum + _parseDouble(entry['priceDelta'], defaultValue: 0);
    });
    return unitPrice + preferenceDelta;
  }

  String? _validateSelection() {
    if (_portionOptions.isNotEmpty && (_selectedPortionId == null || _selectedPortionId!.trim().isEmpty)) {
      return 'Please choose a portion size.';
    }

    for (final group in _preferenceGroups) {
      final groupId = _readOptionId(group);
      if (groupId == null) continue;
      final minSelections = _parseInt(group['minSelections'], defaultValue: 0).clamp(0, 99);
      if (minSelections <= 0) continue;

      final selectedCount = _selectedPreferenceOptionIdsByGroup[groupId]?.length ?? 0;
      if (selectedCount < minSelections) {
        final label = _readOptionLabel(group, fallback: 'this preference');
        return minSelections == 1
            ? 'Please select an option for $label.'
            : 'Please select at least $minSelections options for $label.';
      }
    }

    return null;
  }

  void _save() {
    final validationError = _validateSelection();
    if (validationError != null) {
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: validationError,
        maxLines: 2,
      );
      return;
    }

    final selectedPortion = _resolveSelectedPortionSnapshot();
    final selectedPreferences = _resolveSelectedPreferenceSnapshots();
    final note = _noteController.text.trim();
    final customizationKey = _buildCustomizationKey(
      foodId: widget.item.id,
      portionId: selectedPortion?['id']?.toString(),
      preferenceOptionIds: selectedPreferences
          .map((entry) => entry['optionId']?.toString() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false),
      note: note,
    );

    final updated = widget.item.withCartCustomization(
      selectedPortion: selectedPortion,
      selectedPreferences: selectedPreferences,
      itemNote: note.isEmpty ? null : note,
      cartCustomizationKey: customizationKey,
      priceOverride: _resolvePrice(),
    );
    Navigator.of(context).pop(updated);
  }

  String _selectionRuleLabel({required int minSelections, required int maxSelections}) {
    if (minSelections <= 0 && maxSelections <= 1) {
      return 'Optional • choose up to 1';
    }
    if (minSelections <= 0) return 'Optional • choose up to $maxSelections';
    if (minSelections == maxSelections) {
      return 'Required • choose $minSelections';
    }
    return 'Required • choose $minSelections-$maxSelections';
  }

  String? _defaultSelectionKeyForOption(Map<String, dynamic> option) {
    final optionId = _readOptionId(option);
    if (optionId == null) return null;
    final sizeOptions = _readPreferenceSizeOptions(option);
    if (sizeOptions.isEmpty) return optionId;
    final defaultSize = _resolveSelectedSizeOption(sizeOptions: sizeOptions, selectedSizeId: null);
    final sizeId = defaultSize == null ? null : _readOptionId(defaultSize);
    return _buildSelectionKey(optionId, sizeOptionId: sizeId);
  }

  void _removePreferenceSelection({
    required String groupId,
    required String selectionKey,
    required int minSelections,
    required String groupLabel,
  }) {
    final selected = _selectedPreferenceOptionIdsByGroup[groupId];
    if (selected == null || !selected.contains(selectionKey)) return;

    if (selected.length <= minSelections) {
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: minSelections == 1
            ? '$groupLabel requires one selection.'
            : '$groupLabel requires at least $minSelections selections.',
        maxLines: 2,
      );
      return;
    }

    selected.remove(selectionKey);
    if (selected.isEmpty) {
      _selectedPreferenceOptionIdsByGroup.remove(groupId);
    }
    setState(() {});
  }

  void _setPreferenceSelection({
    required String groupId,
    required String optionId,
    required String selectionKey,
    required int minSelections,
    required int maxSelections,
    required String groupLabel,
  }) {
    final selected = _selectedPreferenceOptionIdsByGroup.putIfAbsent(groupId, () => <String>{});
    final existingSelectionKey = _findSelectionForOption(groupId: groupId, optionId: optionId);
    final isExactSelection = existingSelectionKey == selectionKey;

    if (isExactSelection) {
      _removePreferenceSelection(
        groupId: groupId,
        selectionKey: selectionKey,
        minSelections: minSelections,
        groupLabel: groupLabel,
      );
      return;
    }

    if (existingSelectionKey != null) {
      selected.remove(existingSelectionKey);
      selected.add(selectionKey);
      setState(() {});
      return;
    }

    if (maxSelections <= 1) {
      selected
        ..clear()
        ..add(selectionKey);
      setState(() {});
      return;
    }

    if (selected.length >= maxSelections) {
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: 'You can choose up to $maxSelections options for $groupLabel.',
        maxLines: 2,
      );
      return;
    }

    selected.add(selectionKey);
    setState(() {});
  }

  Future<String?> _showSizeBottomSheet({
    required String optionLabel,
    required List<Map<String, dynamic>> sizeOptions,
    required String? selectedSizeOptionId,
    required bool showRemoveAction,
  }) async {
    final colors = context.appColors;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(color: colors.divider, borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                SizedBox(height: 14.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    'Choose size for $optionLabel',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                ),
                SizedBox(height: 10.h),
                ...sizeOptions.map((sizeOption) {
                  final sizeOptionId = _readOptionId(sizeOption);
                  if (sizeOptionId == null) return const SizedBox.shrink();
                  final sizeLabel = _readOptionLabel(sizeOption, fallback: sizeOptionId);
                  final priceDelta = _parseDouble(sizeOption['priceDelta'], defaultValue: 0);
                  final isSelected = selectedSizeOptionId == sizeOptionId;

                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
                    dense: true,
                    onTap: () => Navigator.pop(sheetContext, sizeOptionId),
                    title: Text(
                      sizeLabel,
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                    subtitle: Text(
                      _formatDeltaLabel(priceDelta),
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                    ),
                    trailing: isSelected
                        ? SvgPicture.asset(
                            Assets.icons.checkCircleSolid,
                            package: 'grab_go_shared',
                            height: 18.h,
                            width: 18.w,
                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                          )
                        : Icon(Icons.circle_outlined, color: colors.inputBorder, size: 18.sp),
                  );
                }),
                if (showRemoveAction) ...[
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: AppButton(
                      onPressed: () => Navigator.pop(sheetContext, _removeSelectionSentinel),
                      width: double.infinity,
                      backgroundColor: colors.accentOrange,
                      borderRadius: KBorderSize.borderRadius15,
                      buttonText: "Remove Selection",
                      textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePreferenceTap({
    required String groupId,
    required String groupLabel,
    required Map<String, dynamic> option,
    required int minSelections,
    required int maxSelections,
  }) async {
    final optionId = _readOptionId(option);
    if (optionId == null) return;

    final sizeOptions = _readPreferenceSizeOptions(option);
    if (sizeOptions.isEmpty) {
      _setPreferenceSelection(
        groupId: groupId,
        optionId: optionId,
        selectionKey: optionId,
        minSelections: minSelections,
        maxSelections: maxSelections,
        groupLabel: groupLabel,
      );
      return;
    }

    final existingSelectionKey = _findSelectionForOption(groupId: groupId, optionId: optionId);
    final parsedExisting = existingSelectionKey == null
        ? const <String, String?>{'optionId': null, 'sizeOptionId': null}
        : _parseSelectionKey(existingSelectionKey);
    final selectedSizeOptionId = parsedExisting['sizeOptionId'];

    final pickedSizeOptionId = await _showSizeBottomSheet(
      optionLabel: _readOptionLabel(option, fallback: optionId),
      sizeOptions: sizeOptions,
      selectedSizeOptionId: selectedSizeOptionId,
      showRemoveAction: existingSelectionKey != null,
    );
    if (pickedSizeOptionId == null) return;

    if (pickedSizeOptionId == _removeSelectionSentinel) {
      _removePreferenceSelection(
        groupId: groupId,
        selectionKey: existingSelectionKey!,
        minSelections: minSelections,
        groupLabel: groupLabel,
      );
      return;
    }

    final selectionKey = _buildSelectionKey(optionId, sizeOptionId: pickedSizeOptionId);
    _setPreferenceSelection(
      groupId: groupId,
      optionId: optionId,
      selectionKey: selectionKey,
      minSelections: minSelections,
      maxSelections: maxSelections,
      groupLabel: groupLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          SizedBox(height: 10.h),
          Container(
            width: 42.w,
            height: 4.h,
            decoration: BoxDecoration(color: colors.divider, borderRadius: BorderRadius.circular(999)),
          ),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Customize ${widget.item.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                ),
                PriceTag(
                  notchPosition: NotchPosition.left,
                  price: _resolvePrice(),
                  currency: 'GHS',
                  priceColor: colors.accentOrange,
                  size: PriceTagSize.medium,
                  backgroundColor: colors.accentOrange.withValues(alpha: 0.2),
                  borderColor: Colors.transparent,
                  showShadow: false,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.inputBorder.withValues(alpha: 0.3)),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 0.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasCustomizationOptions)
                    Text(
                      'Customization',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                  if (_portionOptions.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    Text(
                      'Portion size',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: _portionOptions
                          .map((option) {
                            final optionId = _readOptionId(option);
                            if (optionId == null) return const SizedBox.shrink();
                            final isSelected = _selectedPortionId == optionId;
                            final label = _readOptionLabel(option, fallback: optionId);
                            final explicitPrice = _parseDouble(option['price'], defaultValue: double.nan);
                            final basePrice = widget.item.price;
                            final priceDelta = _parseDouble(option['priceDelta'], defaultValue: 0);
                            final priceText = explicitPrice.isFinite
                                ? _formatMoney(explicitPrice)
                                : _formatDeltaLabel(basePrice + priceDelta - basePrice);

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPortionId = optionId;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.accentOrange.withValues(alpha: 0.12)
                                      : colors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? colors.accentOrange : colors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      priceText,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                  ..._preferenceGroups.map((group) {
                    final groupId = _readOptionId(group);
                    if (groupId == null) return const SizedBox.shrink();
                    final options = ((group['options'] as List?) ?? const [])
                        .whereType<Map>()
                        .map((entry) => Map<String, dynamic>.from(entry))
                        .where((entry) => _parseBool(entry['isActive'], defaultValue: true))
                        .toList(growable: false);
                    if (options.isEmpty) return const SizedBox.shrink();

                    final minSelections = _parseInt(group['minSelections'], defaultValue: 0).clamp(0, 99);
                    final maxSelections = _parseInt(group['maxSelections'], defaultValue: 1).clamp(1, 99);
                    final groupLabel = _readOptionLabel(group, fallback: groupId);
                    final selected = _selectedPreferenceOptionIdsByGroup[groupId] ?? <String>{};

                    return Padding(
                      padding: EdgeInsets.only(top: 14.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupLabel,
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _selectionRuleLabel(minSelections: minSelections, maxSelections: maxSelections),
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                          ),
                          SizedBox(height: 8.h),
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: options
                                .map((option) {
                                  final optionId = _readOptionId(option);
                                  if (optionId == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final sizeOptions = _readPreferenceSizeOptions(option);
                                  final selectedSelectionKey = _findSelectionForOption(
                                    groupId: groupId,
                                    optionId: optionId,
                                  );
                                  final isSelected =
                                      selectedSelectionKey != null && selected.contains(selectedSelectionKey);
                                  final parsedSelection = selectedSelectionKey == null
                                      ? const <String, String?>{'optionId': null, 'sizeOptionId': null}
                                      : _parseSelectionKey(selectedSelectionKey);
                                  final selectedSize = _resolveSelectedSizeOption(
                                    sizeOptions: sizeOptions,
                                    selectedSizeId: parsedSelection['sizeOptionId'],
                                  );
                                  final optionLabel = _readOptionLabel(option, fallback: optionId);
                                  final baseDelta = _parseDouble(option['priceDelta'], defaultValue: 0);
                                  final selectedSizeLabel = selectedSize == null
                                      ? null
                                      : _readOptionLabel(selectedSize, fallback: '');
                                  final selectedSizeDelta = selectedSize == null
                                      ? 0
                                      : _parseDouble(selectedSize['priceDelta'], defaultValue: 0);

                                  final deltaLabel = sizeOptions.isEmpty
                                      ? _formatDeltaLabel(baseDelta)
                                      : isSelected
                                      ? [
                                          if (selectedSizeLabel != null && selectedSizeLabel.isNotEmpty)
                                            selectedSizeLabel,
                                          _formatDeltaLabel(baseDelta + selectedSizeDelta),
                                        ].join(' • ')
                                      : 'Custom';

                                  return GestureDetector(
                                    onTap: () => _handlePreferenceTap(
                                      groupId: groupId,
                                      groupLabel: groupLabel,
                                      option: option,
                                      minSelections: minSelections,
                                      maxSelections: maxSelections,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      curve: Curves.easeOut,
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colors.accentOrange.withValues(alpha: 0.12)
                                            : colors.backgroundSecondary,
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            optionLabel,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected ? colors.accentOrange : colors.textPrimary,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            deltaLabel,
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 14.h),
                  Text(
                    'Special instructions',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    minLines: 1,
                    inputFormatters: [LengthLimitingTextInputFormatter(200)],
                    style: TextStyle(fontSize: 13.sp, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Less salt, extra stew, no onions, etc.',
                      hintStyle: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.backgroundSecondary,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colors.accentOrange),
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_noteController.text.trim().length}/200',
                      style: TextStyle(fontSize: 11.sp, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
            child: AppButton(
              onPressed: _save,
              buttonText: 'Save customizations',
              width: double.infinity,
              backgroundColor: colors.accentOrange,
              borderRadius: KBorderSize.borderMedium,
              textStyle: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
