import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'vendor_card.dart';

class VendorHorizontalSection extends StatelessWidget {
  final String title;
  final String icon;
  final List<VendorModel> vendors;
  final Function(VendorModel) onItemTap;
  final bool isLoading;
  final Color accentColor;
  final String? emptyText;

  const VendorHorizontalSection({
    super.key,
    required this.title,
    required this.icon,
    required this.vendors,
    required this.onItemTap,
    this.isLoading = false,
    required this.accentColor,
    this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && vendors.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final cardWidth = (size.width * 0.72).clamp(220.0, 300.0);
    final cardHeight = (cardWidth * 0.75).clamp(180.0, 210.0);

    return Column(
      children: [
        SectionHeader(title: title, sectionTotal: vendors.length, accentColor: accentColor, onSeeAll: () {}),
        SizedBox(height: 12.h),

        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              return Container(
                padding: EdgeInsets.only(right: 15.w),
                child: VendorCard(
                  vendor: vendor,
                  onTap: () => onItemTap(vendor),
                  width: cardWidth,
                  margin: EdgeInsets.symmetric(vertical: 4.h),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
