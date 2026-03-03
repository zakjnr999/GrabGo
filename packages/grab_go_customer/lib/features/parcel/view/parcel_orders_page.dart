import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/parcel/viewmodel/parcel_provider.dart';
import 'package:grab_go_customer/features/parcel/widgets/order_actions.dart';
import 'package:grab_go_customer/features/parcel/widgets/order_card.dart';
import 'package:grab_go_customer/features/parcel/widgets/order_detail_sheet.dart';
import 'package:grab_go_customer/shared/services/paystack_service.dart' as paystack;
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/models/parcel_models.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:grab_go_shared/shared/widgets/app_refresh_indicator.dart';
import 'package:provider/provider.dart';

class ParcelOrdersPage extends StatefulWidget {
  const ParcelOrdersPage({super.key});

  @override
  State<ParcelOrdersPage> createState() => _ParcelOrdersPageState();
}

class _ParcelOrdersPageState extends State<ParcelOrdersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ParcelProvider>().loadOrders();
    });
  }

  bool _canRetryPayment(ParcelOrderSummary order) {
    const unpaidStatuses = {'pending', 'processing'};
    return unpaidStatuses.contains(order.paymentStatus.toLowerCase());
  }

  bool _canCancelOrder(ParcelOrderSummary order) {
    const cancellableStatuses = {'pending_payment', 'payment_processing', 'paid', 'awaiting_dispatch'};
    return cancellableStatuses.contains(order.status.toLowerCase());
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'n/a';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  Future<void> _refreshOrders() async {
    await context.read<ParcelProvider>().loadOrders();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  Future<void> _viewOrder(ParcelProvider provider, String parcelId) async {
    final detail = await provider.loadOrderDetail(parcelId);
    if (!mounted) return;
    if (detail == null) {
      _showToast(provider.errorMessage ?? 'Failed to load order details.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.86,
        child: OrderDetailSheet(detail: detail, formatDate: _formatDate),
      ),
    );
  }

  Future<void> _payForOrder(ParcelProvider provider, ParcelOrderSummary order) async {
    final init = await provider.initializePaystack(order.id);
    if (!mounted) return;
    if (init == null) {
      _showToast(provider.errorMessage ?? 'Failed to initialize payment.');
      return;
    }

    final result = await paystack.PaystackService.instance.launchPayment(
      context: context,
      authorizationUrl: init.authorizationUrl,
      reference: init.reference,
    );

    if (!mounted) return;
    if (result.status == paystack.PaystackPaymentStatus.cancelled) {
      _showToast('Payment was cancelled.');
      return;
    }

    if (result.status == paystack.PaystackPaymentStatus.failed) {
      _showToast('Payment did not complete successfully.');
      return;
    }

    final confirmation = await provider.confirmPayment(order.id, reference: result.reference ?? init.reference);
    if (!mounted) return;
    if (confirmation == null) {
      _showToast(provider.errorMessage ?? 'Payment confirmation failed.');
      return;
    }

    _showToast(
      confirmation.alreadyPaid ? 'Payment was already confirmed for this parcel.' : 'Payment confirmed successfully.',
    );
  }

  Future<void> _cancelOrder(ParcelProvider provider, ParcelOrderSummary order) async {
    final cancelled = await provider.cancelOrder(order.id);
    if (!mounted) return;
    if (cancelled == null) {
      _showToast(provider.errorMessage ?? 'Failed to cancel parcel order.');
      return;
    }
    _showToast('Parcel ${cancelled.parcelNumber} cancelled.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.backgroundPrimary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: Consumer<ParcelProvider>(
          builder: (context, provider, _) {
            final isPaymentBusy = provider.isInitializingPayment || provider.isConfirmingPayment;
            final isAnyOrderActionBusy = isPaymentBusy || provider.isCancellingOrder;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: padding.top + 10, left: 20.w, right: 20.w, bottom: 16.h),
                  child: Row(
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.pop(),
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: EdgeInsets.all(10.r),
                              child: SvgPicture.asset(
                                Assets.icons.navArrowLeft,
                                package: 'grab_go_shared',
                                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        'Parcel Orders',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          package: 'grab_go_shared',
                          color: colors.textPrimary,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _refreshOrders,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: EdgeInsets.all(10.r),
                              child: SvgPicture.asset(
                                Assets.icons.refresh,
                                package: 'grab_go_shared',
                                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: colors.backgroundSecondary, height: 1.h, thickness: 1),
                Expanded(
                  child: AppRefreshIndicator(
                    onRefresh: _refreshOrders,
                    iconPath: Assets.icons.boxIso,
                    bgColor: colors.accentOrange,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (provider.errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: colors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                provider.errorMessage!,
                                style: TextStyle(color: colors.error, fontSize: 13.sp, fontWeight: FontWeight.w600),
                              ),
                            ),
                            SizedBox(height: 12.h),
                          ],
                          Row(
                            children: [
                              Text(
                                'All Parcel Orders',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  package: 'grab_go_shared',
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              if (provider.isLoadingOrders)
                                SizedBox(
                                  width: 14.w,
                                  height: 14.w,
                                  child: const CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          if (!provider.isLoadingOrders && provider.orders.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: colors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                              ),
                              child: Text(
                                'No parcel orders yet.',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            ...provider.orders.map(
                              (order) => Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    OrderCard(
                                      title: 'Parcel ${order.parcelNumber}',
                                      order: order,
                                      createdAtLabel: _formatDate(order.createdAt),
                                    ),
                                    SizedBox(height: 8.h),
                                    OrderActions(
                                      isBusy: isAnyOrderActionBusy,
                                      canPay: _canRetryPayment(order),
                                      canCancel: _canCancelOrder(order),
                                      onViewDetails: () => _viewOrder(provider, order.id),
                                      onPay: () => _payForOrder(provider, order),
                                      onCancel: () => _cancelOrder(provider, order),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (provider.isLoadingOrderDetail)
                            Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: const LinearProgressIndicator(),
                            ),
                          if (isPaymentBusy)
                            Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: Text(
                                provider.isConfirmingPayment
                                    ? 'Confirming parcel payment...'
                                    : 'Preparing parcel payment...',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (provider.isCancellingOrder)
                            Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: Text(
                                'Cancelling parcel order...',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
