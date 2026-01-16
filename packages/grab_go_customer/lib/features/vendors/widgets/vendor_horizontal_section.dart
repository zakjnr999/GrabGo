import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'vendor_card.dart';
import '../../../shared/widgets/horizontal_card_skeleton.dart';

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
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isLoading && vendors.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SectionHeader(
          title: title,
          sectionIcon: icon,
          sectionTotal: vendors.length,
          accentColor: accentColor,
          onSeeAll: () {},
        ),
        SizedBox(height: 12.h),
        if (isLoading)
          HorizontalCardSkeleton(colors: colors, isDark: isDark, height: 230.h, itemCount: 5)
        else
          SizedBox(
            height: 234.h,
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
                    width: 280.w,
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
