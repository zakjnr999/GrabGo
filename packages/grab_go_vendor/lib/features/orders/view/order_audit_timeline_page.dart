import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';

class OrderAuditTimelinePage extends StatefulWidget {
  final String orderId;
  final List<VendorOrderAuditEntry> entries;

  const OrderAuditTimelinePage({
    super.key,
    required this.orderId,
    required this.entries,
  });

  @override
  State<OrderAuditTimelinePage> createState() => _OrderAuditTimelinePageState();
}

class _OrderAuditTimelinePageState extends State<OrderAuditTimelinePage> {
  final ScrollController _contentScrollController = ScrollController();
  bool _showTopDivider = false;

  @override
  void initState() {
    super.initState();
    _contentScrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_contentScrollController.hasClients) return;
    final shouldShow = _contentScrollController.offset > 0.5;
    if (shouldShow == _showTopDivider) return;
    setState(() => _showTopDivider = shouldShow);
  }

  @override
  void dispose() {
    _contentScrollController.removeListener(_handleScroll);
    _contentScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: colors.textSecondary,
                ),
                icon: SvgPicture.asset(
                  Assets.icons.navArrowLeft,
                  package: 'grab_go_shared',
                  width: 18.w,
                  height: 18.w,
                  colorFilter: ColorFilter.mode(
                    colors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
                label: Text(
                  'Back',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Audit timeline',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                widget.orderId,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 10.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: _showTopDivider ? 1.h : 0,
                color: colors.backgroundSecondary,
              ),
              SizedBox(height: 10.h),
              Expanded(
                child: ListView.builder(
                  controller: _contentScrollController,
                  padding: EdgeInsets.only(bottom: 20.h),
                  itemCount: widget.entries.length,
                  itemBuilder: (context, index) {
                    final item = widget.entries[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 10.h),
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.action,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                item.timeLabel,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Actor: ${item.actor}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            item.details,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
