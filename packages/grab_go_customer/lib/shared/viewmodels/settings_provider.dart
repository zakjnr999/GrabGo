import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // Notification preferences
  bool _pushNotificationsEnabled = true;
  bool _orderUpdatesEnabled = true;
  bool _promotionsEnabled = true;
  bool _chatMessagesEnabled = true;
  bool _favoritesEnabled = true;
  bool _notificationSoundEnabled = true;

  // Display preferences
  double _fontScale = 1.0; // 0.85, 1.0, 1.15, 1.3

  // Order preferences
  int _defaultTipPercentage = 15;
  bool _contactlessDeliveryDefault = false;
  bool _includeUtensilsDefault = true;

  // Language & Currency
  String _language = 'en';
  String _currency = 'GHS';

  // Biometric
  bool _biometricLoginEnabled = false;

  // Default pickup location
  String _defaultPickupLocation = '';

  // Cached SharedPreferences instance
  SharedPreferences? _prefs;

  // Getters
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get orderUpdatesEnabled => _orderUpdatesEnabled;
  bool get promotionsEnabled => _promotionsEnabled;
  bool get chatMessagesEnabled => _chatMessagesEnabled;
  bool get favoritesEnabled => _favoritesEnabled;
  bool get notificationSoundEnabled => _notificationSoundEnabled;
  double get fontScale => _fontScale;
  int get defaultTipPercentage => _defaultTipPercentage;
  bool get contactlessDeliveryDefault => _contactlessDeliveryDefault;
  bool get includeUtensilsDefault => _includeUtensilsDefault;
  String get language => _language;
  String get currency => _currency;
  bool get biometricLoginEnabled => _biometricLoginEnabled;
  String get defaultPickupLocation => _defaultPickupLocation;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      _pushNotificationsEnabled = _prefs!.getBool('push_notifications') ?? true;
      _orderUpdatesEnabled = _prefs!.getBool('order_updates') ?? true;
      _promotionsEnabled = _prefs!.getBool('promotions') ?? true;
      _chatMessagesEnabled = _prefs!.getBool('chat_messages') ?? true;
      _favoritesEnabled = _prefs!.getBool('favorites') ?? true;
      _notificationSoundEnabled = _prefs!.getBool('notification_sound') ?? true;
      _fontScale = (_prefs!.getDouble('font_scale') ?? 1.0).clamp(0.85, 1.3);
      _defaultTipPercentage = _prefs!.getInt('default_tip') ?? 15;
      _contactlessDeliveryDefault = _prefs!.getBool('contactless_delivery') ?? false;
      _includeUtensilsDefault = _prefs!.getBool('include_utensils') ?? true;
      _language = _prefs!.getString('language') ?? 'en';
      _currency = _prefs!.getString('currency') ?? 'GHS';
      _biometricLoginEnabled = _prefs!.getBool('biometric_login') ?? false;
      _defaultPickupLocation = _prefs!.getString('default_pickup_location') ?? '';

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> setPushNotifications(bool value) async {
    _pushNotificationsEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('push_notifications', value);
  }

  Future<void> setOrderUpdates(bool value) async {
    _orderUpdatesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('order_updates', value);
  }

  Future<void> setPromotions(bool value) async {
    _promotionsEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('promotions', value);
  }

  Future<void> setChatMessages(bool value) async {
    _chatMessagesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('chat_messages', value);
  }

  Future<void> setFavorites(bool value) async {
    _favoritesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('favorites', value);
  }

  Future<void> setNotificationSound(bool value) async {
    _notificationSoundEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('notification_sound', value);
  }

  Future<void> setFontScale(double value) async {
    _fontScale = value.clamp(0.85, 1.3);
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setDouble('font_scale', _fontScale);
  }

  Future<void> setDefaultTipPercentage(int value) async {
    _defaultTipPercentage = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt('default_tip', value);
  }

  Future<void> setContactlessDelivery(bool value) async {
    _contactlessDeliveryDefault = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('contactless_delivery', value);
  }

  Future<void> setIncludeUtensils(bool value) async {
    _includeUtensilsDefault = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('include_utensils', value);
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('language', value);
  }

  Future<void> setCurrency(String value) async {
    _currency = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('currency', value);
  }

  Future<void> setBiometricLogin(bool value) async {
    _biometricLoginEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('biometric_login', value);
  }

  Future<void> setDefaultPickupLocation(String value) async {
    _defaultPickupLocation = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('default_pickup_location', value);
  }

  String get fontSizeName {
    if (_fontScale <= 0.85) return 'Small';
    if (_fontScale <= 1.0) return 'Medium';
    if (_fontScale <= 1.15) return 'Large';
    return 'Extra Large';
  }
}
