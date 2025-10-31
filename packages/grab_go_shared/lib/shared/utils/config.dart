class AppConfig {
  static const String paystackPublicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
    defaultValue: 'pk_test_d8c9105dfd25cb02a538c4af3214a04ae7a3a804',
  );

  static const String paystackSecretKey = String.fromEnvironment(
    'PAYSTACK_SECRET_KEY',
    defaultValue: 'sk_test_41f11b58301bb0fe6aa1537d6f71dd2b97f73c21',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://grabgo.onrender.com/api',
  );

  static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: 'pAuLInepisT_les');

  static const String appName = String.fromEnvironment('NAME', defaultValue: 'gRAb_gO');
  static const String currency = 'GHS';
  static const String defaultCountry = 'Ghana';
}
