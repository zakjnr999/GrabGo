import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class MenuSearch extends StatefulWidget {
  final Function(String) onSearchChanged;
  final String searchQuery;

  const MenuSearch({
    super.key,
    required this.onSearchChanged,
    this.searchQuery = '',
  });

  @override
  State<MenuSearch> createState() => _MenuSearchState();
}

class _MenuSearchState extends State<MenuSearch> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isSearching = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    _focusNode = FocusNode();

    // Listen to focus changes
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });

      if (!_focusNode.hasFocus && _controller.text.isEmpty) {
        // If focus is lost and no text, exit search mode
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () {
        if (!_isSearching) {
          setState(() {
            _isSearching = true;
          });
          // Request focus when entering search mode
          Future.delayed(const Duration(milliseconds: 100), () {
            _focusNode.requestFocus();
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: KSpacing.md.r,
          vertical: KSpacing.md.r,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20),
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
            SvgPicture.asset(
              Assets.icons.search,
                            package: 'grab_go_shared',
              height: KIconSize.md,
              width: KIconSize.md,
              colorFilter: ColorFilter.mode(
                colors.textTertiary,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _isSearching
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                      showCursor: _hasFocus,
                      decoration: InputDecoration(
                        hintText: "Search",
                        hintStyle: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: widget.onSearchChanged,
                    )
                  : Text(
                      "Search",
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ),
            if (_isSearching && _controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _controller.clear();
                  widget.onSearchChanged('');
                  _focusNode.unfocus();
                  setState(() {
                    _isSearching = false;
                  });
                },
                child: Icon(
                  Icons.clear,
                  size: KIconSize.md,
                  color: colors.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}


