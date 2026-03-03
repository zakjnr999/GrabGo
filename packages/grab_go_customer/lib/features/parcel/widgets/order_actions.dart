import 'package:flutter/material.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

class OrderActions extends StatelessWidget {
  final bool isBusy;
  final bool canPay;
  final bool canCancel;
  final VoidCallback onViewDetails;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  const OrderActions({
    super.key,
    required this.isBusy,
    required this.canPay,
    required this.canCancel,
    required this.onViewDetails,
    required this.onPay,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: isBusy ? null : onViewDetails,
          icon: const Icon(Icons.info_outline),
          label: const Text('Details'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.inputBorder),
          ),
        ),
        if (canPay)
          ElevatedButton.icon(
            onPressed: isBusy ? null : onPay,
            icon: const Icon(Icons.payment),
            label: const Text('Pay'),
            style: ElevatedButton.styleFrom(backgroundColor: colors.accentOrange, foregroundColor: Colors.white),
          ),
        if (canCancel)
          OutlinedButton.icon(
            onPressed: isBusy ? null : onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.35)),
            ),
          ),
      ],
    );
  }
}
