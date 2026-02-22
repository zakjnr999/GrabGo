import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/store_context/view/store_context_switcher_page.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:provider/provider.dart';

class VendorStoreContextChip extends StatelessWidget {
  final bool compact;

  const VendorStoreContextChip({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Consumer<VendorStoreContextViewModel>(
      builder: (context, viewModel, _) {
        return InkWell(
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => ChangeNotifierProvider.value(
                value: viewModel,
                child: const StoreContextSwitcherPage(),
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(999.r),
          child: Container(
            constraints: BoxConstraints(maxWidth: compact ? 190.w : 260.w),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10.w : 12.w,
              vertical: compact ? 6.h : 8.h,
            ),
            decoration: BoxDecoration(
              color: colors.vendorPrimaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.storefront_rounded,
                  color: colors.vendorPrimaryBlue,
                  size: compact ? 15.sp : 16.sp,
                ),
                SizedBox(width: 6.w),
                Flexible(
                  child: Text(
                    viewModel.selectedBranch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11.sp : 12.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.vendorPrimaryBlue,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  width: 3.w,
                  height: 3.w,
                  decoration: BoxDecoration(
                    color: colors.vendorPrimaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6.w),
                Flexible(
                  child: Text(
                    viewModel.serviceScopeLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10.sp : 11.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.vendorPrimaryBlue,
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.expand_more_rounded,
                  size: compact ? 15.sp : 16.sp,
                  color: colors.vendorPrimaryBlue,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
