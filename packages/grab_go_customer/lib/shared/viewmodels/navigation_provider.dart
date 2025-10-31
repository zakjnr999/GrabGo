import 'package:flutter/foundation.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void navigateToMenu() {
    setIndex(1);
  }

  void navigateToHome() {
    setIndex(0);
  }

  void navigateToRestaurants() {
    setIndex(3);
  }

  void navigateToAccount() {
    setIndex(4);
  }
}

