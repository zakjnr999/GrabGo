import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';

class VendorCatalogCategory {
  final String id;
  final String name;
  final VendorServiceType serviceType;

  const VendorCatalogCategory({
    required this.id,
    required this.name,
    required this.serviceType,
  });

  VendorCatalogCategory copyWith({
    String? name,
    VendorServiceType? serviceType,
  }) {
    return VendorCatalogCategory(
      id: id,
      name: name ?? this.name,
      serviceType: serviceType ?? this.serviceType,
    );
  }
}

class VendorCatalogItem {
  final String id;
  final String name;
  final String description;
  final VendorServiceType serviceType;
  final String categoryId;
  final double price;
  final int stock;
  final bool isAvailable;
  final bool requiresPrescription;

  const VendorCatalogItem({
    required this.id,
    required this.name,
    required this.description,
    required this.serviceType,
    required this.categoryId,
    required this.price,
    required this.stock,
    required this.isAvailable,
    required this.requiresPrescription,
  });

  VendorCatalogItem copyWith({
    String? name,
    String? description,
    VendorServiceType? serviceType,
    String? categoryId,
    double? price,
    int? stock,
    bool? isAvailable,
    bool? requiresPrescription,
  }) {
    return VendorCatalogItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      serviceType: serviceType ?? this.serviceType,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      requiresPrescription: requiresPrescription ?? this.requiresPrescription,
    );
  }
}

class VendorCatalogItemDraft {
  final String name;
  final String description;
  final VendorServiceType serviceType;
  final String categoryId;
  final double price;
  final int stock;
  final bool isAvailable;
  final bool requiresPrescription;

  const VendorCatalogItemDraft({
    required this.name,
    required this.description,
    required this.serviceType,
    required this.categoryId,
    required this.price,
    required this.stock,
    required this.isAvailable,
    required this.requiresPrescription,
  });
}

extension VendorServiceTypeCatalogX on VendorServiceType {
  String get label {
    return switch (this) {
      VendorServiceType.food => 'Food',
      VendorServiceType.grocery => 'Grocery',
      VendorServiceType.pharmacy => 'Pharmacy',
      VendorServiceType.grabMart => 'GrabMart',
    };
  }

  IconData get icon {
    return switch (this) {
      VendorServiceType.food => Icons.restaurant_rounded,
      VendorServiceType.grocery => Icons.local_grocery_store_rounded,
      VendorServiceType.pharmacy => Icons.local_pharmacy_outlined,
      VendorServiceType.grabMart => Icons.shopping_bag_outlined,
    };
  }
}
