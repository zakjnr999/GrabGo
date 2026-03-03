import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/models/parcel_models.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

class OrderDetailSheet extends StatelessWidget {
  final ParcelOrderDetailModel detail;
  final String Function(DateTime?) formatDate;

  const OrderDetailSheet({
    super.key,
    required this.detail,
    required this.formatDate,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Parcel ${detail.parcelNumber}')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailLine(context, 'Status', detail.status),
            _detailLine(context, 'Payment Status', detail.paymentStatus),
            _detailLine(
              context,
              'Payment Method',
              detail.paymentMethod ?? 'n/a',
            ),
            _detailLine(
              context,
              'Payment Provider',
              detail.paymentProvider ?? 'n/a',
            ),
            _detailLine(
              context,
              'Payment Ref',
              detail.paymentReferenceId == null ||
                      detail.paymentReferenceId!.isEmpty
                  ? 'n/a'
                  : detail.paymentReferenceId!,
            ),
            if (detail.rainFee > 0)
              _detailLine(
                context,
                'Rain Surcharge',
                '${detail.currency} ${detail.rainFee.toStringAsFixed(2)}',
              ),
            _detailLine(
              context,
              'Total',
              '${detail.currency} ${detail.totalAmount.toStringAsFixed(2)}',
            ),
            _detailLine(context, 'Created', formatDate(detail.createdAt)),
            _detailLine(context, 'Updated', formatDate(detail.updatedAt)),
            _detailLine(context, 'Schedule', detail.scheduleType),
            _detailLine(
              context,
              'Scheduled Pickup',
              formatDate(detail.scheduledPickupAt),
            ),
            const Divider(height: 30),
            const Text(
              'Stops & Contacts',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            _detailLine(context, 'Pickup', detail.pickupAddressLine1),
            _detailLine(context, 'Sender', detail.senderName),
            _detailLine(context, 'Sender Phone', detail.senderPhone),
            _detailLine(context, 'Dropoff', detail.dropoffAddressLine1),
            _detailLine(context, 'Recipient', detail.recipientName),
            _detailLine(context, 'Recipient Phone', detail.recipientPhone),
            const Divider(height: 30),
            const Text('Parcel', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8.h),
            _detailLine(context, 'Category', detail.packageCategory),
            _detailLine(
              context,
              'Description',
              detail.packageDescription ?? 'n/a',
            ),
            _detailLine(context, 'Size Tier', detail.sizeTier),
            _detailLine(
              context,
              'Weight',
              '${detail.weightKg.toStringAsFixed(2)} kg',
            ),
            _detailLine(
              context,
              'Declared Value',
              '${detail.currency} ${detail.declaredValueGhs.toStringAsFixed(2)}',
            ),
            _detailLine(context, 'Notes', detail.notes ?? 'n/a'),
            if (detail.cancelReason != null && detail.cancelReason!.isNotEmpty)
              _detailLine(context, 'Cancel Reason', detail.cancelReason!),
            const Divider(height: 30),
            const Text(
              'Return-to-Sender Financials',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            _detailLine(
              context,
              'Return Charge Status',
              detail.returnChargeStatus,
            ),
            _detailLine(
              context,
              'Return Charge Amount',
              '${detail.currency} ${detail.returnChargeAmount.toStringAsFixed(2)}',
            ),
            _detailLine(
              context,
              'Original Trip Earning',
              '${detail.currency} ${detail.originalTripEarning.toStringAsFixed(2)}',
            ),
            _detailLine(
              context,
              'Return Trip Earning',
              '${detail.currency} ${detail.returnTripEarning.toStringAsFixed(2)}',
            ),
            _detailLine(
              context,
              'Total Rider Earning',
              '${detail.currency} ${detail.totalRiderEarning.toStringAsFixed(2)}',
            ),
            const Divider(height: 30),
            const Text(
              'Recent Events',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            if (detail.events.isEmpty)
              const Text('No events available yet.')
            else
              ...detail.events
                  .take(12)
                  .map(
                    (event) => Card(
                      margin: EdgeInsets.only(bottom: 8.h),
                      child: Padding(
                        padding: EdgeInsets.all(10.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.eventType,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text('Actor: ${event.actorRole ?? "n/a"}'),
                            Text('Time: ${formatDate(event.createdAt)}'),
                            if (event.reason != null &&
                                event.reason!.isNotEmpty)
                              Text('Reason: ${event.reason}'),
                            if (event.metadata.isNotEmpty)
                              Text(
                                'Metadata: ${event.metadata}',
                                style: TextStyle(
                                  color: context.appColors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
