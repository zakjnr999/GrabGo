enum RestaurantNavigationPage {
  dashboard,
  menu,
  orders,
  analytics,
  settings,
}

extension RestaurantNavigationPageExtension on RestaurantNavigationPage {
  String get title {
    switch (this) {
      case RestaurantNavigationPage.dashboard:
        return 'Restaurant Overview';
      case RestaurantNavigationPage.menu:
        return 'Menu Management';
      case RestaurantNavigationPage.orders:
        return 'Order Management';
      case RestaurantNavigationPage.analytics:
        return 'Restaurant Analytics';
      case RestaurantNavigationPage.settings:
        return 'Restaurant Settings';
    }
  }
}
