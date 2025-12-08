import 'package:flutter/material.dart';
import 'package:grab_go_shared/shared/services/socket_service.dart';

class BottomNavProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  int _chatUnreadCount = 0;

  int get selectedIndex => _selectedIndex;
  int get chatUnreadCount => _chatUnreadCount;

  BottomNavProvider() {
    _chatUnreadCount = SocketService().totalUnread;

    SocketService().registerUnreadListener((count) {
      if (count == _chatUnreadCount) return;
      _chatUnreadCount = count;
      notifyListeners();
    });
  }

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void setChatUnreadCount(int count) {
    SocketService().overrideTotalUnread(count);
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
