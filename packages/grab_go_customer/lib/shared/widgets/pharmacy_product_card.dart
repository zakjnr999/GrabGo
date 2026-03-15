import 'package:flutter/material.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/shared/widgets/service_product_card.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class PharmacyProductCard extends StatelessWidget {
  final PharmacyItem item;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final bool showStoreName;
  final bool showDiscountBadge;
  final bool showTopRatedBadge;
  final bool compactLayout;

  const PharmacyProductCard({
    super.key,
    required this.item,
    this.onTap,
    this.margin,
    this.width,
    this.showStoreName = true,
    this.showDiscountBadge = false,
    this.showTopRatedBadge = false,
    this.compactLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    return ServiceProductCard<PharmacyItem>(
      item: item,
      onTap: onTap,
      margin: margin,
      width: width,
      showStoreName: showStoreName,
      showDiscountBadge: showDiscountBadge,
      showTopRatedBadge: showTopRatedBadge,
      compactLayout: compactLayout,
      accentColor: context.appColors.servicePharmacy,
      imageUrl: item.catalogImage,
      unitLabel: item.unit,
      storeName: item.storeName,
      price: item.price,
      discountedPrice: item.discountedPrice,
      discountPercentage: item.discountPercentage,
      rating: item.rating,
      hasDiscount: item.hasDiscount,
    );
  }
}
