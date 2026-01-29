import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class AvailableOrderDetailsBottomSheet extends StatelessWidget {
  final AvailableOrderDto order;
  final VoidCallback onAccept;
  final String? actionButtonText;
  final Color? actionButtonColor;

  const AvailableOrderDetailsBottomSheet({
    super.key,
    required this.order,
    required this.onAccept,
    this.actionButtonText,
    this.actionButtonColor,
  });

  static void show({
    required BuildContext context,
    required AvailableOrderDto order,
    required VoidCallback onAccept,
    String? actionButtonText,
    Color? actionButtonColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AvailableOrderDetailsBottomSheet(
        order: order,
        onAccept: onAccept,
        actionButtonText: actionButtonText,
        actionButtonColor: actionButtonColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.of(context).size;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),

          // Header
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Details',
                    style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "ORDER ID :",
                        style: TextStyle(fontSize: 12.sp, color: colors.textPrimary, fontWeight: FontWeight.w400),
                      ),
                      Text(
                        order.orderNumber,
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "EARNINGS :",
                        style: TextStyle(fontSize: 12.sp, color: colors.textPrimary, fontWeight: FontWeight.w400),
                      ),
                      Text(
                        'GHS ${order.riderEarnings?.toStringAsFixed(2)}',
                        style: TextStyle(color: colors.accentGreen, fontSize: 20.sp, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  _buildDetailSection(
                    colors,
                    'Restaurant',
                    order.restaurantName,
                    order.restaurantAddress,
                    size,
                    order.restaurantLogo ?? '',
                    Assets.icons.store,
                  ),
                  SizedBox(height: 20.h),
                  _buildDetailSection(
                    colors,
                    'Customer',
                    order.customerName,
                    order.customerAddress,
                    size,
                    order.customerPhoto ?? '',
                    Assets.icons.user,
                  ),
                  SizedBox(height: 20.h),

                  Text(
                    'Order Items',
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 12.h),
                  ...order.orderItems.map(
                    (item) => Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    Text(
                      'Special Instructions',
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            order.notes!,
                            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Accept button
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              border: Border(top: BorderSide(color: colors.border, width: 1)),
            ),
            child: SafeArea(
              child: SizedBox(
                height: 48.h,
                width: double.infinity,
                child: AppButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAccept();
                  },
                  backgroundColor: actionButtonColor ?? colors.accentGreen,
                  borderRadius: KBorderSize.borderRadius4,
                  buttonText: actionButtonText ?? 'Accept Order',
                  textStyle: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
    AppColorsExtension colors,
    String title,
    String mainText,
    String? subtitle,
    Size size,
    String? imageUrl,
    String icon, {
    String? subtitle2,
  }) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          child: CachedNetworkImage(
            height: size.width * 0.15,
            width: size.width * 0.15,
            fit: BoxFit.cover,
            imageUrl: ImageOptimizer.getPreviewUrl(imageUrl ?? '', width: 200),
            memCacheWidth: 200,
            maxHeightDiskCache: 200,
            placeholder: (context, url) => Container(
              height: size.width * 0.15,
              width: size.width * 0.15,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: colors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 24.w,
                height: 24.w,
                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: size.width * 0.15,
              width: size.width * 0.15,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: colors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 24.w,
                height: 24.w,
                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4.h),
              Text(
                mainText,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                ),
              ],
              if (subtitle2 != null && subtitle2.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle2,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
