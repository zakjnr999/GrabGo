import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RestaurantLocations extends StatefulWidget {
  final ValueChanged<String> onCitySelected;

  const RestaurantLocations({super.key, required this.onCitySelected});

  @override
  State<RestaurantLocations> createState() => _RestaurantLocationsState();
}

class _RestaurantLocationsState extends State<RestaurantLocations> {
  final List<String> cities = [
    "All",
    "Accra",
    "Kumasi",
    "Tamale",
    "Takoradi",
    "Cape Coast",
    "Sunyani",
    "Ho",
    "Koforidua",
    "Bolgatanga",
    "Wa",
  ];

  String? selectedCity;

  @override
  void initState() {
    super.initState();
    selectedCity = cities.first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        children: cities.map((city) {
          final bool isSelected = selectedCity == city;
          return Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: ChoiceChip(
              showCheckmark: false,
              elevation: 5,
              label: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                style: TextStyle(
                  color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                child: Text(city),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  selectedCity = city;
                  widget.onCitySelected(city);
                });
              },
              selectedColor: colors.accentOrange,
              backgroundColor: colors.backgroundPrimary,
              shadowColor: Colors.black.withAlpha(10),
              selectedShadowColor: Colors.black.withAlpha(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KBorderSize.border),
                side: BorderSide(color: isSelected ? colors.accentOrange : colors.backgroundSecondary),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
