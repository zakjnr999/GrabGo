import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/models/parcel_models.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';

class OrderCard extends StatelessWidget {
  final String title;
  final ParcelOrderSummary order;
  final String createdAtLabel;

  const OrderCard({super.key, required this.title, required this.order, required this.createdAtLabel});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Parcel #: ${order.parcelNumber}',
            style: TextStyle(color: colors.textPrimary, fontSize: 13.sp),
          ),
          Text(
            'Status: ${order.status}',
            style: TextStyle(color: colors.textPrimary, fontSize: 13.sp),
          ),
          Text(
            'Payment: ${order.paymentStatus} (${order.paymentMethod ?? "n/a"})',
            style: TextStyle(color: colors.textPrimary, fontSize: 13.sp),
          ),
          Text(
            'Total: ${order.currency} ${order.totalAmount.toStringAsFixed(2)}',
            style: TextStyle(color: colors.accentOrange, fontWeight: FontWeight.w700, fontSize: 13.sp),
          ),
          Text(
            'Created: $createdAtLabel',
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}
