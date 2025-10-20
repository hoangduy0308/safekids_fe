import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../constants/app_constants.dart';
import '../models/location.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Get auth token from SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyToken);
  }

  /// Get authenticated headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    print('[ApiService] Using token: $token'); // Debugging line
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Handle HTTP errors
  void _handleError(http.Response response) {
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      final message = body['message'] ?? body['error'] ?? 'Unknown error occurred';
      throw Exception(message);
    }
  }

  /// SCREEN TIME CONFIGURATION METHODS

  /// Save screen time configuration
  Future<Map<String, dynamic>> saveScreenTimeConfig({
    required String childId,
    required int dailyLimit,
    required bool bedtimeEnabled,
    required String bedtimeStart,
    required String bedtimeEnd,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.screentimeConfig),
        headers: headers,
        body: jsonEncode({
          'childId': childId,
          'dailyLimit': dailyLimit,
          'bedtimeEnabled': bedtimeEnabled,
          'bedtimeStart': bedtimeStart,
          'bedtimeEnd': bedtimeEnd,
        }),
      );

      _handleError(response);
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  /// Get screen time configuration for a child
  Future<Map<String, dynamic>> getScreenTimeConfig(String childId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.screentimeConfig}/$childId'),
        headers: headers,
      );

      _handleError(response);
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  /// Get screen time suggestions for a child
  Future<Map<String, dynamic>> getScreenTimeSuggestions(String childId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.screentimeSuggestions}/$childId'),
        headers: headers,
      );

      _handleError(response);
      final data = jsonDecode(response.body);
      return data['data']; // Extract the data field from response
    } catch (e) {
      rethrow;
    }
  }

  /// SCREEN TIME USAGE METHODS

  /// Record screen time usage (for child device tracking)
  Future<Map<String, dynamic>> recordScreenTimeUsage({
    required String childId,
    required String date,
    required int totalMinutes,
    required List<Map<String, dynamic>> sessions,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.screentimeUsage),
        headers: headers,
        body: jsonEncode({
          'childId': childId,
          'date': date,
          'totalMinutes': totalMinutes,
          'sessions': sessions,
        }),
      );

      _handleError(response);
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  /// Get screen time usage history
  Future<List<Map<String, dynamic>>> getScreenTimeUsageHistory({
    required String childId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final headers = await _getHeaders();
      String url = '${ApiConfig.screentimeUsage}/$childId';
      
      if (startDate != null || endDate != null) {
        final queryParams = <String, String>{};
        if (startDate != null) queryParams['startDate'] = startDate;
        if (endDate != null) queryParams['endDate'] = endDate;
        
        if (queryParams.isNotEmpty) {
          final queryString = queryParams.entries
              .map((e) => '${e.key}=${e.value}')
              .join('&');
          url = '$url?$queryString';
        }
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      _handleError(response);
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    } catch (e) {
      rethrow;
    }
  }

  /// UTILITY METHODS

  /// Make a generic GET request
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers,
      );

      _handleError(response);
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  /// Make a generic POST request
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(body),
      );

      _handleError(response);
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  /// Make a generic PUT request
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(body),
      );

      _handleError(response);
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  /// Make a generic DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse(endpoint),
        headers: headers,
      );

      _handleError(response);
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  /// AUTHENTICATION METHODS

  /// Register new user (no auth required)
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String role,
    int? age,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
          'phone': phone,
          'role': role,
          if (age != null) 'age': age,
        }),
      );

      // Handle registration specific errors
      if (response.statusCode == 400) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Invalid input data');
      } else if (response.statusCode == 409) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Email already registered');
      } else if (response.statusCode >= 400) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? body['message'] ?? 'Registration failed');
      }

      final data = jsonDecode(response.body);
      
      // Auto-save token if registration successful
      if (data['token'] != null) {
        await _saveToken(data['token']);
      }

      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? fcmToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          if (fcmToken != null) 'fcmToken': fcmToken,
        }),
      );

      // Handle login specific errors
      if (response.statusCode == 401) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Invalid email or password');
      } else if (response.statusCode >= 400) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? body['message'] ?? 'Login failed');
      }

      final data = jsonDecode(response.body);
      
      // Auto-save token if login successful
      if (data['token'] != null) {
        await _saveToken(data['token']);
      }

      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Get current user profile (auth required)
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.getMe),
        headers: headers,
      );

      _handleError(response);
      return jsonDecode(response.body);
    } catch (e) {
      rethrow;
    }
  }

  /// USER PROFILE METHODS

  /// Get current user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.getProfile),
        headers: headers,
      );
      
      _handleError(response);
      final data = jsonDecode(response.body);
      return data['user'];
    } catch (e) {
      print('Get profile error: $e');
      rethrow;
    }
  }

  /// Update user profile (fullName, phone)
  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{};
      if (fullName != null) body['fullName'] = fullName;
      if (phone != null) body['phone'] = phone;

      final response = await http.put(
        Uri.parse(ApiConfig.updateProfile),
        headers: headers,
        body: jsonEncode(body),
      );
      
      _handleError(response);
      final data = jsonDecode(response.body);
      return data['user'];
    } catch (e) {
      print('Update profile error: $e');
      rethrow;
    }
  }

  /// Update FCM token for push notifications
  Future<void> updateFCMToken(String fcmToken) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.updateFCMToken),
        headers: headers,
        body: jsonEncode({'fcmToken': fcmToken}),
      );
      
      _handleError(response);
    } catch (e) {
      print('Update FCM token error: $e');
      // Don't rethrow - FCM is optional
    }
  }

  /// Update location settings (Task 2.5.7)
  Future<Map<String, dynamic>> updateLocationSettings(
    bool sharingEnabled,
    String trackingInterval,
    String? pausedUntil,
  ) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'sharingEnabled': sharingEnabled,
        'trackingInterval': trackingInterval,
      };
      if (pausedUntil != null) {
        body['pausedUntil'] = pausedUntil;
      }

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/auth/location-settings'),
        headers: headers,
        body: jsonEncode(body),
      );

      _handleError(response);
      final data = jsonDecode(response.body);
      print('[ApiService] Location settings updated: $data');
      return data;
    } catch (e) {
      print('Update location settings error: $e');
      rethrow;
    }
  }

  /// Clear authentication token (logout)
  Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyToken);
    } catch (e) {
      print('Error clearing token: $e');
    }
  }

  /// Send location update (child only)
  /// Task 2.6.7: Include battery level in location payload
  Future<void> sendLocation(double latitude, double longitude, double accuracy, {int? batteryLevel}) async {
    try {
      final headers = await _getHeaders();
      final body = {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Task 2.6.7: Add battery level if available
      if (batteryLevel != null) {
        body['batteryLevel'] = batteryLevel;
      }
      
      final response = await http.post(
        Uri.parse(ApiConfig.sendLocation),
        headers: headers,
        body: jsonEncode(body),
      );
      
      _handleError(response);
    } catch (e) {
      print('Send location error: $e');
      rethrow;
    }
  }

  /// Get latest location for a specific child (parent only)
  Future<Map<String, dynamic>> getChildLatestLocation(String childId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/location/child/$childId/latest'),
        headers: headers,
      );
      
      _handleError(response);
      return jsonDecode(response.body);
    } catch (e) {
      print('Get child latest location error: $e');
      rethrow;
    }
  }

  // Link Request Methods

  /// Send link request to another user
  Future<Map<String, dynamic>> sendLinkRequest(String receiverEmail, {String? message}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.linkRequest),
        headers: headers,
        body: jsonEncode({
          'receiverEmail': receiverEmail,
          if (message != null) 'message': message,
        }),
      );
      
      _handleError(response);
      final data = jsonDecode(response.body);
      return data['data'];
    } catch (e) {
      print('Send link request error: $e');
      rethrow;
    }
  }

  /// Accept link request
  Future<Map<String, dynamic>> acceptLinkRequest(String requestId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.linkAccept(requestId)),
        headers: headers,
      );
      
      _handleError(response);
      final data = jsonDecode(response.body);
      return data['data'];
    } catch (e) {
      print('Accept link request error: $e');
      rethrow;
    }
  }

  /// Reject link request
  Future<Map<String, dynamic>> rejectLinkRequest(String requestId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.linkReject(requestId)),
        headers: headers,
      );
      
      _handleError(response);
      final data = jsonDecode(response.body);
      return data['data'];
    } catch (e) {
      print('Reject link request error: $e');
      rethrow;
    }
  }

  /// Get all link requests (sent and received)
  Future<List<dynamic>> getLinkRequests({String? status}) async {
    try {
      final headers = await _getHeaders();
      final uri = status != null 
          ? Uri.parse('${ApiConfig.linkRequests}?status=$status')
          : Uri.parse(ApiConfig.linkRequests);
      
      final response = await http.get(uri, headers: headers);
      
      _handleError(response);
      final data = jsonDecode(response.body);
      return data['data']['requests'] ?? [];
    } catch (e) {
      print('Get link requests error: $e');
      rethrow;
    }
  }

  /// Remove child link (parent only)
  Future<void> removeChildLink(String childId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse(ApiConfig.linkRemove(childId)),
        headers: headers,
      );
      
      _handleError(response);
    } catch (e) {
      print('Remove child link error: $e');
      rethrow;
    }
  }

  /// LOCATION HISTORY METHODS

  /// Get location history for a child (Task 4: AC 2.3.1)
  Future<List<Location>> getLocationHistory(
    String childId,
    String startDate,
    String endDate, {
    int limit = 100,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/location/child/$childId/history')
          .replace(queryParameters: {
        'startDate': startDate,
        'endDate': endDate,
        'limit': limit.toString(),
      });

      final response = await http.get(uri, headers: headers);

      _handleError(response);
      final data = jsonDecode(response.body);
      final locations = (data['data']['locations'] as List)
          .map((json) => Location.fromJson(json))
          .toList();
      return locations;
    } catch (e) {
      print('Get location history error: $e');
      rethrow;
    }
  }

  /// Get location stats for a child (Task 2: AC 2.3.4)
  Future<Map<String, dynamic>> getLocationStats(
    String childId,
    String startDate,
    String endDate,
  ) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/location/child/$childId/stats')
          .replace(queryParameters: {
        'startDate': startDate,
        'endDate': endDate,
      });

      final response = await http.get(uri, headers: headers);

      _handleError(response);
      final data = jsonDecode(response.body);
      return data['data'];
    } catch (e) {
      print('Get location stats error: $e');
      rethrow;
    }
  }

  /// Get child battery level (Task 2.6.6)
  Future<int> getChildBatteryLevel(String childId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/child/$childId/battery'),
        headers: headers,
      );

      _handleError(response);
      final data = jsonDecode(response.body);
      return (data['data']['batteryLevel'] as int?) ?? 0;
    } catch (e) {
      print('Get battery level error: $e');
      return 0;
    }
  }

  /// Get geofence suggestions for a child (Story 3.5)
  Future<List<Map<String, dynamic>>> getGeofenceSuggestions(String childId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/geofence/suggestions/$childId'),
        headers: headers,
      );

      _handleError(response);
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']['suggestions'] ?? []);
    } catch (e) {
      print('Get geofence suggestions error: $e');
      rethrow;
    }
  }

  /// Dismiss a geofence suggestion (Story 3.5)
  Future<void> dismissSuggestion(
    String childId,
    double latitude,
    double longitude,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/geofence/suggestions/dismiss'),
        headers: headers,
        body: jsonEncode({
          'childId': childId,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      _handleError(response);
    } catch (e) {
      print('Dismiss suggestion error: $e');
      rethrow;
    }
  }

  /// Get my linked children
  Future<List<Map<String, dynamic>>> getMyChildren() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.getMyChildren),
        headers: headers,
      );

      _handleError(response);
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      print('Get my children error: $e');
      rethrow;
    }
  }

  /// Get all geofences for parent (optionally filtered by child)
  Future<List<dynamic>> getGeofences({String? childId}) async {
    try {
      final headers = await _getHeaders();
      final uri = childId != null
          ? Uri.parse('${ApiConfig.baseUrl}/geofence').replace(queryParameters: {'childId': childId})
          : Uri.parse('${ApiConfig.baseUrl}/geofence');
      
      final response = await http.get(uri, headers: headers);

      _handleError(response);
      final data = jsonDecode(response.body);
      return List<dynamic>.from(data['data']?['geofences'] ?? []);
    } catch (e) {
      print('Get geofences error: $e');
      rethrow;
    }
  }

  /// Create a new geofence
  Future<Map<String, dynamic>> createGeofence({
    required String name,
    required String type,
    required double centerLat,
    required double centerLng,
    required double radius,
    required List<String> linkedChildren,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/geofence'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'type': type,
          'center': {
            'latitude': centerLat,
            'longitude': centerLng,
          },
          'radius': radius,
          'linkedChildren': linkedChildren,
        }),
      );

      _handleError(response);
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data['data'] ?? {});
    } catch (e) {
      print('Create geofence error: $e');
      rethrow;
    }
  }

  /// Update existing geofence
  Future<Map<String, dynamic>> updateGeofence({
    required String geofenceId,
    required String name,
    required String type,
    required double radius,
    required List<String> linkedChildren,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/geofence/$geofenceId'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'type': type,
          'radius': radius,
          'linkedChildren': linkedChildren,
        }),
      );

      _handleError(response);
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data['data'] ?? {});
    } catch (e) {
      print('Update geofence error: $e');
      rethrow;
    }
  }

  /// Get geofence alerts with filters
  Future<Map<String, dynamic>> getGeofenceAlerts({
    String? startDate,
    String? endDate,
    String? childId,
    String? geofenceId,
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{};
      
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (childId != null) queryParams['childId'] = childId;
      if (geofenceId != null) queryParams['geofenceId'] = geofenceId;
      queryParams['limit'] = limit.toString();
      queryParams['skip'] = skip.toString();

      final uri = Uri.parse('${ApiConfig.baseUrl}/geofence/alerts')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: headers);

      _handleError(response);
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data['data'] ?? {});
    } catch (e) {
      print('Get geofence alerts error: $e');
      rethrow;
    }
  }

  /// Delete geofence by ID
  Future<void> deleteGeofence(String geofenceId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/geofence/$geofenceId'),
        headers: headers,
      );

      _handleError(response);
    } catch (e) {
      print('Delete geofence error: $e');
      rethrow;
    }
  }

  /// Update geofence active status
  Future<void> updateGeofenceStatus(String geofenceId, bool active) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/geofence/$geofenceId'),
        headers: headers,
        body: jsonEncode({'active': active}),
      );

      _handleError(response);
    } catch (e) {
      print('Update geofence status error: $e');
      rethrow;
    }
  }

  /// Private helper to save token
  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyToken, token);
    } catch (e) {
      print('Error saving token: $e');
    }
  }
}
