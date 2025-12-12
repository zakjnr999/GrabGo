import 'package:flutter/material.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';
import 'package:grab_go_shared/shared/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsProvider extends ChangeNotifier {
  // Notification preferences (9 types)
  bool _chatMessagesEnabled = true;
  bool _orderUpdatesEnabled = true;
  bool _promoNotificationsEnabled = true;
  bool _commentRepliesEnabled = true;
  bool _commentReactionsEnabled = true;
  bool _referralUpdatesEnabled = true;
  bool _paymentUpdatesEnabled = true;
  bool _deliveryUpdatesEnabled = true;
  bool _systemUpdatesEnabled = true;
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

  // Getters - Notification Settings
  bool get chatMessagesEnabled => _chatMessagesEnabled;
  bool get orderUpdatesEnabled => _orderUpdatesEnabled;
  bool get promoNotificationsEnabled => _promoNotificationsEnabled;
  bool get commentRepliesEnabled => _commentRepliesEnabled;
  bool get commentReactionsEnabled => _commentReactionsEnabled;
  bool get referralUpdatesEnabled => _referralUpdatesEnabled;
  bool get paymentUpdatesEnabled => _paymentUpdatesEnabled;
  bool get deliveryUpdatesEnabled => _deliveryUpdatesEnabled;
  bool get systemUpdatesEnabled => _systemUpdatesEnabled;
  bool get notificationSoundEnabled => _notificationSoundEnabled;

  // Other getters
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

      // Load from local cache first (for offline)
      _chatMessagesEnabled = _prefs!.getBool('chat_messages') ?? true;
      _orderUpdatesEnabled = _prefs!.getBool('order_updates') ?? true;
      _promoNotificationsEnabled = _prefs!.getBool('promo_notifications') ?? true;
      _commentRepliesEnabled = _prefs!.getBool('comment_replies') ?? true;
      _commentReactionsEnabled = _prefs!.getBool('comment_reactions') ?? true;
      _referralUpdatesEnabled = _prefs!.getBool('referral_updates') ?? true;
      _paymentUpdatesEnabled = _prefs!.getBool('payment_updates') ?? true;
      _deliveryUpdatesEnabled = _prefs!.getBool('delivery_updates') ?? true;
      _systemUpdatesEnabled = _prefs!.getBool('system_updates') ?? true;
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

      // Sync with backend in background
      _loadNotificationSettingsFromBackend();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Load notification settings from backend
  Future<void> _loadNotificationSettingsFromBackend() async {
    try {
      final token = await CacheService.getAuthToken();
      if (token == null) {
        debugPrint('⚠️ No auth token, skipping backend sync');
        return;
      }

      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/users/settings/notifications'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['notificationSettings'] != null) {
          final settings = data['notificationSettings'] as Map<String, dynamic>;

          _chatMessagesEnabled = settings['chatMessages'] ?? true;
          _orderUpdatesEnabled = settings['orderUpdates'] ?? true;
          _promoNotificationsEnabled = settings['promoNotifications'] ?? true;
          _commentRepliesEnabled = settings['commentReplies'] ?? true;
          _commentReactionsEnabled = settings['commentReactions'] ?? true;
          _referralUpdatesEnabled = settings['referralUpdates'] ?? true;
          _paymentUpdatesEnabled = settings['paymentUpdates'] ?? true;
          _deliveryUpdatesEnabled = settings['deliveryUpdates'] ?? true;
          _systemUpdatesEnabled = settings['systemUpdates'] ?? true;

          // Save to local cache
          await _saveNotificationSettingsLocally();
          notifyListeners();

          debugPrint('✅ Notification settings synced from backend');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not sync notification settings from backend: $e');
      // Continue with local cache
    }
  }

  /// Save notification settings to local cache
  Future<void> _saveNotificationSettingsLocally() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('chat_messages', _chatMessagesEnabled);
    await _prefs!.setBool('order_updates', _orderUpdatesEnabled);
    await _prefs!.setBool('promo_notifications', _promoNotificationsEnabled);
    await _prefs!.setBool('comment_replies', _commentRepliesEnabled);
    await _prefs!.setBool('comment_reactions', _commentReactionsEnabled);
    await _prefs!.setBool('referral_updates', _referralUpdatesEnabled);
    await _prefs!.setBool('payment_updates', _paymentUpdatesEnabled);
    await _prefs!.setBool('delivery_updates', _deliveryUpdatesEnabled);
    await _prefs!.setBool('system_updates', _systemUpdatesEnabled);
  }

  /// Sync notification settings with backend
  Future<void> _syncNotificationSettingsWithBackend() async {
    try {
      final token = await CacheService.getAuthToken();
      if (token == null) {
        debugPrint('⚠️ No auth token, skipping backend sync');
        return;
      }

      final response = await http
          .patch(
            Uri.parse('${AppConfig.apiBaseUrl}/users/settings/notifications'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'settings': {
                'chatMessages': _chatMessagesEnabled,
                'orderUpdates': _orderUpdatesEnabled,
                'promoNotifications': _promoNotificationsEnabled,
                'commentReplies': _commentRepliesEnabled,
                'commentReactions': _commentReactionsEnabled,
                'referralUpdates': _referralUpdatesEnabled,
                'paymentUpdates': _paymentUpdatesEnabled,
                'deliveryUpdates': _deliveryUpdatesEnabled,
                'systemUpdates': _systemUpdatesEnabled,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Notification settings synced to backend');
      }
    } catch (e) {
      debugPrint('⚠️ Could not sync notification settings to backend: $e');
      // Settings still saved locally
    }
  }

  // Notification setters with backend sync
  Future<void> setChatMessages(bool value) async {
    _chatMessagesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('chat_messages', value);
    await _syncNotificationSettingsWithBackend();
  }

  Future<void> setOrderUpdates(bool value) async {
    _orderUpdatesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('order_updates', value);
    await _syncNotificationSettingsWithBackend();
  }

  Future<void> setPromoNotifications(bool value) async {
    _promoNotificationsEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('promo_notifications', value);
    await _syncNotificationSettingsWithBackend();
  }

  Future<void> setCommentReplies(bool value) async {
    _commentRepliesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('comment_replies', value);
    await _syncNotificationSettingsWithBackend();
  }

  Future<void> setCommentReactions(bool value) async {
    _commentReactionsEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('comment_reactions', value);
    await _syncNotificationSettingsWithBackend();
  }

  Future<void> setReferralUpdates(bool value) async {
    _referralUpdatesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('referral_updates', value);
    await _syncNotificationSettingsWithBackend();
  }

  Future<void> setPaymentUpdates(bool value) async {
    _paymentUpdatesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('payment_updates', value);
    await _syncNotificationSettingsWithBackend();
  }

  Future<void> setDeliveryUpdates(bool value) async {
    _deliveryUpdatesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('delivery_updates', value);
    await _syncNotificationSettingsWithBackend();
  }

  Future<void> setSystemUpdates(bool value) async {
    _systemUpdatesEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('system_updates', value);
    await _syncNotificationSettingsWithBackend();
  }

  Future<void> setNotificationSound(bool value) async {
    _notificationSoundEnabled = value;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool('notification_sound', value);
  }

  // Other setters (unchanged)
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
