import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/catalog/model/vendor_catalog_models.dart';

class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel() {
    searchController.addListener(_onSearchChanged);
  }

  final TextEditingController searchController = TextEditingController();

  final List<VendorCatalogCategory> _categories = [
    const VendorCatalogCategory(
      id: 'cat_food_main',
      name: 'Main Meals',
      serviceType: VendorServiceType.food,
    ),
    const VendorCatalogCategory(
      id: 'cat_food_drinks',
      name: 'Drinks',
      serviceType: VendorServiceType.food,
    ),
    const VendorCatalogCategory(
      id: 'cat_grocery_rice',
      name: 'Rice & Grains',
      serviceType: VendorServiceType.grocery,
    ),
    const VendorCatalogCategory(
      id: 'cat_pharmacy_otc',
      name: 'Over-the-counter',
      serviceType: VendorServiceType.pharmacy,
    ),
    const VendorCatalogCategory(
      id: 'cat_grabmart_home',
      name: 'Home Essentials',
      serviceType: VendorServiceType.grabMart,
    ),
  ];

  final List<VendorCatalogItem> _items = [
    const VendorCatalogItem(
      id: 'item_001',
      name: 'Smoked Chicken Jollof',
      description: 'Served with sauce and salad',
      serviceType: VendorServiceType.food,
      categoryId: 'cat_food_main',
      price: 45.0,
      stock: 14,
      isAvailable: true,
      requiresPrescription: false,
    ),
    const VendorCatalogItem(
      id: 'item_002',
      name: 'Orange Juice 500ml',
      description: 'Freshly squeezed and chilled',
      serviceType: VendorServiceType.food,
      categoryId: 'cat_food_drinks',
      price: 12.0,
      stock: 7,
      isAvailable: true,
      requiresPrescription: false,
    ),
    const VendorCatalogItem(
      id: 'item_003',
      name: 'Vitamin C 1000mg',
      description: 'Pack of 20 tablets',
      serviceType: VendorServiceType.pharmacy,
      categoryId: 'cat_pharmacy_otc',
      price: 18.0,
      stock: 3,
      isAvailable: true,
      requiresPrescription: false,
    ),
    const VendorCatalogItem(
      id: 'item_004',
      name: 'Basmati Rice 5kg',
      description: 'Premium long grain',
      serviceType: VendorServiceType.grocery,
      categoryId: 'cat_grocery_rice',
      price: 92.0,
      stock: 0,
      isAvailable: false,
      requiresPrescription: false,
    ),
    const VendorCatalogItem(
      id: 'item_005',
      name: 'Dishwashing Liquid',
      description: 'Lemon scent, 1L',
      serviceType: VendorServiceType.grabMart,
      categoryId: 'cat_grabmart_home',
      price: 15.0,
      stock: 22,
      isAvailable: true,
      requiresPrescription: false,
    ),
  ];

  final Set<String> _selectedItemIds = <String>{};
  VendorServiceType? _serviceFilter;
  String? _categoryFilterId;
  bool? _availabilityFilter;
  String _query = '';

  List<VendorCatalogCategory> get categories => List.unmodifiable(_categories);
  Set<String> get selectedItemIds => Set.unmodifiable(_selectedItemIds);
  int get selectedCount => _selectedItemIds.length;
  VendorServiceType? get serviceFilter => _serviceFilter;
  String? get categoryFilterId => _categoryFilterId;
  bool? get availabilityFilter => _availabilityFilter;

  List<VendorCatalogCategory> get visibleCategories {
    if (_serviceFilter == null) return List.unmodifiable(_categories);
    return _categories
        .where((category) => category.serviceType == _serviceFilter)
        .toList();
  }

  List<VendorCatalogItem> get filteredItems {
    return _items.where((item) {
      final matchesService =
          _serviceFilter == null || item.serviceType == _serviceFilter;
      final matchesCategory =
          _categoryFilterId == null || item.categoryId == _categoryFilterId;
      final matchesAvailability =
          _availabilityFilter == null ||
          item.isAvailable == _availabilityFilter;
      final search = _query.toLowerCase();
      final categoryName = categoryNameFor(item.categoryId).toLowerCase();
      final matchesSearch =
          search.isEmpty ||
          item.name.toLowerCase().contains(search) ||
          item.description.toLowerCase().contains(search) ||
          categoryName.contains(search);
      return matchesService &&
          matchesCategory &&
          matchesAvailability &&
          matchesSearch;
    }).toList();
  }

  String categoryNameFor(String id) {
    final category = _categories.cast<VendorCatalogCategory?>().firstWhere(
      (entry) => entry?.id == id,
      orElse: () => null,
    );
    return category?.name ?? 'Uncategorized';
  }

  VendorCatalogItem? itemById(String itemId) {
    return _items.cast<VendorCatalogItem?>().firstWhere(
      (entry) => entry?.id == itemId,
      orElse: () => null,
    );
  }

  void setServiceFilter(VendorServiceType? value) {
    if (_serviceFilter == value) return;
    _serviceFilter = value;
    if (_categoryFilterId != null) {
      final currentCategory = _categories
          .cast<VendorCatalogCategory?>()
          .firstWhere(
            (entry) => entry?.id == _categoryFilterId,
            orElse: () => null,
          );
      if (currentCategory == null ||
          (_serviceFilter != null &&
              currentCategory.serviceType != _serviceFilter)) {
        _categoryFilterId = null;
      }
    }
    notifyListeners();
  }

  void setCategoryFilter(String? categoryId) {
    if (_categoryFilterId == categoryId) return;
    _categoryFilterId = categoryId;
    notifyListeners();
  }

  void setAvailabilityFilter(bool? value) {
    if (_availabilityFilter == value) return;
    _availabilityFilter = value;
    notifyListeners();
  }

  void toggleItemSelection(String itemId) {
    if (_selectedItemIds.contains(itemId)) {
      _selectedItemIds.remove(itemId);
    } else {
      _selectedItemIds.add(itemId);
    }
    notifyListeners();
  }

  void selectItems(Set<String> itemIds) {
    if (_selectedItemIds.length == itemIds.length &&
        _selectedItemIds.containsAll(itemIds)) {
      return;
    }
    _selectedItemIds
      ..clear()
      ..addAll(itemIds);
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedItemIds.isEmpty) return;
    _selectedItemIds.clear();
    notifyListeners();
  }

  void setSelectedItemsAvailability(bool isAvailable) {
    if (_selectedItemIds.isEmpty) return;
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      if (_selectedItemIds.contains(item.id)) {
        _items[index] = item.copyWith(isAvailable: isAvailable);
      }
    }
    _selectedItemIds.clear();
    notifyListeners();
  }

  void adjustSelectedItemsStockBy(int delta) {
    if (_selectedItemIds.isEmpty || delta == 0) return;
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      if (!_selectedItemIds.contains(item.id)) continue;
      final nextStock = (item.stock + delta).clamp(0, 1000000).toInt();
      _items[index] = item.copyWith(
        stock: nextStock,
        isAvailable: nextStock == 0 ? false : item.isAvailable,
      );
    }
    _selectedItemIds.clear();
    notifyListeners();
  }

  void toggleItemAvailability(String itemId, bool isAvailable) {
    final index = _items.indexWhere((entry) => entry.id == itemId);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(isAvailable: isAvailable);
    notifyListeners();
  }

  void adjustItemStock(String itemId, int stock) {
    final index = _items.indexWhere((entry) => entry.id == itemId);
    if (index < 0) return;
    final sanitized = stock < 0 ? 0 : stock;
    _items[index] = _items[index].copyWith(
      stock: sanitized,
      isAvailable: sanitized == 0 ? false : _items[index].isAvailable,
    );
    notifyListeners();
  }

  void addItem(VendorCatalogItemDraft draft) {
    _items.insert(
      0,
      VendorCatalogItem(
        id: 'item_${DateTime.now().microsecondsSinceEpoch}',
        name: draft.name,
        description: draft.description,
        serviceType: draft.serviceType,
        categoryId: draft.categoryId,
        price: draft.price,
        stock: draft.stock,
        isAvailable: draft.isAvailable,
        requiresPrescription: draft.requiresPrescription,
      ),
    );
    notifyListeners();
  }

  void updateItem(String itemId, VendorCatalogItemDraft draft) {
    final index = _items.indexWhere((entry) => entry.id == itemId);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      name: draft.name,
      description: draft.description,
      serviceType: draft.serviceType,
      categoryId: draft.categoryId,
      price: draft.price,
      stock: draft.stock,
      isAvailable: draft.isAvailable,
      requiresPrescription: draft.requiresPrescription,
    );
    notifyListeners();
  }

  void removeItem(String itemId) {
    final index = _items.indexWhere((entry) => entry.id == itemId);
    if (index < 0) return;
    _items.removeAt(index);
    _selectedItemIds.remove(itemId);
    notifyListeners();
  }

  void addCategory({
    required String name,
    required VendorServiceType serviceType,
  }) {
    _categories.add(
      VendorCatalogCategory(
        id: 'cat_${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        serviceType: serviceType,
      ),
    );
    notifyListeners();
  }

  void renameCategory(String categoryId, String name) {
    final index = _categories.indexWhere((entry) => entry.id == categoryId);
    if (index < 0) return;
    _categories[index] = _categories[index].copyWith(name: name.trim());
    notifyListeners();
  }

  void removeCategory(String categoryId) {
    _categories.removeWhere((entry) => entry.id == categoryId);
    final fallbackCategory = _categories.isNotEmpty
        ? _categories.first.id
        : null;
    if (fallbackCategory != null) {
      for (var index = 0; index < _items.length; index++) {
        if (_items[index].categoryId == categoryId) {
          _items[index] = _items[index].copyWith(categoryId: fallbackCategory);
        }
      }
    }
    if (_categoryFilterId == categoryId) {
      _categoryFilterId = null;
    }
    notifyListeners();
  }

  void _onSearchChanged() {
    final nextValue = searchController.text.trim();
    if (_query == nextValue) return;
    _query = nextValue;
    notifyListeners();
  }

  @override
  void dispose() {
    searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }
}
