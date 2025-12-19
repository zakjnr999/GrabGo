class FilterModel {
  // Price range
  double minPrice;
  double maxPrice;

  // Rating filter
  double? minRating;

  // Selected categories
  List<String> selectedCategories; // category IDs

  // Selected restaurants/stores
  List<String> selectedRestaurants; // restaurant/store IDs

  // Quick filters
  bool onSale;
  bool popular;
  bool isNew;
  bool fast;

  // Dietary preferences
  String? dietary; // 'Vegetarian', 'Vegan', 'Halal', 'Gluten-Free'

  // Distance filter
  String? distance; // 'Under 1 km', '1-3 km', '3-5 km', 'Any Distance'

  // Delivery time filter
  String? deliveryTime; // 'Under 20 min', '20-30 min', '30-45 min', 'Any Time'

  FilterModel({
    this.minPrice = 0,
    this.maxPrice = 10000,
    this.minRating,
    List<String>? selectedCategories,
    List<String>? selectedRestaurants,
    this.onSale = false,
    this.popular = false,
    this.isNew = false,
    this.fast = false,
    this.dietary,
    this.distance,
    this.deliveryTime,
  }) : selectedCategories = selectedCategories ?? [],
       selectedRestaurants = selectedRestaurants ?? [];

  // Check if any filter is active
  bool get isActive {
    // Price filter is active if range is different from default (0-10000)
    final isPriceFilterActive = minPrice != 0 || maxPrice != 10000;
    return isPriceFilterActive ||
        minRating != null ||
        selectedCategories.isNotEmpty ||
        selectedRestaurants.isNotEmpty ||
        onSale ||
        popular ||
        isNew ||
        fast ||
        dietary != null ||
        distance != null ||
        deliveryTime != null;
  }

  Map<String, dynamic> toJson() => {
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'minRating': minRating,
    'selectedCategories': selectedCategories,
    'selectedRestaurants': selectedRestaurants,
    'onSale': onSale,
    'popular': popular,
    'isNew': isNew,
    'fast': fast,
    'dietary': dietary,
    'distance': distance,
    'deliveryTime': deliveryTime,
  };

  factory FilterModel.fromJson(Map<String, dynamic> json) {
    final minPrice = (json['minPrice'] as num?)?.toDouble() ?? 0;
    final maxPrice = (json['maxPrice'] as num?)?.toDouble() ?? 10000;
    final minRating = json['minRating'] != null ? (json['minRating'] as num).toDouble() : null;

    // Validate and sanitize values
    final validatedMinPrice = (minPrice.isNaN || minPrice.isInfinite || minPrice < 0 ? 0.0 : minPrice).toDouble();
    final validatedMaxPrice =
        (maxPrice.isNaN || maxPrice.isInfinite || maxPrice < validatedMinPrice ? 10000.0 : maxPrice).toDouble();
    final validatedMinRating =
        minRating != null && (minRating.isNaN || minRating.isInfinite || minRating < 0 || minRating > 5)
        ? null
        : minRating;

    return FilterModel(
      minPrice: validatedMinPrice,
      maxPrice: validatedMaxPrice,
      minRating: validatedMinRating,
      selectedCategories:
          (json['selectedCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      selectedRestaurants:
          (json['selectedRestaurants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      onSale: json['onSale'] as bool? ?? false,
      popular: json['popular'] as bool? ?? false,
      isNew: json['isNew'] as bool? ?? false,
      fast: json['fast'] as bool? ?? false,
      dietary: json['dietary'] as String?,
      distance: json['distance'] as String?,
      deliveryTime: json['deliveryTime'] as String?,
    );
  }

  // Reset all filters
  void reset() {
    minPrice = 0;
    maxPrice = 10000;
    minRating = null;
    selectedCategories.clear();
    selectedRestaurants.clear();
    onSale = false;
    popular = false;
    isNew = false;
    fast = false;
    dietary = null;
    distance = null;
    deliveryTime = null;
  }

  // Create a copy
  FilterModel copyWith({
    double? minPrice,
    double? maxPrice,
    double? minRating,
    List<String>? selectedCategories,
    List<String>? selectedRestaurants,
    bool? onSale,
    bool? popular,
    bool? isNew,
    bool? fast,
    String? dietary,
    String? distance,
    String? deliveryTime,
  }) {
    return FilterModel(
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: minRating ?? this.minRating,
      selectedCategories: selectedCategories ?? [...this.selectedCategories],
      selectedRestaurants: selectedRestaurants ?? [...this.selectedRestaurants],
      onSale: onSale ?? this.onSale,
      popular: popular ?? this.popular,
      isNew: isNew ?? this.isNew,
      fast: fast ?? this.fast,
      dietary: dietary ?? this.dietary,
      distance: distance ?? this.distance,
      deliveryTime: deliveryTime ?? this.deliveryTime,
    );
  }
}
