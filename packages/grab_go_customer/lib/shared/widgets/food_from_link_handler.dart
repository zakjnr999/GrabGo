import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/services/food_share_link.dart';
import 'package:grab_go_shared/shared/widgets/app_toast_message.dart';
import 'package:grab_go_shared/shared/widgets/loading_dialog.dart';
import 'package:provider/provider.dart';

class FoodFromLinkHandler extends StatefulWidget {
  const FoodFromLinkHandler({super.key, required this.foodId});

  final String foodId;

  @override
  State<FoodFromLinkHandler> createState() => _FoodFromLinkHandlerState();
}

class _FoodFromLinkHandlerState extends State<FoodFromLinkHandler> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LoadingDialog.instance().show(context: context, text: "Loading food item...");
      }
    });
    _handleFoodLink();
  }

  Future<void> _handleFoodLink() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) {
      LoadingDialog.instance().hide();
      return;
    }

    try {
      final parsed = FoodShareLinkService.parseFoodId(widget.foodId);

      if (parsed == null) {
        LoadingDialog.instance().hide();
        _showErrorAndNavigateBack('Invalid food link. Please check the link and try again.');
        return;
      }

      final sellerIdStr = parsed['sellerId'] ?? '';
      final foodNameEncoded = parsed['foodName'] ?? '';

      final foodName = foodNameEncoded.replaceAll('-', ' ');

      int? sellerId;
      sellerId = int.tryParse(sellerIdStr);

      if (sellerIdStr.isEmpty || foodName.isEmpty || foodName.trim().isEmpty) {
        LoadingDialog.instance().hide();
        _showErrorAndNavigateBack('Invalid food link format.');
        return;
      }

      final foodProvider = Provider.of<FoodProvider>(context, listen: false);

      if (foodProvider.categories.isEmpty) {
        try {
          await foodProvider.fetchCategories();
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          LoadingDialog.instance().hide();
          _showErrorAndNavigateBack('Failed to load food items. Please try again.');
          return;
        }
      }

      if (foodProvider.categories.isEmpty) {
        LoadingDialog.instance().hide();
        _showErrorAndNavigateBack('No food items available. Please check your connection.');
        return;
      }
      FoodItem? foundFoodItem;

      for (final category in foodProvider.categories) {
        try {
          foundFoodItem = category.items.firstWhere((item) {
            bool matchesSellerId = false;
            if (sellerId != null) {
              matchesSellerId = item.sellerId == sellerId;
            } else {
              final itemSellerIdStr = item.sellerId.toString();
              matchesSellerId =
                  itemSellerIdStr == sellerIdStr ||
                  itemSellerIdStr.contains(sellerIdStr) ||
                  sellerIdStr.contains(itemSellerIdStr);
            }

            final itemNameLower = item.name.toLowerCase().trim();
            final searchNameLower = foodName.toLowerCase().trim();
            final matchesName =
                itemNameLower == searchNameLower ||
                itemNameLower.contains(searchNameLower) ||
                searchNameLower.contains(itemNameLower);

            return matchesSellerId && matchesName;
          });
          break;
        } catch (e) {
          continue;
        }
      }

      if (foundFoodItem == null) {
        final allItems = foodProvider.categories.expand((cat) => cat.items).toList();
        foundFoodItem = allItems.firstWhere((item) {
          if (sellerId != null) {
            return item.sellerId == sellerId;
          } else {
            final itemSellerIdStr = item.sellerId.toString();
            return itemSellerIdStr == sellerIdStr ||
                itemSellerIdStr.contains(sellerIdStr) ||
                sellerIdStr.contains(itemSellerIdStr);
          }
        });
      }

      if (mounted) {
        LoadingDialog.instance().hide();

        final router = GoRouter.of(context);
        final canPop = router.canPop();

        if (!canPop) {
          if (mounted) {
            context.go("/homepage");

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    context.push("/foodDetails", extra: foundFoodItem);
                  }
                });
              }
            });
          }
        } else {
          context.push("/foodDetails", extra: foundFoodItem);
        }
      } else {
        LoadingDialog.instance().hide();
        _showErrorAndNavigateBack('Food item not found. It may no longer be available or the link is invalid.');
      }
    } catch (e) {
      LoadingDialog.instance().hide();
      _showErrorAndNavigateBack('Error loading food item: ${e.toString()}');
    }
  }

  void _showErrorAndNavigateBack(String message) {
    if (!mounted) return;

    AppToastMessage.show(
      context: context,
      message: message,
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 4),
      icon: Icons.error_outline,
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.go("/");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }

  @override
  void dispose() {
    LoadingDialog.instance().hide();
    super.dispose();
  }
}
