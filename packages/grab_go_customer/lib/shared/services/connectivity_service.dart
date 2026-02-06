import 'dart:async';
import 'dart:io';

/// Single source of truth for internet connectivity checks.
class ConnectivityService {
  /// Check if the device has an active internet connection.
  ///
  /// Uses DNS lookup to verify actual connectivity (not just network interface).
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
