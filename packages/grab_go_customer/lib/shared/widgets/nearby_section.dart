import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/shared/widgets/nearby_restaurant_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class NearbySection extends StatelessWidget {
  final List<RestaurantModel> nearbyRestaurants;
  final VoidCallback onSeeAll;
  final Function(RestaurantModel) onRestaurantTap;

  const NearbySection({
    super.key,
    required this.nearbyRestaurants,
    required this.onSeeAll,
    required this.onRestaurantTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        SectionHeader(
          title: "Nearby You",
          icon: Assets.icons.mapPin,
          accentColor: colors.accentGreen,
          onSeeAll: onSeeAll,
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 120.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20.w),
            physics: const BouncingScrollPhysics(),
            itemCount: nearbyRestaurants.length,
            itemBuilder: (context, index) {
              final restaurant = nearbyRestaurants[index];
              // Mock distance (0.5 - 3.0 km)
              final distance = 0.5 + (index * 0.5);

              return Padding(
                padding: EdgeInsets.only(right: 15.w),
                child: NearbyRestaurantCard(
                  restaurant: restaurant,
                  distance: distance,
                  onTap: () => onRestaurantTap(restaurant),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
