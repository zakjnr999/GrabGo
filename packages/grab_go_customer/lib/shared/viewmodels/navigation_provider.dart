import 'package:flutter/foundation.dart';

class NavigationProvider extends ChangeNotifier {
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
