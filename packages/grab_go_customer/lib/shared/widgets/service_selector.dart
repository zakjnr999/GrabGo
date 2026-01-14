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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.services.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 2.1,
        ),
        itemBuilder: (context, index) {
          final service = widget.services[index];

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (index >= 0 && index < widget.services.length) {
                  widget.onServiceSelected(service);
                }
              },
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentOrange.withValues(alpha: 0.12), colors.accentOrange.withValues(alpha: 0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                ),
                child: Stack(
                  children: [
                    // Decorative background emoji
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: Opacity(
                        opacity: 0.12,
                        child: Text(service.emoji, style: TextStyle(fontSize: 50.sp)),
                      ),
                    ),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(service.emoji, style: TextStyle(fontSize: 26.sp)),
                          SizedBox(width: 10.w),
                          Flexible(
                            child: Text(
                              service.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15.sp,
                                fontFamily: "Lato",
                                letterSpacing: 0.2,
                              ),
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
        },
      ),
    );
  }
}
