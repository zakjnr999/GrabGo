import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/view/item_reviews_page.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/food_details_appbar.dart';
import 'package:grab_go_customer/shared/widgets/price_tag_widget.dart';
import 'package:grab_go_customer/shared/widgets/grocery_item_card.dart';
import 'package:grab_go_customer/shared/widgets/deal_card.dart';

class FoodDetails extends StatefulWidget {
  const FoodDetails({super.key, this.foodItem, this.groceryItem, this.pharmacyItem, this.grabMartItem})
    : assert(
        foodItem != null || groceryItem != null || pharmacyItem != null || grabMartItem != null,
        'At least one item type must be provided',
      );

  final FoodItem? foodItem;
  final GroceryItem? groceryItem;
  final PharmacyItem? pharmacyItem;
  final GrabMartItem? grabMartItem;

  bool get isGrocery => groceryItem != null;
  bool get isPharmacy => pharmacyItem != null;
  bool get isGrabMart => grabMartItem != null;
  bool get isStoreItem => isGrocery || isPharmacy || isGrabMart;

  @override
  State<FoodDetails> createState() => _FoodDetailsState();
}

class _FoodDetailsState extends State<FoodDetails> with TickerProviderStateMixin {
  static const String _preferenceSelectionDelimiter = '::';
  static const String _removePreferenceSelectionSentinel = '__REMOVE_PREFERENCE_SELECTION__';

  late FoodCategoryModel selectedCategory;
  int _restaurantItemsToShow = 3;
  final int _itemsPerPage = 3;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  final TextEditingController _itemNoteController = TextEditingController();
  String? _selectedPortionId;
  final Map<String, Set<String>> _selectedPreferenceOptionIdsByGroup = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _animationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _bounceController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _bounceController.forward();
    });

    _initializeCustomizationDrafts();
    _ensureFoodCatalogLoaded();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    _bounceController.dispose();
    _itemNoteController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore) {
        _loadMoreRestaurantItems();
      }
    }
  }

  bool get isPharmacy => widget.isPharmacy;
  bool get isGrabMart => widget.isGrabMart;
  bool get isStoreItem => widget.isStoreItem;

  void _ensureFoodCatalogLoaded() {
    if (widget.foodItem == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<FoodProvider>();
      if (provider.getAllFoods().isEmpty && !provider.isLoading) {
        provider.fetchCategories();
      }
    });
  }

  void _loadMoreRestaurantItems() {
    if (widget.foodItem == null) return;
    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _restaurantItemsToShow += _itemsPerPage;
          _isLoadingMore = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> get _portionOptions => widget.foodItem?.portionOptions ?? const <Map<String, dynamic>>[];

  List<Map<String, dynamic>> get _preferenceGroups =>
      widget.foodItem?.preferenceGroups ?? const <Map<String, dynamic>>[];

  bool get _isFoodCustomizationEnabled =>
      widget.foodItem != null && (_portionOptions.isNotEmpty || _preferenceGroups.isNotEmpty);

  void _initializeCustomizationDrafts() {
    if (widget.foodItem == null) return;

    if (_portionOptions.isNotEmpty) {
      final defaultOption = _portionOptions.firstWhere(
        (option) =>
            _parseBool(option['isDefault'], defaultValue: false) && _parseBool(option['isActive'], defaultValue: true),
        orElse: () => _portionOptions.firstWhere(
          (option) => _parseBool(option['isActive'], defaultValue: true),
          orElse: () => _portionOptions.first,
        ),
      );
      _selectedPortionId = _readOptionId(defaultOption);
    }

    for (final group in _preferenceGroups) {
      final groupId = _readOptionId(group);
      if (groupId == null) continue;

      final options = ((group['options'] as List?) ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
      if (options.isEmpty) continue;

      final maxSelections = ((group['maxSelections'] as num?)?.toInt() ?? 1).clamp(1, 99);
      final defaults = options
          .where(
            (option) =>
                _parseBool(option['isDefault'], defaultValue: false) &&
                _parseBool(option['isActive'], defaultValue: true),
          )
          .map(_buildDefaultPreferenceSelectionKey)
          .whereType<String>()
          .toList(growable: false);
      if (defaults.isNotEmpty) {
        _selectedPreferenceOptionIdsByGroup[groupId] = defaults.take(maxSelections).toSet();
      }
    }

    final note = widget.foodItem?.itemNote?.trim();
    if (note != null && note.isNotEmpty) {
      _itemNoteController.text = note;
    }
  }

  String? _readOptionId(Map<String, dynamic> option) {
    final raw = option['id'] ?? option['code'] ?? option['key'] ?? option['value'];
    final id = raw?.toString().trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  String _readOptionLabel(Map<String, dynamic> option, {String fallback = ''}) {
    return option['label']?.toString() ?? option['name']?.toString() ?? option['title']?.toString() ?? fallback;
  }

  double _readOptionPrice(Map<String, dynamic> option, {double fallback = 0}) {
    final value = option['price'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double _readOptionPriceDelta(Map<String, dynamic> option) {
    final value = option['priceDelta'] ?? option['additionalPrice'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
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

  String _buildPreferenceSelectionKey(String optionId, {String? sizeOptionId}) {
    final normalizedOptionId = optionId.trim();
    final normalizedSizeId = sizeOptionId?.trim();
    if (normalizedSizeId == null || normalizedSizeId.isEmpty) {
      return normalizedOptionId;
    }
    return '$normalizedOptionId$_preferenceSelectionDelimiter$normalizedSizeId';
  }

  Map<String, String?> _parsePreferenceSelectionKey(String selectionKey) {
    final normalized = selectionKey.trim();
    if (normalized.isEmpty) {
      return {'optionId': null, 'sizeOptionId': null};
    }

    final delimiterIndex = normalized.indexOf(_preferenceSelectionDelimiter);
    if (delimiterIndex <= 0) {
      return {'optionId': normalized, 'sizeOptionId': null};
    }

    final optionId = normalized.substring(0, delimiterIndex).trim();
    final sizeOptionId = normalized.substring(delimiterIndex + _preferenceSelectionDelimiter.length).trim();

    return {'optionId': optionId.isEmpty ? null : optionId, 'sizeOptionId': sizeOptionId.isEmpty ? null : sizeOptionId};
  }

  String? _findSelectedPreferenceKeyForOption({required String groupId, required String optionId}) {
    final selected = _selectedPreferenceOptionIdsByGroup[groupId];
    if (selected == null || selected.isEmpty) return null;

    for (final selectionKey in selected) {
      final parsed = _parsePreferenceSelectionKey(selectionKey);
      if (parsed['optionId'] == optionId) {
        return selectionKey;
      }
    }
    return null;
  }

  Map<String, dynamic>? _resolveDefaultSizeOption(List<Map<String, dynamic>> sizeOptions) {
    if (sizeOptions.isEmpty) return null;

    return sizeOptions.firstWhere(
      (entry) =>
          _parseBool(entry['isDefault'], defaultValue: false) && _parseBool(entry['isActive'], defaultValue: true),
      orElse: () => sizeOptions.length == 1 ? sizeOptions.first : <String, dynamic>{},
    );
  }

  Map<String, dynamic>? _resolveSelectedSizeOption({
    required List<Map<String, dynamic>> sizeOptions,
    String? selectedSizeOptionId,
  }) {
    if (sizeOptions.isEmpty) return null;

    if (selectedSizeOptionId != null && selectedSizeOptionId.trim().isNotEmpty) {
      for (final size in sizeOptions) {
        if (_readOptionId(size) == selectedSizeOptionId.trim()) {
          return size;
        }
      }
    }

    final fallback = _resolveDefaultSizeOption(sizeOptions);
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return null;
  }

  String? _buildDefaultPreferenceSelectionKey(Map<String, dynamic> option) {
    final optionId = _readOptionId(option);
    if (optionId == null) return null;

    final sizeOptions = _readPreferenceSizeOptions(option);
    if (sizeOptions.isEmpty) return optionId;

    final defaultSizeOption = _resolveDefaultSizeOption(sizeOptions);
    if (defaultSizeOption == null || defaultSizeOption.isEmpty) {
      return null;
    }

    final sizeOptionId = _readOptionId(defaultSizeOption);
    if (sizeOptionId == null) return null;
    return _buildPreferenceSelectionKey(optionId, sizeOptionId: sizeOptionId);
  }

  Map<String, dynamic>? _resolveSelectedPortionSnapshot() {
    if (!_isFoodCustomizationEnabled || _portionOptions.isEmpty) return null;
    if (_selectedPortionId == null || _selectedPortionId!.trim().isEmpty) {
      return null;
    }
    Map<String, dynamic>? option;
    for (final candidate in _portionOptions) {
      if (_readOptionId(candidate) == _selectedPortionId) {
        option = candidate;
        break;
      }
    }
    if (option == null) return null;

    final basePrice = widget.foodItem?.price ?? 0;
    final explicitPrice = _readOptionPrice(option, fallback: double.nan);
    final unitPrice = explicitPrice.isFinite ? explicitPrice : (basePrice + _readOptionPriceDelta(option));

    return {
      'id': _readOptionId(option),
      'label': _readOptionLabel(option, fallback: _selectedPortionId!),
      'quantityLabel':
          option['quantityLabel']?.toString() ?? option['quantity']?.toString() ?? option['size']?.toString(),
      'price': unitPrice,
      'priceDelta': _readOptionPriceDelta(option),
    };
  }

  List<Map<String, dynamic>> _resolveSelectedPreferenceSnapshots() {
    if (!_isFoodCustomizationEnabled || _preferenceGroups.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final selected = <Map<String, dynamic>>[];
    for (final group in _preferenceGroups) {
      final groupId = _readOptionId(group);
      if (groupId == null) continue;
      final groupLabel = _readOptionLabel(group, fallback: groupId).trim().isEmpty
          ? groupId
          : _readOptionLabel(group, fallback: groupId);
      final selectedKeys = _selectedPreferenceOptionIdsByGroup[groupId] ?? {};
      if (selectedKeys.isEmpty) continue;

      final options = ((group['options'] as List?) ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);

      for (final selectionKey in selectedKeys) {
        final parsedSelection = _parsePreferenceSelectionKey(selectionKey);
        final optionId = parsedSelection['optionId'];
        if (optionId == null) continue;

        final option = options.firstWhere(
          (entry) => _readOptionId(entry) == optionId,
          orElse: () => const <String, dynamic>{},
        );
        if (option.isEmpty) continue;

        final sizeOptions = _readPreferenceSizeOptions(option);
        final selectedSize = _resolveSelectedSizeOption(
          sizeOptions: sizeOptions,
          selectedSizeOptionId: parsedSelection['sizeOptionId'],
        );

        final selectedSizeId = selectedSize == null ? null : _readOptionId(selectedSize);
        final basePriceDelta = _readOptionPriceDelta(option);
        final sizePriceDelta = selectedSize == null ? 0 : _readOptionPriceDelta(selectedSize);
        final totalPriceDelta = basePriceDelta + sizePriceDelta;
        final resolvedSelectionKey = _buildPreferenceSelectionKey(optionId, sizeOptionId: selectedSizeId);
        final optionLabel = _readOptionLabel(option, fallback: optionId);
        final selectedSizeLabel = selectedSize == null ? null : _readOptionLabel(selectedSize, fallback: '');

        selected.add({
          'groupId': groupId,
          'groupLabel': groupLabel,
          'optionId': resolvedSelectionKey,
          'optionBaseId': optionId,
          'optionLabel': selectedSizeLabel != null && selectedSizeLabel.isNotEmpty
              ? '$optionLabel ($selectedSizeLabel)'
              : optionLabel,
          'sizeOptionId': selectedSizeId,
          'sizeOptionLabel': selectedSizeLabel,
          'basePriceDelta': basePriceDelta,
          'sizePriceDelta': sizePriceDelta,
          'priceDelta': totalPriceDelta,
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

  double _resolveCustomizedFoodPrice() {
    final food = widget.foodItem;
    if (food == null) return 0;

    var unitPrice = food.price;
    final selectedPortion = _resolveSelectedPortionSnapshot();
    if (selectedPortion != null) {
      final portionPrice = selectedPortion['price'];
      if (portionPrice is num) {
        unitPrice = portionPrice.toDouble();
      }
    }

    final selectedPreferences = _resolveSelectedPreferenceSnapshots();
    final preferenceDelta = selectedPreferences.fold<double>(0, (sum, entry) {
      final value = entry['priceDelta'];
      if (value is num) return sum + value.toDouble();
      if (value is String) return sum + (double.tryParse(value) ?? 0);
      return sum;
    });

    return unitPrice + preferenceDelta;
  }

  String? _buildFoodCustomizationKey({
    required String foodId,
    String? portionId,
    required List<String> preferenceOptionIds,
    String? note,
  }) {
    final normalizedPortionId = portionId?.trim();
    final normalizedPreferenceIds =
        preferenceOptionIds.map((entry) => entry.trim()).where((entry) => entry.isNotEmpty).toSet().toList()..sort();
    final normalizedNote = (note ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

    if ((normalizedPortionId == null || normalizedPortionId.isEmpty) &&
        normalizedPreferenceIds.isEmpty &&
        normalizedNote.isEmpty) {
      return null;
    }

    return 'food:$foodId|portion:${normalizedPortionId ?? '-'}|prefs:${normalizedPreferenceIds.join(',').isEmpty ? '-' : normalizedPreferenceIds.join(',')}|note:${normalizedNote.isEmpty ? '-' : normalizedNote}';
  }

  FoodItem _buildFoodCartItem() {
    final baseFood = widget.foodItem!;
    final selectedPortion = _resolveSelectedPortionSnapshot();
    final selectedPreferences = _resolveSelectedPreferenceSnapshots();
    final note = _itemNoteController.text.trim();
    final customizationKey = _buildFoodCustomizationKey(
      foodId: baseFood.id,
      portionId: selectedPortion?['id']?.toString(),
      preferenceOptionIds: selectedPreferences
          .map((entry) => entry['optionId']?.toString() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false),
      note: note,
    );

    return baseFood.withCartCustomization(
      selectedPortion: selectedPortion,
      selectedPreferences: selectedPreferences,
      itemNote: note.isEmpty ? null : note,
      cartCustomizationKey: customizationKey,
      priceOverride: _resolveCustomizedFoodPrice(),
    );
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
    if (value is String) {
      return int.tryParse(value.trim()) ?? defaultValue;
    }
    return defaultValue;
  }

  String _formatMoney(double value) => 'GHS ${value.toStringAsFixed(2)}';

  String _formatDeltaLabel(double delta) {
    if (delta == 0) return 'Included';
    final sign = delta > 0 ? '+' : '-';
    return '$sign${_formatMoney(delta.abs())}';
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

  String? _validateFoodCustomizationSelection() {
    if (widget.foodItem == null) return null;

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

  Future<void> _handleAddToCart(CartProvider provider, CartItem item) async {
    final validationError = _validateFoodCustomizationSelection();
    if (validationError != null) {
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: validationError,
        maxLines: 2,
      );
      return;
    }

    await provider.addToCart(item, context: context);
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
    final existingSelectionKey = _findSelectedPreferenceKeyForOption(groupId: groupId, optionId: optionId);
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

  Future<String?> _showPreferenceSizeBottomSheet({
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
                  final priceDelta = _readOptionPriceDelta(sizeOption);
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
                      onPressed: () => Navigator.pop(sheetContext, _removePreferenceSelectionSentinel),
                      width: double.infinity,
                      backgroundColor: colors.accentOrange,
                      borderRadius: KBorderSize.borderMedium,
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

  Future<void> _handlePreferenceOptionTap({
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

    final existingSelectionKey = _findSelectedPreferenceKeyForOption(groupId: groupId, optionId: optionId);
    final parsedExistingSelection = existingSelectionKey == null
        ? const <String, String?>{'optionId': null, 'sizeOptionId': null}
        : _parsePreferenceSelectionKey(existingSelectionKey);
    final selectedSizeOptionId = parsedExistingSelection['sizeOptionId'];

    final pickedSizeOptionId = await _showPreferenceSizeBottomSheet(
      optionLabel: _readOptionLabel(option, fallback: optionId),
      sizeOptions: sizeOptions,
      selectedSizeOptionId: selectedSizeOptionId,
      showRemoveAction: existingSelectionKey != null,
    );

    if (pickedSizeOptionId == null) return;

    if (pickedSizeOptionId == _removePreferenceSelectionSentinel) {
      _removePreferenceSelection(
        groupId: groupId,
        selectionKey: existingSelectionKey!,
        minSelections: minSelections,
        groupLabel: groupLabel,
      );
      return;
    }

    final selectionKey = _buildPreferenceSelectionKey(optionId, sizeOptionId: pickedSizeOptionId);
    if (existingSelectionKey != null && existingSelectionKey == selectionKey) {
      return;
    }
    _setPreferenceSelection(
      groupId: groupId,
      optionId: optionId,
      selectionKey: selectionKey,
      minSelections: minSelections,
      maxSelections: maxSelections,
      groupLabel: groupLabel,
    );
  }

  Widget _buildCustomizationSection(AppColorsExtension colors) {
    if (widget.foodItem == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(colors, 'Customize Order'),
          SizedBox(height: 12.h),
          if (_portionOptions.isNotEmpty) ...[
            Text(
              'Portion size',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _portionOptions
                  .where((option) => _parseBool(option['isActive'], defaultValue: true))
                  .map((option) {
                    final optionId = _readOptionId(option);
                    if (optionId == null) return const SizedBox.shrink();
                    final isSelected = _selectedPortionId == optionId;
                    final label = _readOptionLabel(option, fallback: optionId);
                    final explicitPrice = _readOptionPrice(option, fallback: double.nan);
                    final priceText = explicitPrice.isFinite
                        ? _formatMoney(explicitPrice)
                        : _formatDeltaLabel(_readOptionPriceDelta(option));

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
                          color: isSelected ? colors.accentOrange.withValues(alpha: 0.12) : colors.backgroundSecondary,
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
            SizedBox(height: 14.h),
          ],
          ..._preferenceGroups.map((group) {
            final groupId = _readOptionId(group);
            if (groupId == null) return const SizedBox.shrink();
            final options = ((group['options'] as List?) ?? const [])
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .where((option) => _parseBool(option['isActive'], defaultValue: true))
                .toList(growable: false);
            if (options.isEmpty) return const SizedBox.shrink();

            final minSelections = _parseInt(group['minSelections'], defaultValue: 0).clamp(0, 99);
            final maxSelections = _parseInt(group['maxSelections'], defaultValue: 1).clamp(1, 99);
            final groupLabel = _readOptionLabel(group, fallback: groupId);
            final selected = _selectedPreferenceOptionIdsByGroup[groupId] ?? <String>{};

            return Padding(
              padding: EdgeInsets.only(bottom: 14.h),
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
                          if (optionId == null) return const SizedBox.shrink();
                          final sizeOptions = _readPreferenceSizeOptions(option);
                          final selectedSelectionKey = _findSelectedPreferenceKeyForOption(
                            groupId: groupId,
                            optionId: optionId,
                          );
                          final isSelected = selectedSelectionKey != null && selected.contains(selectedSelectionKey);
                          final parsedSelection = selectedSelectionKey == null
                              ? const <String, String?>{'optionId': null, 'sizeOptionId': null}
                              : _parsePreferenceSelectionKey(selectedSelectionKey);
                          final selectedSize = _resolveSelectedSizeOption(
                            sizeOptions: sizeOptions,
                            selectedSizeOptionId: parsedSelection['sizeOptionId'],
                          );
                          final optionLabel = _readOptionLabel(option, fallback: optionId);
                          final baseDelta = _readOptionPriceDelta(option);
                          final selectedSizeLabel = selectedSize == null
                              ? null
                              : _readOptionLabel(selectedSize, fallback: '');
                          final selectedSizeDelta = selectedSize == null ? 0 : _readOptionPriceDelta(selectedSize);
                          final deltaLabel = sizeOptions.isEmpty
                              ? _formatDeltaLabel(baseDelta)
                              : isSelected
                              ? [
                                  if (selectedSizeLabel != null && selectedSizeLabel.isNotEmpty) selectedSizeLabel,
                                  _formatDeltaLabel(baseDelta + selectedSizeDelta),
                                ].join(' • ')
                              : 'Custom';

                          return GestureDetector(
                            onTap: () => _handlePreferenceOptionTap(
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
          Text(
            _isFoodCustomizationEnabled ? 'Special instructions' : 'Special instructions (optional)',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
          SizedBox(height: 8.h),
          if (!_isFoodCustomizationEnabled) ...[
            Text(
              'Tell the vendor how you want this order prepared.',
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
            ),
            SizedBox(height: 8.h),
          ],
          TextField(
            controller: _itemNoteController,
            onChanged: (_) => setState(() {}),
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
              '${_itemNoteController.text.trim().length}/200',
              style: TextStyle(fontSize: 11.sp, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String get itemName {
    if (widget.isGrocery) return widget.groceryItem!.name;
    if (isPharmacy) return widget.pharmacyItem!.name;
    if (isGrabMart) return widget.grabMartItem!.name;
    return widget.foodItem!.name;
  }

  String get itemDescription {
    if (widget.isGrocery) return widget.groceryItem!.description;
    if (isPharmacy) return widget.pharmacyItem!.description;
    if (isGrabMart) return widget.grabMartItem!.description;
    return widget.foodItem!.description;
  }

  String get itemImage {
    if (widget.isGrocery) return widget.groceryItem!.image;
    if (isPharmacy) return widget.pharmacyItem!.image;
    if (isGrabMart) return widget.grabMartItem!.image;
    return widget.foodItem!.image;
  }

  double get itemPrice {
    if (widget.isGrocery) return widget.groceryItem!.discountedPrice;
    if (isPharmacy) return widget.pharmacyItem!.discountedPrice;
    if (isGrabMart) return widget.grabMartItem!.discountedPrice;
    return widget.foodItem!.price;
  }

  double get itemRating {
    if (widget.isGrocery) return widget.groceryItem!.rating;
    if (isPharmacy) return widget.pharmacyItem!.rating;
    if (isGrabMart) return widget.grabMartItem!.rating;
    return widget.foodItem!.rating;
  }

  int get itemReviewCount {
    if (widget.isGrocery) return widget.groceryItem!.reviewCount;
    if (isPharmacy) return widget.pharmacyItem!.reviewCount;
    if (isGrabMart) return widget.grabMartItem!.reviewCount;
    return widget.foodItem?.reviewCount ?? 0;
  }

  String get itemIngredients {
    try {
      if (widget.isGrocery || isPharmacy || isGrabMart) {
        return '';
      }

      final foodItem = widget.foodItem;
      if (foodItem == null) return '';

      final ingredients = foodItem.ingredients;
      if (ingredients.isNotEmpty) {
        return ingredients.join(', ');
      }
    } catch (e) {
      return '';
    }
    return '';
  }

  bool get hasIngredients {
    try {
      if (widget.isGrocery || isPharmacy || isGrabMart) {
        return false;
      }
      final foodItem = widget.foodItem;
      if (foodItem == null) return false;

      return foodItem.ingredients.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  CartItem get cartItem {
    if (widget.isGrocery) return widget.groceryItem!;
    if (isPharmacy) return widget.pharmacyItem!;
    if (isGrabMart) return widget.grabMartItem!;
    return widget.foodItem!;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.paddingOf(context);
    Size size = MediaQuery.sizeOf(context);
    final itemDisplayPrice = widget.foodItem != null ? _resolveCustomizedFoodPrice() : itemPrice;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else {
            if (context.mounted) {
              context.go("/homepage");
            }
          }
        },
        child: Scaffold(
          backgroundColor: colors.backgroundPrimary,
          body: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: <Widget>[
                  FoodDetailsAppBar(foodItem: cartItem),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (isStoreItem) ...[
                                            Builder(
                                              builder: (context) {
                                                String brand = "";
                                                if (widget.isGrocery) brand = widget.groceryItem!.brand;
                                                if (isPharmacy) brand = widget.pharmacyItem!.brand;
                                                if (isGrabMart) brand = widget.grabMartItem!.brand;

                                                if (brand.isEmpty) return const SizedBox.shrink();
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      brand.toUpperCase(),
                                                      style: TextStyle(
                                                        color: colors.textSecondary,
                                                        fontSize: 12.sp,
                                                        fontWeight: FontWeight.w600,
                                                        letterSpacing: 1.0,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4.h),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                          Text(
                                            itemName,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 20.sp,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                            ),
                                          ),
                                          SizedBox(height: 6.h),
                                          if (isStoreItem)
                                            Builder(
                                              builder: (context) {
                                                String unit = "";
                                                if (widget.isGrocery) unit = widget.groceryItem!.unit;
                                                if (isPharmacy) unit = widget.pharmacyItem!.unit;
                                                if (isGrabMart) unit = widget.grabMartItem!.unit;

                                                return Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                                  decoration: BoxDecoration(
                                                    color: colors.inputBackground,
                                                    borderRadius: BorderRadius.circular(6.r),
                                                  ),
                                                  child: Text(
                                                    unit,
                                                    style: TextStyle(
                                                      color: colors.textSecondary,
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          else
                                            Text(
                                              "By ${widget.foodItem!.sellerName}",
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          if (isPharmacy && widget.pharmacyItem!.requiresPrescription) ...[
                                            SizedBox(height: 8.h),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: Colors.red.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6.r),
                                                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.description_outlined, size: 14.sp, color: Colors.red),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    "Prescription Required",
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 11.sp,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          SizedBox(height: 6.h),
                                          Row(
                                            children: [
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (index) => SvgPicture.asset(
                                                    Assets.icons.starSolid,
                                                    package: 'grab_go_shared',
                                                    height: 16,
                                                    width: 16,
                                                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              Text(
                                                itemRating.toStringAsFixed(1),
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  color: colors.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              Text(
                                                '($itemReviewCount ${itemReviewCount == 1 ? 'review' : 'reviews'})',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  color: colors.textSecondary,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              GestureDetector(
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ItemReviewsPage(
                                                      rating: itemRating,
                                                      reviewCount: itemReviewCount,
                                                    ),
                                                  ),
                                                ),
                                                child: SvgPicture.asset(
                                                  Assets.icons.navArrowRight,
                                                  package: 'grab_go_shared',
                                                  height: 12.h,
                                                  width: 12.w,
                                                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8.h),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              SvgPicture.asset(
                                                Assets.icons.timer,
                                                package: 'grab_go_shared',
                                                height: 16.h,
                                                width: 16.w,
                                                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                              ),
                                              SizedBox(width: 4.w),
                                              Text(
                                                widget.foodItem != null
                                                    ? widget.foodItem!.estimatedDeliveryTime
                                                    : "25-30",
                                                style: TextStyle(
                                                  fontFamily: 'Lato',
                                                  package: 'grab_go_shared',
                                                  color: colors.accentOrange,
                                                  fontSize: 13.sp,
                                                ),
                                              ),
                                              SizedBox(width: 10.w),
                                              if (widget.foodItem?.orderCount != 0) ...[
                                                Container(
                                                  height: 4.h,
                                                  width: 4.w,
                                                  decoration: BoxDecoration(
                                                    color: colors.textSecondary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                Text(
                                                  '${widget.foodItem?.orderCount.toString()} orders',
                                                  style: TextStyle(
                                                    fontFamily: 'Lato',
                                                    package: 'grab_go_shared',
                                                    color: colors.textPrimary,
                                                    fontWeight: FontWeight.w400,
                                                    fontSize: 13.sp,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    PriceTag(
                                      notchPosition: NotchPosition.left,
                                      price: itemDisplayPrice,
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

                              SizedBox(height: KSpacing.lg.h),

                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(colors, 'Description'),
                                    SizedBox(height: 12.h),
                                    ReadMoreText(
                                      itemDescription,
                                      trimMode: TrimMode.Line,
                                      trimLines: 3,
                                      colorClickableText: colors.accentOrange,
                                      trimCollapsedText: " Show more",
                                      trimExpandedText: " Show less",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        color: colors.textSecondary,
                                        height: 1.5,
                                      ),
                                      moreStyle: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.accentOrange,
                                      ),
                                      lessStyle: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.accentOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (widget.foodItem != null) ...[
                                SizedBox(height: KSpacing.lg.h),
                                _buildCustomizationSection(colors),
                              ],

                              if (hasIngredients) ...[
                                SizedBox(height: KSpacing.md.h),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionHeader(colors, 'Ingredients'),
                                      SizedBox(height: 12.h),
                                      Wrap(
                                        spacing: 8.w,
                                        runSpacing: 8.h,
                                        children: widget.foodItem!.ingredients.map((ingredient) {
                                          return Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: colors.accentOrange.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(20.r),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6.w,
                                                  height: 6.h,
                                                  decoration: BoxDecoration(
                                                    color: colors.accentOrange,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  ingredient,
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w800,
                                                    color: colors.accentOrange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              SizedBox(height: KSpacing.lg.h),

                              if (!widget.isGrocery && widget.foodItem != null)
                                Consumer<FoodProvider>(
                                  builder: (context, foodProvider, child) {
                                    final youMayLikeItems = foodProvider.getYouMayLikeItems(widget.foodItem!, limit: 5);

                                    if (youMayLikeItems.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(left: 20.w),
                                          child: _buildSectionHeader(colors, 'You May Like'),
                                        ),
                                        SizedBox(height: 12.h),
                                        Builder(
                                          builder: (context) {
                                            final cardWidth = (size.width * 0.62).clamp(200.0, 260.0);
                                            final imageHeight = (cardWidth * 0.45).clamp(90.0, 125.0);
                                            final cardHeight = (imageHeight + 110.h).clamp(208.0, 250.0);
                                            return SizedBox(
                                              height: cardHeight,
                                              child: ListView.builder(
                                                padding: EdgeInsets.only(left: 20.w),
                                                scrollDirection: Axis.horizontal,
                                                physics: const AlwaysScrollableScrollPhysics(),
                                                itemCount: youMayLikeItems.length,
                                                itemBuilder: (context, index) {
                                                  final item = youMayLikeItems[index];
                                                  return Padding(
                                                    padding: EdgeInsets.only(right: 12.w),
                                                    child: DealCard(
                                                      item: item,
                                                      discountPercent: item.discountPercentage.toInt(),
                                                      deliveryTime: item.estimatedDeliveryTime,
                                                      cardWidth: cardWidth,
                                                      onTap: () {
                                                        context.push('/foodDetails', extra: item);
                                                      },
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),

                              SizedBox(height: KSpacing.md.h),

                              if (!widget.isGrocery && widget.foodItem != null)
                                Consumer<FoodProvider>(
                                  builder: (context, foodProvider, child) {
                                    final allRestaurantFoods = foodProvider.getItemsFromRestaurant(
                                      restaurantId: widget.foodItem!.restaurantId,
                                      sellerId: widget.foodItem!.sellerId,
                                      sellerName: widget.foodItem!.sellerName,
                                      excludeItemId: widget.foodItem!.id,
                                    );

                                    if (allRestaurantFoods.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    final displayedItems = allRestaurantFoods.take(_restaurantItemsToShow).toList();
                                    final hasMoreItems = allRestaurantFoods.length > _restaurantItemsToShow;

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                                          child: _buildSectionHeader(colors, 'More From Restaurant'),
                                        ),
                                        SizedBox(height: 12.h),
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                                          child: Column(
                                            children: displayedItems.map((item) {
                                              return Padding(
                                                padding: EdgeInsets.only(bottom: 12.h),
                                                child: _buildRestaurantFoodItem(item, colors),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                        if (hasMoreItems && _isLoadingMore) ...[
                                          LoadingMore(
                                            colors: colors,
                                            spinnerColor: colors.accentOrange,
                                            borderColor: colors.accentOrange,
                                          ),
                                          SizedBox(height: 8.h),
                                        ],
                                      ],
                                    );
                                  },
                                )
                              else
                                // Similar Items for Groceries
                                Consumer<GroceryProvider>(
                                  builder: (context, groceryProvider, child) {
                                    final similarItems = groceryProvider.items
                                        .where(
                                          (item) =>
                                              item.categoryId == widget.groceryItem!.categoryId &&
                                              item.id != widget.groceryItem!.id,
                                        )
                                        .take(5)
                                        .toList();

                                    if (similarItems.isEmpty) return const SizedBox.shrink();

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                                          child: Text(
                                            "Similar Items",
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.w800,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        SizedBox(
                                          height: 250.h,
                                          child: ListView.builder(
                                            padding: EdgeInsets.only(left: 20.w),
                                            scrollDirection: Axis.horizontal,
                                            physics: const BouncingScrollPhysics(),
                                            itemCount: similarItems.length,
                                            itemBuilder: (context, index) {
                                              return SizedBox(
                                                width: 160.w,
                                                child: GroceryItemCard(
                                                  item: similarItems[index],
                                                  margin: EdgeInsets.only(right: 12.w, bottom: 10.h),
                                                  onTap: () {
                                                    context.push('/foodDetails', extra: similarItems[index]);
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                              SizedBox(height: KSpacing.md.h),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          bottomNavigationBar: Container(
            padding: EdgeInsets.only(bottom: padding.bottom),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.border),
                topRight: Radius.circular(KBorderSize.border),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Container(
              height: size.height * 0.10,
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(color: colors.backgroundPrimary),
              child: Consumer<CartProvider>(
                builder: (context, provider, _) {
                  final CartItem actionableCartItem = widget.foodItem != null ? _buildFoodCartItem() : cartItem;
                  final int qty = provider.getItemQuantity(
                    actionableCartItem,
                    includeFoodCustomizations: widget.foodItem != null,
                  );
                  final bool isInCart = qty > 0;
                  final bool isItemPending = provider.isItemOperationPendingForDisplay(
                    actionableCartItem,
                    includeFoodCustomizations: widget.foodItem != null,
                  );
                  final actionItem = provider.resolveItemForCartAction(
                    actionableCartItem,
                    includeFoodCustomizations: widget.foodItem != null,
                  );

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isInCart
                          ? Expanded(
                              child: Container(
                                height: size.height * 0.06,
                                margin: EdgeInsets.only(right: KSpacing.md.w),
                                padding: EdgeInsets.symmetric(horizontal: 10.w),
                                decoration: BoxDecoration(
                                  color: colors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        if (isItemPending) return;
                                        if (isInCart && actionItem != null) {
                                          provider.removeFromCart(actionItem);
                                        }
                                      },
                                      child: isItemPending
                                          ? SizedBox(
                                              width: 20.w,
                                              height: 20.w,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(colors.textSecondary),
                                              ),
                                            )
                                          : Icon(Icons.remove, color: colors.textSecondary, size: 20),
                                    ),
                                    Text(
                                      isItemPending ? '...' : qty.toString(),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w400,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        if (isItemPending) return;
                                        _handleAddToCart(provider, actionableCartItem);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(2.r),
                                        decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                                        child: isItemPending
                                            ? SizedBox(
                                                width: 20.w,
                                                height: 20.w,
                                                child: const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Icon(Icons.add, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),

                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.accentOrange,
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                          ),
                          child: AppButton(
                            onPressed: () {
                              if (isItemPending) return;
                              if (isInCart && actionItem != null) {
                                provider.removeItemCompletely(actionItem);
                              } else {
                                _handleAddToCart(provider, actionableCartItem);
                              }
                            },
                            backgroundColor: Colors.transparent,
                            borderRadius: KBorderSize.borderMedium,
                            buttonText: isItemPending ? "Updating..." : (isInCart ? "Remove from Cart" : "Add to Cart"),
                            textStyle: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Text _buildSectionHeader(AppColorsExtension colors, String name) {
    return Text(
      name,
      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
    );
  }

  Widget _buildRestaurantFoodItem(FoodItem item, AppColorsExtension colors) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final bool isInCart = cartProvider.hasItemInCart(item, includeFoodCustomizations: true);
        final bool isItemPending = cartProvider.isItemOperationPendingForDisplay(item, includeFoodCustomizations: true);
        final actionItem = cartProvider.resolveItemForCartAction(item, includeFoodCustomizations: true);

        return FoodItemCard(
          item: item,
          margin: EdgeInsets.zero,
          onTap: () {
            context.push("/foodDetails", extra: item);
          },
          trailing: GestureDetector(
            onTap: () {
              if (isItemPending) return;
              if (isInCart && actionItem != null) {
                cartProvider.removeItemCompletely(actionItem);
              } else {
                cartProvider.addToCart(item, context: context);
              }
            },
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isInCart ? colors.accentOrange : colors.backgroundSecondary,
                border: Border.all(color: isInCart ? colors.accentOrange : colors.inputBorder, width: 1),
              ),
              child: isItemPending
                  ? SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(isInCart ? Colors.white : colors.accentOrange),
                      ),
                    )
                  : SvgPicture.asset(
                      isInCart ? Assets.icons.check : Assets.icons.cart,
                      package: 'grab_go_shared',
                      height: 16.h,
                      width: 16.w,
                      colorFilter: ColorFilter.mode(isInCart ? Colors.white : colors.textPrimary, BlendMode.srcIn),
                    ),
            ),
          ),
        );
      },
    );
  }
}
