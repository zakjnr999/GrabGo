import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:provider/provider.dart';

class VendorOutageBanner extends StatelessWidget {
  final VoidCallback? onManageTap;

  const VendorOutageBanner({super.key, this.onManageTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Consumer<VendorStoreOperationsViewModel>(
      builder: (context, viewModel, _) {
        if (!viewModel.hasOutage) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: colors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: colors.error,
                size: 18.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.outageHeadline,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.error,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      viewModel.outageDetail,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.error,
                      ),
                    ),
                  ],
                ),
              ),
              if (onManageTap != null)
                TextButton(
                  onPressed: onManageTap,
                  child: Text(
                    'Manage',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.error,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
