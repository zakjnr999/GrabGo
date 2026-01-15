import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service to fetch TURN server credentials from Metered.ca
class TurnCredentialsService {
  static const String _apiUrl = 
      'https://grabgo.metered.live/api/v1/turn/credentials?apiKey=4baae489c45622e681453e58ece2acd9c686';

  /// Fetch fresh TURN credentials from Metered.ca
  /// Returns ICE servers configuration
  static Future<Map<String, dynamic>> fetchTurnCredentials() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      
      if (response.statusCode == 200) {
        final List<dynamic> iceServers = json.decode(response.body);
        
        return {
          'iceServers': iceServers,
        };
      } else {
        throw Exception('Failed to fetch TURN credentials: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to static credentials if API fails
      print('Error fetching TURN credentials: $e');
      return _getFallbackCredentials();
    }
  }

  /// Fallback static credentials (same as current)
  static Map<String, dynamic> _getFallbackCredentials() {
    return {
      'iceServers': [
        {'urls': 'stun:stun.relay.metered.ca:80'},
        {
          'urls': 'turn:global.relay.metered.ca:80',
          'username': '391f82e16b189f1a5fc1e628',
          'credential': 'T0cC8/w3OJ4F3hVD'
        },
        {
          'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
          'username': '391f82e16b189f1a5fc1e628',
          'credential': 'T0cC8/w3OJ4F3hVD'
        },
        {
          'urls': 'turn:global.relay.metered.ca:443',
          'username': '391f82e16b189f1a5fc1e628',
          'credential': 'T0cC8/w3OJ4F3hVD'
        },
        {
          'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
          'username': '391f82e16b189f1a5fc1e628',
          'credential': 'T0cC8/w3OJ4F3hVD'
        }
      ],
    };
  }
}
