import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import '../view/map_tracking.dart';

/// Test page to launch tracking in test mode
class TrackingTestPage extends StatelessWidget {
  const TrackingTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    
    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        title: Text(
          'Tracking Test',
          style: TextStyle(color: colors.textPrimary),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.science,
                size: 80.sp,
                color: colors.accentOrange,
              ),
              SizedBox(height: 24.h),
              Text(
                'Test Live Tracking',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'This will simulate a rider delivering your order without needing the rider app.',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: colors.inputBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Simulation:',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    _buildTimelineItem(colors, '0s', 'Order Accepted'),
                    _buildTimelineItem(colors, '10s', 'Preparing Order'),
                    _buildTimelineItem(colors, '20s', 'Rider Picks Up'),
                    _buildTimelineItem(colors, '20-80s', 'Rider Moving to You'),
                    _buildTimelineItem(colors, '80s', 'Delivered!'),
                  ],
                ),
              ),
              
              SizedBox(height: 32.h),
              
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MapTracking(
                        orderId: 'test_order_123',
                        useTestMode: true, // ← Enable test mode
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentOrange,
                  padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 24.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Start Test',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(AppColorsExtension colors, String time, String event) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Container(
            width: 60.w,
            child: Text(
              time,
              style: TextStyle(
                color: colors.accentOrange,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              event,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
