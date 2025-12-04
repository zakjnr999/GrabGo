import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  int _chatUnreadCount = 0;

  int get selectedIndex => _selectedIndex;
  int get chatUnreadCount => _chatUnreadCount;

  NavigationProvider() {
    _chatUnreadCount = CacheService.getChatUnreadCount();
  }

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void setChatUnreadCount(int count) {
    final normalized = count < 0 ? 0 : count;
    if (normalized == _chatUnreadCount) return;
    _chatUnreadCount = normalized;
    unawaited(CacheService.saveChatUnreadCount(_chatUnreadCount));
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
