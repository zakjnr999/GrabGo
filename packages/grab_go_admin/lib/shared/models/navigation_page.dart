enum NavigationPage {
  dashboard,
  restaurants,
  payments,
  orders,
  settings,
}

extension NavigationPageExtension on NavigationPage {
  String get title {
    switch (this) {
      case NavigationPage.dashboard:
        return 'Dashboard';
      case NavigationPage.restaurants:
        return 'Restaurants Management';
      case NavigationPage.payments:
        return 'Payments';
      case NavigationPage.orders:
        return 'Orders';
      case NavigationPage.settings:
        return 'Settings';
    }
  }
}
