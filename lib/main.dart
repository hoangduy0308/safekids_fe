import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'services/notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/parent/parent_dashboard_screen.dart';
import 'screens/child/child_home_screen.dart';
import 'theme/app_theme.dart';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  debugPrint('🔥 Initializing Firebase...');
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized successfully');
    debugPrint('✅ Firebase apps: ${Firebase.apps}');
    debugPrint('✅ Default app: ${Firebase.app()}');
  } catch (e, stackTrace) {
    debugPrint('❌ Firebase init error: $e');
    debugPrint('❌ Stack trace: $stackTrace');
  }

  // Initialize Notification Service for FCM (Story 3.2)
  debugPrint('🔔 Initializing Notification Service...');
  try {
    await NotificationService().initialize();
    debugPrint('✅ Notification Service initialized');
  } catch (e) {
    debugPrint('❌ Notification Service init error: $e');
  }

  // Initialize Hive for offline storage
  await Hive.initFlutter();
  
  // Initialize FlutterForegroundTask for background location tracking
  FlutterForegroundTask.initCommunicationPort();
  
  runApp(const SafeKidsApp());
}

class SafeKidsApp extends StatelessWidget {
  const SafeKidsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Determine theme based on user role
          // Parent: Purple theme, Child: Teal theme
          final themeData = AppTheme.getTheme(isParent: authProvider.isParent);
          
          return MaterialApp(
            title: 'SafeKids',
            debugShowCheckedModeBanner: false,
            theme: themeData,
            navigatorKey: navigatorKey,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while initializing
        if (authProvider.user == null && authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Not authenticated - show login
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        // Authenticated - route based on role
        if (authProvider.isParent) {
          return const ParentDashboardScreen();
        } else {
          return const ChildHomeScreen();
        }
      },
    );
  }
}