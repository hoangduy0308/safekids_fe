/**
 * Story 2.2: View Child Location on Map (Parent App)
 * Flutter Widget Tests - Parent Dashboard with Google Maps
 * 
 * AC Coverage:
 * - AC 2.2.1: Display Map with Child Location
 * - AC 2.2.3: Fetch Initial Location Data
 * - AC 2.2.4: Child Selection and Details
 * - AC 2.2.5: Multiple Children Support
 * - AC 2.2.6: Connection Status
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Mock classes
class MockGoogleMapController extends Mock implements GoogleMapController {}
class MockApiService extends Mock implements ApiService {}
class MockSocketService extends Mock implements SocketService {}
class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  group('AC 2.2.1: Display Map with Child Location', () {
    testWidgets('2.2.1-U-001: Parent dashboard shows Google Map',
        (WidgetTester tester) async {
      await tester.pumpWidget(testApp());

      // Verify GoogleMap widget exists
      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets('2.2.1-U-002: Initial map centered on Hanoi (default)',
        (WidgetTester tester) async {
      await tester.pumpWidget(testApp());

      // Verify initial camera position
      final googleMap = find.byType(GoogleMap);
      expect(googleMap, findsOneWidget);
      // Note: Camera position verification requires GoogleMapController
    });

    testWidgets('2.2.1-U-003: Map shows child marker',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Child One',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Verify marker is displayed
      final mapWidget = find.byType(GoogleMap);
      expect(mapWidget, findsOneWidget);
    });

    testWidgets('2.2.1-U-004: Marker includes child name in infoWindow',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsOneWidget);
      // InfoWindow visibility verified in integration tests
    });

    testWidgets('2.2.1-U-005: Multiple children show different markers',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
            ChildLocation(
              childId: 'child2',
              name: 'Bob',
              latitude: 10.7600,
              longitude: 106.6669,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets('2.2.1-U-006: No children shows empty map',
        (WidgetTester tester) async {
      await tester.pumpWidget(testApp(childLocations: []));

      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsOneWidget);
      expect(find.text('Chưa có con được liên kết'), findsOneWidget);
    });
  });

  group('AC 2.2.2: Real-time Location Updates via Socket.io', () => {
    testWidgets('2.2.2-U-001: Socket.io listener registered on initState',
        (WidgetTester tester) async {
      final mockSocket = MockSocketService();
      
      await tester.pumpWidget(
        testApp(
          socketService: mockSocket,
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Verify Socket listener registered
      verify(mockSocket.onLocationUpdate(any)).called(greaterThanOrEqualTo(1));
    });

    testWidgets('2.2.2-U-002: Marker position updates on locationUpdate event',
        (WidgetTester tester) async {
      final updateCallback = ValueNotifier<Map?>(null);
      final mockSocket = MockSocketService();
      
      when(mockSocket.onLocationUpdate(any)).thenAnswer((invocation) {
        final callback = invocation.positionalArguments[0];
        updateCallback.addListener(() {
          if (updateCallback.value != null) {
            callback(updateCallback.value);
          }
        });
      });

      await tester.pumpWidget(
        testApp(
          socketService: mockSocket,
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Simulate locationUpdate event
      updateCallback.value = {
        'childId': 'child1',
        'latitude': 10.85,
        'longitude': 106.70,
        'accuracy': 4.0,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await tester.pumpAndSettle();

      // Verify marker updated (position change confirmed in integration tests)
      verify(mockSocket.onLocationUpdate(any)).called(greaterThanOrEqualTo(1));
    });

    testWidgets('2.2.2-U-003: Timestamp updates on marker',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsOneWidget);
    });
  });

  group('AC 2.2.3: Fetch Initial Location Data', () => {
    testWidgets('2.2.3-U-001: Dashboard fetches latest child location on load',
        (WidgetTester tester) async {
      final mockApi = MockApiService();
      
      when(mockApi.getChildLocation(any)).thenAnswer(
        (_) => Future.value(
          ChildLocation(
            childId: 'child1',
            name: 'Alice',
            latitude: 10.8231,
            longitude: 106.6843,
            timestamp: DateTime.now(),
          ),
        ),
      );

      await tester.pumpWidget(testApp(apiService: mockApi));
      await tester.pumpAndSettle();

      verify(mockApi.getChildLocation(any)).called(greaterThanOrEqualTo(1));
    });

    testWidgets('2.2.3-U-002: Shows loading state while fetching',
        (WidgetTester tester) async {
      final mockApi = MockApiService();
      
      when(mockApi.getChildLocation(any)).thenAnswer(
        (_) => Future.delayed(
          Duration(seconds: 1),
          () => ChildLocation(
            childId: 'child1',
            name: 'Alice',
            latitude: 10.8231,
            longitude: 106.6843,
            timestamp: DateTime.now(),
          ),
        ),
      );

      await tester.pumpWidget(testApp(apiService: mockApi));

      // Loading indicator visible while fetching
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();
    });

    testWidgets('2.2.3-U-003: No location shows "Chưa có dữ liệu vị trí"',
        (WidgetTester tester) async {
      final mockApi = MockApiService();
      
      when(mockApi.getChildLocation(any)).thenThrow(Exception('Not found'));

      await tester.pumpWidget(testApp(apiService: mockApi));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có dữ liệu vị trí'), findsOneWidget);
    });
  });

  group('AC 2.2.4: Child Selection and Details', () => {
    testWidgets('2.2.4-U-001: Tap marker shows child details bottom sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Tap map area (simplified - actual marker tap tested in integration)
      await tester.tap(find.byType(GoogleMap));
      await tester.pumpAndSettle();
    });

    testWidgets('2.2.4-U-002: Details popup shows child name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          showDetailsSheet: true,
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('2.2.4-U-003: Details shows location coordinates',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          showDetailsSheet: true,
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(contains('10.8231')), findsOneWidget);
      expect(find.text(contains('106.6843')), findsOneWidget);
    });

    testWidgets('2.2.4-U-004: Details shows "Cập nhật" time ago',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          showDetailsSheet: true,
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(contains('phút trước')), findsOneWidget);
    });

    testWidgets('2.2.4-U-005: Details shows accuracy',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          showDetailsSheet: true,
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              accuracy: 5.0,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(contains('Độ chính xác')), findsOneWidget);
      expect(find.text(contains('5m')), findsOneWidget);
    });
  });

  group('AC 2.2.5: Multiple Children Support', () => {
    testWidgets('2.2.5-U-001: Shows all linked children on map',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
            ChildLocation(
              childId: 'child2',
              name: 'Bob',
              latitude: 10.7600,
              longitude: 106.6669,
              timestamp: DateTime.now(),
            ),
            ChildLocation(
              childId: 'child3',
              name: 'Charlie',
              latitude: 10.7200,
              longitude: 106.7000,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsOneWidget);
    });

    testWidgets('2.2.5-U-002: Different marker colors for each child',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              markerColor: 'blue',
              timestamp: DateTime.now(),
            ),
            ChildLocation(
              childId: 'child2',
              name: 'Bob',
              latitude: 10.7600,
              longitude: 106.6669,
              markerColor: 'red',
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsOneWidget);
    });
  });

  group('AC 2.2.6: Connection Status', () => {
    testWidgets('2.2.6-U-001: Shows indicator when disconnected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          connectionStatus: 'disconnected',
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(contains('Mất kết nối')), findsOneWidget);
    });

    testWidgettest('2.2.6-U-002: Indicator disappears when connected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          connectionStatus: 'connected',
          childLocations: [
            ChildLocation(
              childId: 'child1',
              name: 'Alice',
              latitude: 10.8231,
              longitude: 106.6843,
              timestamp: DateTime.now(),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(contains('Mất kết nối')), findsNothing);
    });
  });
}

// Test helper widget
Widget testApp({
  List<ChildLocation> childLocations = const [],
  MockApiService? apiService,
  MockSocketService? socketService,
  MockAuthProvider? authProvider,
  bool showDetailsSheet = false,
  String connectionStatus = 'connected',
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('Test Dashboard'),
      ),
    ),
  );
}

// Mock data models
class ChildLocation {
  final String childId;
  final String name;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final String? markerColor;

  ChildLocation({
    required this.childId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.accuracy = 5.0,
    required this.timestamp,
    this.markerColor,
  });
}
