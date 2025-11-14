class FilterModel {
  // Price range
  double minPrice;
  double maxPrice;

  // Rating filter
  double? minRating;

  // Selected categories
  List<String> selectedCategories; // category IDs

  // Selected restaurants
  List<String> selectedRestaurants; // restaurant IDs

  FilterModel({
    this.minPrice = 0,
    this.maxPrice = 10000,
    this.minRating,
    List<String>? selectedCategories,
    List<String>? selectedRestaurants,
  }) : selectedCategories = selectedCategories ?? [],
       selectedRestaurants = selectedRestaurants ?? [];

  // Check if any filter is active
  bool get isActive {
    // Price filter is active if range is different from default (0-10000)
    final isPriceFilterActive = minPrice != 0 || maxPrice != 10000;
    return isPriceFilterActive || minRating != null || selectedCategories.isNotEmpty || selectedRestaurants.isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'minRating': minRating,
    'selectedCategories': selectedCategories,
    'selectedRestaurants': selectedRestaurants,
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
    );
  }

  // Reset all filters
  void reset() {
    minPrice = 0;
    maxPrice = 10000;
    minRating = null;
    selectedCategories.clear();
    selectedRestaurants.clear();
  }

  // Create a copy
  FilterModel copyWith({
    double? minPrice,
    double? maxPrice,
    double? minRating,
    List<String>? selectedCategories,
    List<String>? selectedRestaurants,
  }) {
    return FilterModel(
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: minRating ?? this.minRating,
      selectedCategories: selectedCategories ?? [...this.selectedCategories],
      selectedRestaurants: selectedRestaurants ?? [...this.selectedRestaurants],
    );
  }
}
