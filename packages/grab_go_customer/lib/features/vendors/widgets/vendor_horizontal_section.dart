import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/trailing_see_all_card.dart';
import 'vendor_card.dart';

class VendorHorizontalSection extends StatelessWidget {
  final String title;
  final String icon;
  final List<VendorModel> vendors;
  final Function(VendorModel) onItemTap;
  final bool isLoading;
  final Color accentColor;
  final String? emptyText;
  final bool showClosedOnImage;
  final VoidCallback? onSeeAll;
  final bool highlightExclusiveBadge;
  final bool showEndSeeAllCard;

  const VendorHorizontalSection({
    super.key,
    required this.title,
    required this.icon,
    required this.vendors,
    required this.onItemTap,
    this.isLoading = false,
    required this.accentColor,
    this.emptyText,
    this.showClosedOnImage = false,
    this.onSeeAll,
    this.highlightExclusiveBadge = false,
    this.showEndSeeAllCard = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && vendors.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final cardWidth = (size.width * 0.72).clamp(220.0, 300.0);
    final imageHeight = (cardWidth * 0.45).clamp(90.0, 125.0);
    final cardHeight = (imageHeight + 120.h).clamp(210.0, 255.0);
    final showTrailingSeeAllCard = showEndSeeAllCard && !isLoading && vendors.isNotEmpty;
    final itemCount = vendors.length + (showTrailingSeeAllCard ? 1 : 0);

    return Column(
      children: [
        SectionHeader(title: title, sectionTotal: vendors.length, accentColor: accentColor, onSeeAll: onSeeAll),
        SizedBox(height: 12.h),

        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (showTrailingSeeAllCard && index == vendors.length) {
                return Padding(
                  padding: EdgeInsets.only(right: 20.w),
                  child: _buildTrailingSeeAllCard(context, width: cardWidth * 0.48, height: cardHeight - 8.h),
                );
              }

              final vendor = vendors[index];
              return Container(
                padding: EdgeInsets.only(right: 15.w),
                child: VendorCard(
                  vendor: vendor,
                  onTap: () => onItemTap(vendor),
                  width: cardWidth,
                  margin: EdgeInsets.symmetric(vertical: 4.h),
                  showClosedOnImage: showClosedOnImage,
                  highlightExclusiveBadge: highlightExclusiveBadge,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrailingSeeAllCard(BuildContext context, {required double width, required double height}) {
    return TrailingSeeAllCard(
      width: width,
      height: height,
      accentColor: accentColor,
      subtitle: 'View more vendors',
      onTap: onSeeAll,
    );
  }
}
