import 'package:flutter/material.dart';

class BottomNavProvider extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void navigateToHome() {
    setIndex(0);
  }

  void navigateToWallet() {
    setIndex(1);
  }

  void navigateTOChat() {
    setIndex(2);
  }

  void navigateTOProfile() {
    setIndex(3);
  }
}
