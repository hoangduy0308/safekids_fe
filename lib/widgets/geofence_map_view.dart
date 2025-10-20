import 'dart:math' show log;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/geofence.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'geofence_form_dialog.dart';
import 'geofence_details_sheet.dart';

class GeofenceMapView extends StatefulWidget {
  final String? focusedChildId;
  final List<User> linkedChildren;
  final String? initialFocusedGeofenceId;
  final LatLng? initialCenter;
  final bool startInDrawMode;
  final bool showDrawControls;

  const GeofenceMapView({
    Key? key,
    this.focusedChildId,
    required this.linkedChildren,
    this.initialFocusedGeofenceId,
    this.initialCenter,
    this.startInDrawMode = false,
    this.showDrawControls = true,
  }) : super(key: key);

  @override
  State<GeofenceMapView> createState() => _GeofenceMapViewState();
}

class _GeofenceMapViewState extends State<GeofenceMapView> {
  GoogleMapController? _mapController;
  final ApiService _apiService = ApiService();

  Set<Circle> _circles = {};
  bool _drawMode = false;
  LatLng? _geofenceCenter;
  double _geofenceRadius = 100.0;
  Circle? _tempCircle;
  List<Geofence> _geofences = [];
  bool _isLoading = true;
  String? _focusedGeofenceId;
  List<User> _loadedLinkedChildren = [];
  Future<void>? _childrenLoadFuture;
  bool _hasAnimatedToInitialCenter = false;

  List<User> get _availableChildren => _loadedLinkedChildren.isNotEmpty
      ? _loadedLinkedChildren
      : widget.linkedChildren;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(21.0285, 105.8542),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _drawMode = widget.showDrawControls && widget.startInDrawMode;
    _loadGeofences();
    _loadLinkedChildrenIfNeeded();
    
    // If initialCenter provided, set it up and skip draw mode
    if (widget.initialCenter != null) {
      print('[GeofenceMapView] InitialCenter provided: ${widget.initialCenter}');
      _geofenceCenter = widget.initialCenter;
      _tempCircle = Circle(
        circleId: CircleId('temp'),
        center: widget.initialCenter!,
        radius: _geofenceRadius,
        fillColor: Colors.blue.withOpacity(0.2),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      );
      _drawMode = false;
      
      // Trigger UI update after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('[GeofenceMapView] Post frame callback - temp circle ready');
      });
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    print('[GeofenceMapView] Map created');
    
    // If initialCenter provided, animate camera and show radius slider
    if (widget.initialCenter != null && !_hasAnimatedToInitialCenter) {
      _hasAnimatedToInitialCenter = true;
      print('[GeofenceMapView] Animating to initialCenter: ${widget.initialCenter}');
      
      final zoomLevel = _calculateZoomLevel(_geofenceRadius);
      print('[GeofenceMapView] Zoom level: $zoomLevel');
      
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: widget.initialCenter!, zoom: zoomLevel),
        ),
      );
      
      print('[GeofenceMapView] Animation complete');
      
      // Update circles after animation
      setState(() {
        print('[GeofenceMapView] Updating circles, tempCircle: $_tempCircle');
      });
      
      // Show radius slider after animation completes
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        print('[GeofenceMapView] Showing radius slider');
        _showRadiusSlider();
      }
    }
  }

  Future<void> _loadLinkedChildrenIfNeeded({bool forceReload = false}) async {
    if (!forceReload) {
      if (_loadedLinkedChildren.isNotEmpty) {
        return;
      }
      if (_childrenLoadFuture != null) {
        await _childrenLoadFuture;
        return;
      }
    }

    Future<void> loader() async {
      final Map<String, User> merged = {};
      for (final child in widget.linkedChildren) {
        if (child.id.isNotEmpty) {
          merged[child.id] = child;
        }
      }

      try {
        final children = await _apiService.getMyChildren();
        print('[GeofenceMapView] Loaded ${children.length} children from API');
        for (final rawChild in children) {
          final user = _mapApiChildToUser(rawChild);
          if (user != null && user.id.isNotEmpty) {
            merged[user.id] = user;
          }
        }
      } catch (e) {
        print('[GeofenceMapView] Error loading children: ${e}');
      }

      if (mounted) {
        setState(() {
          _loadedLinkedChildren = merged.values.toList();
        });
      } else {
        _loadedLinkedChildren = merged.values.toList();
      }
    }

    _childrenLoadFuture = loader();
    try {
      await _childrenLoadFuture;
    } finally {
      _childrenLoadFuture = null;
    }
  }

  User? _mapApiChildToUser(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    final dynamic idValue = map['childId'] ?? map['_id'] ?? map['id'];
    final String id = idValue?.toString() ?? '';
    final String name =
        (map['childName'] ?? map['name'] ?? map['fullName'] ?? 'Unknown')
            .toString();

    DateTime createdAt;
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    int? age;
    final ageRaw = map['age'];
    if (ageRaw is int) {
      age = ageRaw;
    } else if (ageRaw is num) {
      age = ageRaw.toInt();
    }

    return User(
      id: id,
      name: name,
      fullName: name,
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString(),
      role: map['role']?.toString() ?? 'child',
      age: age,
      createdAt: createdAt,
    );
  }

  Future<void> _loadGeofences() async {
    try {
      setState(() => _isLoading = true);
      print(
        '[GeofenceMapView] Loading geofences with focusedChildId: ${widget.focusedChildId}',
      );

      // Nếu không có focusedChildId, load tất cả vùng của parent
      final response = await _apiService.getGeofences(
        childId: widget.focusedChildId,
      );
      print('[GeofenceMapView] Raw response: $response');
      print('[GeofenceMapView] Response type: ${response.runtimeType}');

      // Response từ API là List
      final List<dynamic> dataList = response;

      print('[GeofenceMapView] Data list length: ${dataList.length}');

      final geofences = dataList.map((json) {
        print('[GeofenceMapView] Parsing geofence: $json');
        return Geofence.fromJson(json as Map<String, dynamic>);
      }).toList();

      print(
        '[GeofenceMapView] Successfully loaded ${geofences.length} geofences',
      );
      setState(() {
        _geofences = geofences;
        _updateCircles();
        _isLoading = false;
      });
      print('[GeofenceMapView] Circles count: ${_circles.length}');

      //  NEW: Focus on initial geofence if provided
      if (widget.initialFocusedGeofenceId != null) {
        await Future.delayed(
          Duration(milliseconds: 300),
        ); // Wait for map to render
        if (mounted && _mapController != null) {
          print(
            '[GeofenceMapView] Map ready, focusing on geofence: ${widget.initialFocusedGeofenceId}',
          );
          await _focusOnGeofence(widget.initialFocusedGeofenceId!);
        } else {
          print('[GeofenceMapView] Map not ready, will skip focus');
        }
      }
      // Không auto-focus vào vùng đầu tiên - chỉ focus khi user click
      // Cách này tránh show detail sheet khi vừa vào map để tạo vùng mới
    } catch (e) {
      print('Error loading geofences: $e');
      print('Stack trace: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //  NEW: Calculate zoom level based on radius
  double _calculateZoomLevel(double radiusInMeters) {
    final maxDistance = radiusInMeters * 2.5;
    final zoomLevel = 16 - (log(maxDistance / 400) / log(2));
    return zoomLevel.clamp(10.0, 20.0);
  }

  //  NEW: Focus on specific geofence with highlight + auto-show details
  Future<void> _focusOnGeofence(String geofenceId) async {
    final geofence = _geofences.where((g) => g.id == geofenceId).firstOrNull;
    if (geofence == null || _mapController == null) return;

    setState(() => _focusedGeofenceId = geofenceId);

    final zoomLevel = _calculateZoomLevel(geofence.radius);
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: geofence.latLng, zoom: zoomLevel),
      ),
    );

    // Auto-show details sheet after animation
    await Future.delayed(Duration(milliseconds: 500));
    if (mounted) {
      _showGeofenceDetails(geofence);
    }
  }

  void _updateCircles() {
    _circles.clear();
    for (final geofence in _geofences) {
      final isFocused = _focusedGeofenceId == geofence.id;
      final color = geofence.isDangerZone ? Colors.red : Colors.green;

      print(
        '[GeofenceMapView] Creating circle for ${geofence.name}: center=${geofence.latLng}, radius=${geofence.radius}',
      );

      _circles.add(
        Circle(
          circleId: CircleId(geofence.id),
          center: geofence.latLng,
          radius: geofence.radius,
          fillColor: color.withOpacity(isFocused ? 0.4 : 0.2),
          strokeColor: isFocused ? color : color,
          strokeWidth: isFocused ? 4 : 2,
          onTap: () => _showGeofenceDetails(geofence),
        ),
      );
    }
    print('[GeofenceMapView] Updated circles, total: ${_circles.length}');
  }

  Set<Circle> _getDisplayCircles() {
    // Nếu có temp circle (đang vẽ vùng mới hoặc từ suggestion), hiển thị nó
    if (_tempCircle != null) {
      print('[GetDisplayCircles] Showing temp circle at ${_tempCircle!.center}');
      return {..._circles, _tempCircle!};
    }

    // Nếu có vùng được focus (click vào để xem), chỉ hiển thị vùng đó
    if (_focusedGeofenceId != null) {
      print(
        '[GetDisplayCircles] Filtering to focused geofence: $_focusedGeofenceId',
      );
      final filteredCircles = _circles
          .where((c) => c.circleId.value == _focusedGeofenceId)
          .toSet();
      print('[GetDisplayCircles] Showing ${filteredCircles.length} circle(s)');
      return filteredCircles;
    }

    // Không có focus, hiển thị tất cả
    print('[GetDisplayCircles] Showing all ${_circles.length} geofence circles');
    return _circles;
  }

  Future<void> _goToMyLocation() async {
    try {
      print('[GoToMyLocation] Requesting location permission');

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cần cấp quyền truy cập vị trí')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vui lòng cấp quyền trong cài đặt')),
        );
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      print(
        '[GoToMyLocation] Got position: ${position.latitude}, ${position.longitude}',
      );

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
        );
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã định vị vị trí của bạn')));
    } catch (e) {
      print('[GoToMyLocation] Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi định vị: $e')));
    }
  }

  void _onMapTap(LatLng position) {
    if (_drawMode) {
      setState(() {
        _geofenceCenter = position;
        _tempCircle = Circle(
          circleId: CircleId('temp'),
          center: position,
          radius: _geofenceRadius,
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        );
      });
      _showRadiusSlider();
    }
  }

  void _showRadiusSlider() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Điều chỉnh bán kính',
                style: AppTypography.h4.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('${_geofenceRadius.toInt()}m', style: AppTypography.h2),
              Slider(
                value: _geofenceRadius,
                min: 50,
                max: 1000,
                divisions: 19,
                label: '${_geofenceRadius.toInt()}m',
                onChanged: (value) {
                  setModalState(() => _geofenceRadius = value);
                  setState(() {
                    _tempCircle = _tempCircle!.copyWith(radiusParam: value);
                  });
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _showGeofenceForm();
                },
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGeofenceForm({Geofence? editingGeofence}) async {
    await _loadLinkedChildrenIfNeeded(forceReload: true);
    final childrenToUse = _availableChildren;

    if (childrenToUse.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa có trẻ em được liên kết để áp dụng vùng'),
          ),
        );
      }
      return;
    }

    print('[ShowGeofenceForm] Children count: ${childrenToUse.length}');

    await showDialog(
      context: context,
      builder: (context) => GeofenceFormDialog(
        center: editingGeofence?.latLng ?? _geofenceCenter!,
        radius: editingGeofence?.radius ?? _geofenceRadius,
        linkedChildren: childrenToUse,
        existingData: editingGeofence != null
            ? {
                'name': editingGeofence.name,
                'type': editingGeofence.type,
                'radius': editingGeofence.radius,
                'linkedChildren': editingGeofence.linkedChildren,
              }
            : null,
        onSave: (data) {
          if (editingGeofence != null) {
            _updateGeofence(editingGeofence.id, data);
          } else {
            _createGeofence(data);
          }
        },
      ),
    );
  }

  Future<void> _createGeofence(Map<String, dynamic> data) async {
    try {
      print('[CreateGeofence] Bắt đầu tạo vùng: ${data['name']}');
      print(
        '[CreateGeofence] Center: ${_geofenceCenter}, Radius: ${data['radius']}',
      );
      print('[CreateGeofence] LinkedChildren: ${data['linkedChildren']}');

      final result = await _apiService.createGeofence(
        name: data['name'],
        type: data['type'],
        centerLat: _geofenceCenter!.latitude,
        centerLng: _geofenceCenter!.longitude,
        radius: data['radius'],
        linkedChildren: data['linkedChildren'],
      );

      print('[CreateGeofence] API response: $result');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã tạo vùng ${data['name']}')));

      print('[CreateGeofence] Gọi _loadGeofences() để refresh...');
      await _loadGeofences();

      print('[CreateGeofence] Refresh xong, cập nhật UI');
      setState(() {
        _drawMode = false;
        _geofenceCenter = null;
        _tempCircle = null;
      });
      print('[CreateGeofence] Hoàn tất');
    } catch (e, stackTrace) {
      print('[CreateGeofence] LỖI: $e');
      print('[CreateGeofence] Stack trace: $stackTrace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _updateGeofence(String id, Map<String, dynamic> data) async {
    try {
      await _apiService.updateGeofence(
        geofenceId: id,
        name: data['name'],
        type: data['type'],
        radius: data['radius'],
        linkedChildren: data['linkedChildren'],
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã cập nhật vùng')));

      _loadGeofences();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteGeofence(String id) async {
    try {
      await _apiService.deleteGeofence(id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã xóa vùng')));
      _loadGeofences();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  void _showGeofenceDetails(Geofence geofence) {
    setState(() => _focusedGeofenceId = geofence.id);
    print(
      '[ShowGeofenceDetails] Set focus to ${geofence.name} (${geofence.id})',
    );

    _loadLinkedChildrenIfNeeded().then((_) {
      if (!mounted) return;
      final childrenNames = _getChildrenNames(geofence.linkedChildren);

      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => GeofenceDetailsSheet(
          geofence: geofence,
          linkedChildrenNames: childrenNames,
          onEdit: () async {
            Navigator.pop(context);
            await _showGeofenceForm(editingGeofence: geofence);
          },
          onDelete: () {
            Navigator.pop(context);
            _showDeleteConfirmation(geofence);
          },
        ),
      ).then((_) {
        if (!mounted) return;
        setState(() => _focusedGeofenceId = null);
        print('[ShowGeofenceDetails] Cleared focus');
      });
    });
  }

  void _showDeleteConfirmation(Geofence geofence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa vùng?'),
        content: Text('Bạn có chắc muốn xóa vùng "${geofence.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGeofence(geofence.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Xóa',
              style: AppTypography.button.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getChildrenNames(List<String> childIds) {
    final available = _availableChildren;
    return available
        .where((child) => childIds.contains(child.id))
        .map((child) => {'name': child.name, 'id': child.id})
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_drawMode ? 'Vẽ Vùng Mới' : 'Quản Lý Vùng'),
        backgroundColor: _drawMode ? Colors.blue : AppColors.parentPrimaryLight,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _defaultPosition,
            circles: _getDisplayCircles(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: _onMapCreated,
            onTap: widget.showDrawControls ? _onMapTap : null,
          ),
          if (_isLoading) Center(child: CircularProgressIndicator()),
          // Status indicator + Create zone toggle
          if (widget.showDrawControls)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(blurRadius: 4, color: Colors.black12),
                      ],
                    ),
                    child: Text(
                      'Vùng: ${_circles.length}',
                      style: AppTypography.captionSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!_drawMode)
                    GestureDetector(
                      onTap: () => setState(() => _drawMode = true),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.parentPrimaryLight,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(blurRadius: 4, color: Colors.black12),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_location,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Vẽ vùng',
                              style: AppTypography.captionSmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => setState(() => _drawMode = false),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(blurRadius: 4, color: Colors.black12),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.close, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Hủy',
                              style: AppTypography.captionSmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_drawMode && widget.showDrawControls)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Nhấn vào bản đồ để chọn tâm vùng',
                  style: AppTypography.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          // Zoom controls + location button (repositioned to avoid collision)
          Positioned(
            bottom: 80,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  onPressed: () async {
                    if (_mapController != null) {
                      await _mapController!.animateCamera(
                        CameraUpdate.zoomBy(1),
                      );
                    }
                  },
                  child: Icon(Icons.add, color: AppColors.parentPrimaryLight),
                ),
                SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.white,
                  onPressed: () async {
                    if (_mapController != null) {
                      await _mapController!.animateCamera(
                        CameraUpdate.zoomBy(-1),
                      );
                    }
                  },
                  child: Icon(
                    Icons.remove,
                    color: AppColors.parentPrimaryLight,
                  ),
                ),
                SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  backgroundColor: Colors.white,
                  onPressed: _goToMyLocation,
                  child: Icon(
                    Icons.my_location,
                    color: AppColors.parentPrimaryLight,
                  ),
                ),
              ],
            ),
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
