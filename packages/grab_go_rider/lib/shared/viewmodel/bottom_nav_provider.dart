import 'package:flutter/material.dart';

class BottomNavProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  int _chatUnreadCount = 0;

  int get selectedIndex => _selectedIndex;
  int get chatUnreadCount => _chatUnreadCount;

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void setChatUnreadCount(int count) {
    if (count == _chatUnreadCount) return;
    _chatUnreadCount = count < 0 ? 0 : count;
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
