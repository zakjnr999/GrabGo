import 'dart:ui';

import 'package:grab_go_customer/features/status/model/status.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

String categoryLabel(StatusCategory category) {
  switch (category) {
    case StatusCategory.dailySpecial:
      return 'Daily Special';
    case StatusCategory.discount:
      return 'Discount';
    case StatusCategory.newItem:
      return 'New Item';
    case StatusCategory.video:
      return 'Video Story';
  }
}

Color categoryColor(StatusCategory category, AppColorsExtension colors) {
  switch (category) {
    case StatusCategory.dailySpecial:
      return colors.accentGreen;
    case StatusCategory.discount:
      return colors.accentOrange;
    case StatusCategory.newItem:
      return colors.accentViolet;
    case StatusCategory.video:
      return colors.accentViolet;
  }
}

String feedSectionTitle(StatusCategory? category) {
  switch (category) {
    case StatusCategory.dailySpecial:
      return 'Today\'s Specials';
    case StatusCategory.discount:
      return 'Discounts & Promos';
    case StatusCategory.newItem:
      return 'New On The Menu';
    case StatusCategory.video:
      return 'Food Stories & Videos';
    case null:
      return 'Latest From Restaurants';
  }
}

String feedSectionIconAsset(StatusCategory? category) {
  switch (category) {
    case StatusCategory.dailySpecial:
      return Assets.icons.fireFlame;
    case StatusCategory.discount:
      return Assets.icons.percentageCircle;
    case StatusCategory.newItem:
      return Assets.icons.star;
    case StatusCategory.video:
      return Assets.icons.mediaImage;
    case null:
      return Assets.icons.utensilsCrossed;
  }
}

Color feedSectionIconColor(StatusCategory? category, AppColorsExtension colors) {
  switch (category) {
    case StatusCategory.dailySpecial:
      return colors.accentGreen;
    case StatusCategory.discount:
      return colors.accentOrange;
    case StatusCategory.newItem:
      return colors.accentViolet;
    case StatusCategory.video:
      return colors.accentViolet;
    case null:
      return colors.accentViolet;
  }
}
