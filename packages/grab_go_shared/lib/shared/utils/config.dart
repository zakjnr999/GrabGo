class AppConfig {
  // Payment Configuration
  static const String paystackPublicKey = String.fromEnvironment('PAYSTACK_PUBLIC_KEY');

  static const String paystackSecretKey = String.fromEnvironment('PAYSTACK_SECRET_KEY');

  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String apiKey = String.fromEnvironment('API_KEY');

  static const String googlePlacesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: 'AIzaSyBvSX6emxtbMNjweHsnetgASW7vCmBysGQ',
  );

  // App Configuration
  static const String appName = String.fromEnvironment('APP_NAME', defaultValue: 'GrabGo');
  static const String currency = 'GHS';
  static const String defaultCountry = 'Ghana';

  // Development Configuration
  static const bool isDevelopment = bool.fromEnvironment('DEVELOPMENT', defaultValue: false);
  static const bool enableLogging = bool.fromEnvironment('ENABLE_LOGGING', defaultValue: false);

  // Validation methods to ensure required environment variables are set
  static void validateConfiguration() {
    final missingVars = <String>[];

    if (paystackPublicKey.isEmpty) missingVars.add('PAYSTACK_PUBLIC_KEY');
    if (paystackSecretKey.isEmpty) missingVars.add('PAYSTACK_SECRET_KEY');
    if (apiBaseUrl.isEmpty) missingVars.add('API_BASE_URL');
    if (apiKey.isEmpty) missingVars.add('API_KEY');

    if (missingVars.isNotEmpty) {
      throw Exception(
        'Missing required environment variables: ${missingVars.join(', ')}\n'
        'Please check your environment configuration and ensure all required variables are set.',
      );
    }
  }

  // Get safe configuration for logging (masks sensitive data)
  static Map<String, String> getSafeConfig() {
    return {
      'APP_NAME': appName,
      'API_BASE_URL': apiBaseUrl.isNotEmpty ? apiBaseUrl : 'NOT_SET',
      'PAYSTACK_PUBLIC_KEY': paystackPublicKey.isNotEmpty ? '${paystackPublicKey.substring(0, 7)}***' : 'NOT_SET',
      'PAYSTACK_SECRET_KEY': paystackSecretKey.isNotEmpty ? 'sk_***' : 'NOT_SET',
      'API_KEY': apiKey.isNotEmpty ? '***${apiKey.substring(apiKey.length - 3)}' : 'NOT_SET',
      'CURRENCY': currency,
      'COUNTRY': defaultCountry,
      'DEVELOPMENT': isDevelopment.toString(),
      'ENABLE_LOGGING': enableLogging.toString(),
    };
  }
}
