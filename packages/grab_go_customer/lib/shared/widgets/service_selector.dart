import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/service_model.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ServiceSelector extends StatefulWidget {
  final List<ServiceModel> services;
  final ValueChanged<ServiceModel> onServiceSelected;
  final ServiceModel? initialSelectedService;

  const ServiceSelector({
    super.key,
    required this.services,
    required this.onServiceSelected,
    this.initialSelectedService,
  });

  @override
  State<ServiceSelector> createState() => _ServiceSelectorState();
}

class _ServiceSelectorState extends State<ServiceSelector> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedService != null) {
      final index = widget.services.indexWhere((service) => service.id == widget.initialSelectedService!.id);
      selectedIndex = index >= 0 ? index : 0;
    } else {
      selectedIndex = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.services.isNotEmpty && selectedIndex < widget.services.length) {
        widget.onServiceSelected(widget.services[selectedIndex]);
      }
    });
  }

  @override
  void didUpdateWidget(ServiceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Guard against empty services
    if (widget.services.isEmpty) {
      return;
    }

    // Update selected index when services list changes
    if (widget.services.length != oldWidget.services.length || !_servicesEqual(widget.services, oldWidget.services)) {
      int newIndex = selectedIndex;

      // Try to preserve the selected service if it still exists in the new list
      if (widget.initialSelectedService != null) {
        final index = widget.services.indexWhere((service) => service.id == widget.initialSelectedService!.id);
        if (index >= 0) {
          newIndex = index;
        } else {
          // Selected service not in new list, reset to first
          newIndex = 0;
        }
      } else {
        // Check if current selected index is still valid
        if (selectedIndex >= widget.services.length) {
          newIndex = 0;
        }
      }

      // Update state and notify parent only if index changed
      if (newIndex != selectedIndex && newIndex < widget.services.length) {
        setState(() {
          selectedIndex = newIndex;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && selectedIndex < widget.services.length) {
            widget.onServiceSelected(widget.services[selectedIndex]);
          }
        });
      }
    } else if (widget.initialSelectedService != null &&
        widget.initialSelectedService!.id != oldWidget.initialSelectedService?.id) {
      // Initial selected service changed, update selection
      final index = widget.services.indexWhere((service) => service.id == widget.initialSelectedService!.id);
      if (index >= 0 && index != selectedIndex && index < widget.services.length) {
        setState(() {
          selectedIndex = index;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && selectedIndex < widget.services.length) {
            widget.onServiceSelected(widget.services[selectedIndex]);
          }
        });
      }
    }
  }

  bool _servicesEqual(List<ServiceModel> list1, List<ServiceModel> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return SizedBox(
      height: 95.h,
      child: ListView.builder(
        padding: EdgeInsets.only(left: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.services.length,
        itemBuilder: (context, index) {
          final service = widget.services[index];
          final bool isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () {
              if (index >= 0 && index < widget.services.length) {
                setState(() {
                  selectedIndex = index;
                });
                widget.onServiceSelected(service);
              }
            },
            child: Padding(
              padding: EdgeInsets.only(right: 20.w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: size.width * 0.22,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]
                        : [colors.backgroundPrimary, colors.backgroundPrimary.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      spreadRadius: 1,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(5),
                      spreadRadius: -1,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      style: TextStyle(fontSize: 30, color: isSelected ? colors.backgroundPrimary : colors.textPrimary),
                      child: Text(service.emoji),
                    ),
                    SizedBox(height: KSpacing.md.h),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      style: TextStyle(
                        color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5.w),
                        child: Text(
                          service.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontFamily: "Lato",
                            package: 'grab_go_shared',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
