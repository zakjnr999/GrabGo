import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:url_launcher/url_launcher.dart';

/// Navigation app options
enum NavigationApp {
  googleMaps('Google Maps', 'com.google.android.apps.maps'),
  waze('Waze', 'com.waze'),
  appleMaps('Apple Maps', 'maps.apple.com');

  final String displayName;
  final String packageName;

  const NavigationApp(this.displayName, this.packageName);
}

/// Utility class for external navigation
class ExternalNavigationHelper {
  /// Show navigation options dialog
  static Future<void> showNavigationOptions({
    required BuildContext context,
    required double destinationLat,
    required double destinationLng,
    required String destinationName,
  }) async {
    final colors = context.appColors;

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius20),
            topRight: Radius.circular(KBorderSize.borderRadius20),
          ),
        ),
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 16.h,
          bottom: MediaQuery.of(context).padding.bottom + 20.h,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text(
                'Open in Navigation App',
                style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8.h),
              Text(
                'Navigate to: $destinationName',
                style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w400),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 20.h),
              // Google Maps
              _NavigationOptionTile(
                icon: Icons.map,
                iconColor: Colors.blue,
                title: 'Google Maps',
                subtitle: 'Recommended',
                onTap: () {
                  Navigator.pop(context);
                  _launchGoogleMaps(destinationLat, destinationLng);
                },
              ),
              SizedBox(height: 12.h),
              // Waze
              _NavigationOptionTile(
                icon: Icons.navigation,
                iconColor: Colors.lightBlue,
                title: 'Waze',
                subtitle: 'Traffic-aware routing',
                onTap: () {
                  Navigator.pop(context);
                  _launchWaze(destinationLat, destinationLng);
                },
              ),
              SizedBox(height: 12.h),
              // Copy coordinates
              _NavigationOptionTile(
                icon: Icons.copy,
                iconColor: colors.textSecondary,
                title: 'Copy Coordinates',
                subtitle: '$destinationLat, $destinationLng',
                onTap: () {
                  Navigator.pop(context);
                  _copyCoordinates(context, destinationLat, destinationLng);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Launch Google Maps with directions
  static Future<void> _launchGoogleMaps(double lat, double lng) async {
    // Google Maps URL for directions
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web
        final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
    }
  }

  /// Launch Waze with directions
  static Future<void> _launchWaze(double lat, double lng) async {
    final url = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Waze: $e');
      // Fallback to Google Maps
      _launchGoogleMaps(lat, lng);
    }
  }

  /// Copy coordinates to clipboard
  static void _copyCoordinates(BuildContext context, double lat, double lng) {
    final colors = context.appColors;
    final messenger = ScaffoldMessenger.of(context);

    // Actually copy to clipboard
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));

    messenger.showSnackBar(
      SnackBar(
        content: Text('Coordinates copied: $lat, $lng'),
        backgroundColor: colors.accentGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Quick launch to Google Maps (without dialog)
  static Future<void> launchGoogleMapsDirectly({required double destinationLat, required double destinationLng}) async {
    await _launchGoogleMaps(destinationLat, destinationLng);
  }

  /// Quick launch to Waze (without dialog)
  static Future<void> launchWazeDirectly({required double destinationLat, required double destinationLng}) async {
    await _launchWaze(destinationLat, destinationLng);
  }
}

class _NavigationOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavigationOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: Icon(icon, color: iconColor, size: 24.w),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textSecondary, size: 24.w),
            ],
          ),
        ),
      ),
    );
  }
}
