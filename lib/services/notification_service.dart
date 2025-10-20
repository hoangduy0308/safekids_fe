import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  // Stream controllers for handling notification events
  final StreamController<RemoteMessage> _onMessageStream = StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _onMessageOpenedAppStream = StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _onBackgroundMessageStream = StreamController<RemoteMessage>.broadcast();

  // Global navigator key for navigation from notifications
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // Error handling flag
  bool _firebaseAvailable = true;

  // Getters for subscribing to notification events
  Stream<RemoteMessage> get onMessage => _onMessageStream.stream;
  Stream<RemoteMessage> get onMessageOpenedApp => _onMessageOpenedAppStream.stream;
  Stream<RemoteMessage> get onBackgroundMessage => _onBackgroundMessageStream.stream;

  Future<void> initialize() async {
    try {
      // Initialize Firebase with fallback options
      try {
        await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
      } catch (e) {
        debugPrint('⚠️ [Notification] Permission request failed: $e');
        _firebaseAvailable = false;
      }

      // Get FCM token with error handling
      try {
        final token = await _firebaseMessaging.getToken();
        debugPrint('🔔 [Notification] FCM Token: $token');
        debugPrint('✅ [Notification] Firebase initialized successfully');
      } catch (e) {
        debugPrint('⚠️ [Notification] FCM token retrieval failed: $e');
        _firebaseAvailable = false;
      }

      // Setup message handlers with error trapping
      try {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        debugPrint('⚠️ [Notification] Message handlers setup failed: $e');
        _firebaseAvailable = false;
      }

      debugPrint('✅ [Notification] Service initialized');
    } catch (e) {
      debugPrint('❌ [Notification] Initialization error: $e');
      _firebaseAvailable = false;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('🔔 [Notification] Foreground message: ${message.notification?.title}');
    debugPrint('🔔 [Notification] Data: ${message.data}');

    // Add to stream for listeners
    _onMessageStream.add(message);

    // Handle specific notification types
    _handleNotificationData(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 [Notification] Message opened from background: ${message.data}');

    // Add to stream for listeners
    _onMessageOpenedAppStream.add(message);

    // Handle navigation or other actions based on notification data
    _handleNotificationData(message);
  }

  void _handleNotificationData(RemoteMessage message) {
    final data = message.data;
    
    if (data['type'] == 'geofence') {
      debugPrint('🔔 [Notification] Geofence alert received');
      _showGeofenceAlertSnackBar(message);
    }
  }

  void _showGeofenceAlertSnackBar(RemoteMessage message) {
    // Get current context from navigator key
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text(message.notification?.body ?? 'Geofence alert')),
            ],
          ),
          backgroundColor: Colors.orange.shade100,
          duration: Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Xem',
            textColor: Colors.orange.shade900,
            onPressed: () {
              _navigateToMap(message.data['geofenceId']);
            },
          ),
        ),
      );
    }
  }

  void _navigateToMap(String? geofenceId) {
    if (geofenceId != null) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.pushNamed(
          context,
          '/parent-dashboard',
          arguments: {'highlightGeofence': geofenceId},
        );
      }
    }
  }

  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      debugPrint('❌ [Notification] Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('🔔 [Notification] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ [Notification] Error subscribing to topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('🔔 [Notification] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ [Notification] Error unsubscribing from topic: $e');
    }
  }

  void dispose() {
    _onMessageStream.close();
    _onMessageOpenedAppStream.close();
    _onBackgroundMessageStream.close();
  }
}

// Background message handler (top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [Notification] Background message: ${message.notification?.title}');
  
  // Initialize Firebase if needed
  // await Firebase.initializeApp();
  
  // Handle background message
  final notificationService = NotificationService();
  notificationService._onBackgroundMessageStream.add(message);
}

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
