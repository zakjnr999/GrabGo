import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RestaurantSearch extends StatefulWidget {
  final Function(String) onSearchChanged;
  final VoidCallback? onFilterPressed;

  const RestaurantSearch({
    super.key,
    required this.onSearchChanged,
    this.onFilterPressed,
  });

  @override
  State<RestaurantSearch> createState() => _RestaurantSearchState();
}

class _RestaurantSearchState extends State<RestaurantSearch> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KBorderSize.border),
        color: colors.backgroundPrimary,

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

      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: 10.w),
            child: SvgPicture.asset(
              Assets.icons.search,
                            package: 'grab_go_shared',
              height: KIconSize.md,
              width: KIconSize.md,
              colorFilter: ColorFilter.mode(
                colors.textTertiary,
                BlendMode.srcIn,
              ),
            ),
          ),

          SizedBox(width: 5.w),

          Expanded(
            child: TextField(
              focusNode: _focusNode,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              controller: _searchController,
              showCursor: _hasFocus,
              onChanged: (value) {
                setState(() {
                  _isSearching = value.isNotEmpty;
                });
                widget.onSearchChanged(value);
              },
              onTap: () {
                setState(() {
                  _isSearching = true;
                });
              },
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: "Search restaurants...",
                hintStyle: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          if (_isSearching)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _focusNode.unfocus();
                setState(() {
                  _isSearching = false;
                });
                widget.onSearchChanged('');
              },
              child: Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: Icon(
                  Icons.clear,
                  size: 16.sp,
                  color: colors.textTertiary,
                ),
              ),
            ),

          GestureDetector(
            onTap: widget.onFilterPressed,
            child: Container(
              width: size.width * 0.24,
              padding: EdgeInsets.all(2.r),
              decoration: BoxDecoration(
                color: colors.accentOrange,
                borderRadius: BorderRadius.circular(KBorderSize.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 10.w),
                    child: Text(
                      "Filter",
                      style: TextStyle(
                        color: colors.backgroundPrimary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(KBorderSize.border),
                    ),
                    child: SvgPicture.asset(
                      Assets.icons.slidersHorizontal,
                            package: 'grab_go_shared',
                      height: KIconSize.sm,
                      width: KIconSize.sm,
                      colorFilter: ColorFilter.mode(
                        colors.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


