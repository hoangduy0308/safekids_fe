import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/path_simplifier.dart';
import '../../utils/distance_calculator.dart';
import '../../theme/app_typography.dart';


/// Widget hiển thị Google Maps với vị trí realtime của các child
class ChildLocationMap extends StatefulWidget {
  /// Optional: ID của child cụ thể để focus (nếu null thì show tất cả)
  final String? focusedChildId;
  
  /// Optional: Location được select để show path tới
  final dynamic selectedLocation;
  
  /// Optional: Vị trí trước đó để vẽ polyline
  final dynamic previousLocation;
  
  /// Optional: List of locations to draw path (for Story 2.4)
  final List<dynamic>? pathLocations;
  
  /// Optional: Show path polyline (default: false)
  final bool showPath;
  
  const ChildLocationMap({
    Key? key,
    this.focusedChildId,
    this.selectedLocation,
    this.previousLocation,
    this.pathLocations,
    this.showPath = false,
  }) : super(key: key);

  @override
  State<ChildLocationMap> createState() => _ChildLocationMapState();
}

class _ChildLocationMapState extends State<ChildLocationMap> {
  GoogleMapController? _mapController;
  final SocketService _socketService = SocketService();
  final ApiService _apiService = ApiService();
  
  Map<String, Marker> _markers = {}; // childId -> Marker
  Map<String, ChildLocation> _childLocations = {}; // childId -> Location data
  Set<Polyline> _polylines = {}; // Polylines for path visualization
  bool _isLoading = true;
  String? _errorMessage;
  
  // Path details tracking (Task 7)
  Map<String, dynamic>? _currentPathDetails;
  List<dynamic> _originalPathLocations = [];

  // Default camera position (Vietnam - Hanoi)
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(21.0285, 105.8542),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    debugPrint('=== ChildLocationMap initState CALLED ===');
    print('[MAP_INIT] focusedChildId: ${widget.focusedChildId}, selectedLocation: ${widget.selectedLocation?.latitude}, ${widget.selectedLocation?.longitude}');
    
    // If selectedLocation is passed directly, skip loading all children
    if (widget.selectedLocation != null) {
      print('[INIT] selectedLocation provided, skipping _initializeMap');
      debugPrint('[DEBUG] selectedLocation provided, skipping _initializeMap');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // DON'T call _drawPathIfNeeded here - wait for onMapCreated callback
    } else if (widget.showPath && widget.pathLocations != null && widget.pathLocations!.isNotEmpty) {
      // If path visualization is enabled, skip normal init
      print('[INIT] showPath=true, loading path locations');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      Future.delayed(const Duration(milliseconds: 500), () {
        print('[INIT] Drawing path polyline');
        _drawPathPolyline();
      });
    } else {
      _initializeMap();
      _setupSocketListener();
    }
  }

  @override
  void didUpdateWidget(covariant ChildLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('[UPDATE_WIDGET] Called - selected: ${widget.selectedLocation != null}, prev: ${widget.previousLocation != null}, path: ${widget.showPath}');
    debugPrint('[DEBUG] didUpdateWidget - selected: ${widget.selectedLocation != null}, prev: ${widget.previousLocation != null}');
    
    // Handle path polyline updates (Task 2.4)
    if (widget.showPath != oldWidget.showPath || 
        widget.pathLocations != oldWidget.pathLocations) {
      print('[UPDATE_WIDGET] Path settings changed, redrawing');
      if (widget.showPath && widget.pathLocations != null && widget.pathLocations!.isNotEmpty) {
        _drawPathPolyline();
      } else if (!widget.showPath) {
        _polylines.clear();
        if (mounted) setState(() {});
      }
    }
    
    // Handle single location path drawing
    if (widget.selectedLocation != null && 
        (oldWidget.selectedLocation != widget.selectedLocation ||
         oldWidget.previousLocation != widget.previousLocation)) {
      print('[UPDATE_WIDGET] Location changed, calling _drawPathIfNeeded');
      debugPrint('[DEBUG] Location changed, calling _drawPathIfNeeded');
      _drawPathIfNeeded();
    } else if (widget.selectedLocation != null) {
      print('[UPDATE_WIDGET] selectedLocation exists but not changed');
    }
  }



  Future<void> _initializeMap() async {
    try {
      debugPrint('[ChildLocationMap] _initializeMap START');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final linkedChildren = authProvider.user?.linkedUsersData ?? [];

      if (linkedChildren.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Chưa có con được liên kết';
          });
        }
        return;
      }

      await Future.wait(linkedChildren.where((child) {
      if (child['role'] != 'child') return false;
      if (widget.focusedChildId != null && widget.focusedChildId != child['_id']) return false;
      return true;
    }).map((child) {
      final childId = child['_id'];
      final childName = child['name'] ?? child['fullName'];
      return _fetchChildLocation(childId, childName);
    }));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    if (_markers.isNotEmpty && _mapController != null) {
      _fitMapToMarkers();
    }
    } catch (e) {
      debugPrint('[ERROR] _initializeMap full error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Lỗi tải bản đồ: $e';
        });
      }
    }
  }

  Future<void> _fetchChildLocation(String childId, String childName) async {
    try {
      final response = await _apiService.getChildLatestLocation(childId);
      if (response['success'] == true && response['data'] != null) {
        final locationData = response['data']['location'];
        if (locationData == null) return;

        final location = ChildLocation(
          childId: childId,
          childName: childName,
          latitude: (locationData['latitude'] as num).toDouble(),
          longitude: (locationData['longitude'] as num).toDouble(),
          accuracy: (locationData['accuracy'] as num?)?.toDouble() ?? 0.0,
          timestamp: DateTime.parse(locationData['timestamp']),
        );

        _updateMarker(location);
        if (mounted) {
          setState(() => _childLocations[childId] = location);
        }
      }
    } catch (e) {
      debugPrint('[Map] Error fetching location for $childName: $e');
    }
  }

  void _setupSocketListener() {
    _socketService.onLocationUpdate = (data) {
      debugPrint('[Map] Received socket location update: $data'); // <-- ADDED FOR DEBUGGING
      final childId = data['userId'] ?? data['childId'];
      if (childId == null) return;
      if (widget.focusedChildId != null && widget.focusedChildId != childId) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final linkedChildren = authProvider.user?.linkedUsersData ?? [];
      final isLinked = linkedChildren.any((child) => child['_id'] == childId);
      if (!isLinked) return;

      final childData = linkedChildren.firstWhere((c) => c['_id'] == childId, orElse: () => <String, dynamic>{});
      final childName = childData['name'] ?? childData['fullName'] ?? 'Unknown';

      final location = ChildLocation(
        childId: childId,
        childName: childName,
        latitude: data['latitude'],
        longitude: data['longitude'],
        accuracy: data['accuracy'] ?? 0.0,
        timestamp: DateTime.now(),
      );

      _updateMarker(location);
      if (mounted) {
        setState(() => _childLocations[childId] = location);
      }

      if (_mapController != null) {
        if (_markers.length == 1) {
          _centerOnChild(location);
        } else if (_markers.length > 1) {
          _fitMapToMarkers();
        }
      }
    };
  }

  void _updateMarker(ChildLocation location) {
    final marker = Marker(
      markerId: MarkerId(location.childId),
      position: LatLng(location.latitude, location.longitude),
      infoWindow: InfoWindow(
        title: location.childName,
        snippet: _getTimeAgo(location.timestamp),
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      onTap: () => _showChildDetails(location),
    );
    if (mounted) {
      setState(() => _markers[location.childId] = marker);
    }
  }

  void _fitMapToMarkers() {
    if (_markers.isEmpty || _mapController == null) return;
    final bounds = _calculateBounds(_markers.values.map((m) => m.position).toList());
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  LatLngBounds _calculateBounds(List<LatLng> positions) {
    if (positions.isEmpty) {
      return LatLngBounds(southwest: _defaultPosition.target, northeast: _defaultPosition.target);
    }
    double minLat = positions.first.latitude, maxLat = positions.first.latitude;
    double minLng = positions.first.longitude, maxLng = positions.first.longitude;
    for (var pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  String _getTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  void _showChildDetails(ChildLocation location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(location.childName, style: AppTypography.h2.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _centerOnChild(location);
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Xem trên bản đồ'),
            ),
          ],
        ),
      ),
    );
  }

  void _centerOnChild(ChildLocation location) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(location.latitude, location.longitude), zoom: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('[MAP_BUILD] Building GoogleMap - markers: ${_markers.length}, loading: $_isLoading, error: $_errorMessage');
    
    return Stack(
      alignment: Alignment.center,
      children: [
        GoogleMap(
          initialCameraPosition: _defaultPosition,
          markers: Set<Marker>.of(_markers.values),
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          onMapCreated: (controller) {
            print('[MAP_CREATED] Google Map initialized successfully');
            print('[MAP_CREATED] Markers: ${_markers.length}');
            _mapController = controller;
            
            // If selectedLocation was provided, draw it now
            if (widget.selectedLocation != null) {
              print('[MAP_CREATED] Drawing selectedLocation');
              _drawPathIfNeeded();
            } else if (_markers.isNotEmpty) {
              print('[MAP_CREATED] Fitting map to ${_markers.length} markers');
              _fitMapToMarkers();
            } else {
              print('[MAP_CREATED] No markers or selected location to display');
            }
          },
        ),
        if (_isLoading)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Đang tải vị trí...'),
              ],
            ),
          ),
        if (!_isLoading && _errorMessage != null)
          Center(
            child: Container(
              padding: EdgeInsets.all(16),
              color: Colors.red[50],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _drawPathIfNeeded() async {
    print('[DRAW_PATH] Called - selectedLocation: ${widget.selectedLocation}, mapController: ${_mapController != null}');
    _polylines.clear();
    
    if (widget.selectedLocation == null) {
      print('[DRAW_PATH] selectedLocation is NULL');
      return;
    }
    
    if (_mapController == null) {
      print('[DRAW_PATH] mapController is NULL');
      return;
    }

    try {
      final selectedLat = widget.selectedLocation!.latitude as double;
      final selectedLng = widget.selectedLocation!.longitude as double;
      final selectedPos = LatLng(selectedLat, selectedLng);
      print('[DRAW_PATH] Selected pos: $selectedPos');

      // Animate camera to selected location
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: selectedPos, zoom: 15),
        ),
      );

      // Draw polyline if previous location exists
      if (widget.previousLocation != null) {
        final prevLat = widget.previousLocation.latitude as double;
        final prevLng = widget.previousLocation.longitude as double;
        final prevPos = LatLng(prevLat, prevLng);

        _polylines.add(
          Polyline(
            polylineId: const PolylineId('path_polyline'),
            points: [prevPos, selectedPos],
            color: Colors.blueAccent,
            width: 3,
            geodesic: true,
          ),
        );
      }

      // Add marker at selected location
      _markers['selected'] = Marker(
        markerId: const MarkerId('selected_location'),
        position: selectedPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Selected Location'),
      );

      if (mounted) {
        print('[DRAW_PATH] setState called');
        setState(() {});
      }
      print('[DRAW_PATH] Path drawn successfully');
    } catch (e) {
      print('[DRAW_PATH] ERROR: $e');
      debugPrint('[ChildLocationMap] Error drawing path: $e');
    }
  }

  /// Draw polyline from pathLocations (Task 2.4, with simplification Task 5)
  Future<void> _drawPathPolyline() async {
    print('[PATH_POLY] Called with ${widget.pathLocations?.length ?? 0} locations');
    _polylines.clear();
    _markers.clear();
    
    if (widget.pathLocations == null || widget.pathLocations!.isEmpty) {
      print('[PATH_POLY] No path locations');
      return;
    }

    if (_mapController == null) {
      print('[PATH_POLY] mapController is NULL');
      return;
    }

    try {
      final locations = widget.pathLocations!;
      print('[PATH_POLY] Drawing path with ${locations.length} points');
      
      // Store original locations for details popup (Task 7)
      _originalPathLocations = locations;
      
      // Convert locations to LatLng points (sorted ASC by timestamp)
      var points = <LatLng>[];
      for (var loc in locations) {
        points.add(LatLng(
          (loc.latitude as num).toDouble(),
          (loc.longitude as num).toDouble(),
        ));
      }

      if (points.isEmpty) {
        print('[PATH_POLY] No valid points after conversion');
        return;
      }

      print('[PATH_POLY] Created ${points.length} polyline points');

      // Task 5: Apply path simplification if > 200 points (AC 2.4.6)
      if (points.length > 200) {
        print('[PATH_POLY] Simplifying path from ${points.length} to ~200 points');
        points = PathSimplifier.simplify(points, tolerance: 0.0001);
        print('[PATH_POLY] Simplified to ${points.length} points');
      }

      // Task 7: Calculate path details for popup
      _calculatePathDetails(locations);

      // Create polyline with onTap handler (Task 7)
      _polylines.add(
        Polyline(
          polylineId: PolylineId('path_${widget.focusedChildId ?? "all"}'),
          points: points,
          color: Colors.blue,
          width: 4,
          geodesic: true,
          onTap: () => _showPathDetailsPopup(), // Task 7: Show details on tap
        ),
      );

      // Add start marker (green)
      _markers['path_start'] = Marker(
        markerId: const MarkerId('path_start'),
        position: points.first,
        infoWindow: const InfoWindow(title: 'Điểm bắt đầu'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );

      // Add end marker (red)
      _markers['path_end'] = Marker(
        markerId: const MarkerId('path_end'),
        position: points.last,
        infoWindow: const InfoWindow(title: 'Điểm kết thúc'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );

      // Animate camera to fit path
      if (points.length > 1) {
        final bounds = _getBounds(points);
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
      } else {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: points.first, zoom: 15),
          ),
        );
      }

      if (mounted) {
        print('[PATH_POLY] setState to update polylines');
        setState(() {});
      }
      print('[PATH_POLY] Path polyline drawn successfully');
    } catch (e) {
      print('[PATH_POLY] ERROR: $e');
      debugPrint('[ChildLocationMap] Error drawing path polyline: $e');
    }
  }

  /// Get bounds for multiple LatLng points
  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Calculate path details: distance, time, speed (Task 7 - AC 2.4.4)
  void _calculatePathDetails(List<dynamic> locations) {
    if (locations.isEmpty) return;

    try {
      // Calculate total distance
      double totalDistance = 0;
      for (int i = 1; i < locations.length; i++) {
        final lat1 = (locations[i - 1].latitude as num).toDouble();
        final lng1 = (locations[i - 1].longitude as num).toDouble();
        final lat2 = (locations[i].latitude as num).toDouble();
        final lng2 = (locations[i].longitude as num).toDouble();
        
        totalDistance += DistanceCalculator.haversine(lat1, lng1, lat2, lng2);
      }

      // Get start and end times
      final startTime = locations.first.timestamp as DateTime;
      final endTime = locations.last.timestamp as DateTime;
      final duration = endTime.difference(startTime);

      // Calculate average speed (km/h)
      final durationHours = duration.inMinutes / 60.0;
      final avgSpeed = durationHours > 0 ? totalDistance / durationHours : 0;

      _currentPathDetails = {
        'totalDistance': totalDistance,
        'startTime': startTime,
        'endTime': endTime,
        'duration': duration,
        'avgSpeed': avgSpeed,
        'pointCount': locations.length,
      };

      print('[PATH_DETAILS] Distance: ${totalDistance.toStringAsFixed(2)}km, Speed: ${avgSpeed.toStringAsFixed(1)}km/h, Points: ${locations.length}');
    } catch (e) {
      print('[PATH_DETAILS] Error calculating details: $e');
    }
  }

  /// Show path details popup (Task 7 - AC 2.4.4)
  void _showPathDetailsPopup() {
    if (_currentPathDetails == null) return;

    final details = _currentPathDetails!;
    final distance = (details['totalDistance'] as double).toStringAsFixed(2);
    final avgSpeed = (details['avgSpeed'] as double).toStringAsFixed(1);
    final duration = details['duration'] as Duration;
    final pointCount = details['pointCount'] as int;
    final startTime = details['startTime'] as DateTime;
    final endTime = details['endTime'] as DateTime;

    // Format times
    final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    final durationStr = '${duration.inHours}h ${(duration.inMinutes % 60).toString().padLeft(2, '0')}m';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chi Tiết Đường Đi',
              style: AppTypography.h4.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Distance row
            _detailRow(
              icon: Icons.straighten,
              label: 'Tổng quãng đường',
              value: '$distance km',
            ),

            // Time range row
            _detailRow(
              icon: Icons.access_time,
              label: 'Thời gian',
              value: '$startStr - $endStr ($durationStr)',
            ),

            // Average speed row
            _detailRow(
              icon: Icons.speed,
              label: 'Tốc độ TB',
              value: '$avgSpeed km/h',
            ),

            // Point count row
            _detailRow(
              icon: Icons.location_on_outlined,
              label: 'Số điểm',
              value: '$pointCount',
            ),

            const SizedBox(height: 16),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Detail row widget for path details popup (Task 7)
  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: AppTypography.label.copyWith(color: Colors.grey),
            ),
          ),
          Text(
            value,
            style: AppTypography.label.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class ChildLocation {
  final String childId;
  final String childName;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  ChildLocation({
    required this.childId,
    required this.childName,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}
