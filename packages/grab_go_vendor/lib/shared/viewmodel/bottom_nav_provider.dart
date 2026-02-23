import 'package:flutter/material.dart';

class VendorBottomNavProvider extends ChangeNotifier {
  VendorBottomNavProvider({int initialIndex = 1})
    : _selectedIndex = initialIndex;

  int _selectedIndex;

  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    if (index == _selectedIndex) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void navigateToHome() => setIndex(0);
  void navigateToOrders() => setIndex(1);
  void navigateToCatalog() => setIndex(2);
  void navigateToMore() => setIndex(3);
}
