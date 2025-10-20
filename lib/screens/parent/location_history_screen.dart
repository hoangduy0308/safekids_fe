import 'package:flutter/material.dart';
import 'package:safekids_app/models/location.dart';
import 'package:safekids_app/services/api_service.dart';
import 'package:safekids_app/utils/distance_calculator.dart';
import 'package:safekids_app/widgets/parent/child_location_map.dart';
import 'package:safekids_app/theme/app_typography.dart';

class LocationHistoryScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const LocationHistoryScreen({
    Key? key,
    required this.childId,
    required this.childName,
  }) : super(key: key);

  @override
  _LocationHistoryScreenState createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen> {
  List<Location> _locations = [];
  bool _loading = true;
  String _selectedFilter = 'Hôm nay';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  Map<String, dynamic>? _backendStats;
  bool _useBackendStats = true;

  @override
  void initState() {
    super.initState();
    _loadHistory('today');
  }

  Future<void> _loadHistory(String filter) async {
    setState(() => _loading = true);

    DateTime startDate;
    DateTime endDate = DateTime.now();

    switch (filter) {
      case 'today':
        startDate = DateTime.now().subtract(const Duration(hours: 24));
        break;
      case '7days':
        startDate = DateTime.now().subtract(const Duration(days: 7));
        break;
      case '30days':
        startDate = DateTime.now().subtract(const Duration(days: 30));
        break;
      default:
        startDate = DateTime.now().subtract(const Duration(hours: 24));
    }

    try {
      final locations = await ApiService().getLocationHistory(
        widget.childId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      );
      
      // Try to fetch backend stats
      await _loadStats(widget.childId, startDate, endDate);
      
      setState(() {
        _locations = locations;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadStats(String childId, DateTime startDate, DateTime endDate) async {
    try {
      final stats = await ApiService().getLocationStats(
        childId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      );
      setState(() {
        _backendStats = stats;
        _useBackendStats = true;
      });
    } catch (e) {
      print('Backend stats error (using frontend calculation): $e');
      setState(() => _useBackendStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lịch Sử - ${widget.childName}')),
      body: Column(
        children: [
          _buildStatsCard(),
          _buildFilterChips(),
          Expanded(child: _buildTimeline()),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    late double totalDistance;
    late double totalTime;
    late List<LocationCluster> mostVisited;

    if (_useBackendStats && _backendStats != null) {
      // Use backend stats
      totalDistance = (_backendStats!['totalDistance'] as num).toDouble();
      totalTime = (_backendStats!['totalTime'] as num).toDouble();
      mostVisited = _parseBackendMostVisited(_backendStats!['mostVisited'] ?? []);
    } else {
      // Fallback to frontend calculation
      totalDistance = _calculateTotalDistance();
      totalTime = _calculateTotalTime();
      mostVisited = _calculateMostVisited();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(Icons.directions_walk, '${totalDistance.toStringAsFixed(1)} km', 'Di chuyển'),
                _statItem(Icons.access_time, '${totalTime.toStringAsFixed(1)} h', 'Theo dõi'),
                _statItem(Icons.location_on, '${_locations.length}', 'Điểm'),
              ],
            ),
            if (mostVisited.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildMostVisitedSection(mostVisited),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMostVisitedSection(List<LocationCluster> clusters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Địa điểm thường xuyên',
          style: AppTypography.captionSmall.copyWith(color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: clusters
              .asMap()
              .entries
              .map((e) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e.key + 1}. ${e.value.count}x',
                                style: AppTypography.overline.copyWith(fontWeight: FontWeight.bold)),
                            Text('${e.value.latitude.toStringAsFixed(4)}, ${e.value.longitude.toStringAsFixed(4)}',
                                style: AppTypography.overline.copyWith(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(height: 8),
        Text(value, style: AppTypography.h4.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: AppTypography.captionSmall.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip('Hôm nay', 'today'),
          _filterChip('7 ngày', '7days'),
          _filterChip('30 ngày', '30days'),
          _filterChip('Tùy chỉnh', 'custom'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedFilter == label,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedFilter = label);
            if (value == 'custom') {
              _showDateRangePicker();
            } else {
              _loadHistory(value);
            }
          }
        },
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      await _loadCustomRange();
    }
  }

  Future<void> _loadCustomRange() async {
    if (_customStartDate == null || _customEndDate == null) return;
    
    setState(() => _loading = true);
    try {
      final locations = await ApiService().getLocationHistory(
        widget.childId,
        _customStartDate!.toIso8601String(),
        _customEndDate!.toIso8601String(),
      );
      
      // Try to fetch backend stats for custom range
      await _loadStats(widget.childId, _customStartDate!, _customEndDate!);
      
      setState(() {
        _locations = locations;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    }
  }

  List<LocationCluster> _parseBackendMostVisited(dynamic data) {
    if (data is! List) return [];
    
    return data
        .take(3)
        .map((item) => LocationCluster(
          latitude: (item['latitude'] as num).toDouble(),
          longitude: (item['longitude'] as num).toDouble(),
          count: item['count'] as int,
        ))
        .toList();
  }

  Widget _buildTimeline() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_locations.isEmpty) return const Center(child: Text('Chưa có lịch sử vị trí'));

    return ListView.builder(
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final loc = _locations[index];
        final prevLoc = index < _locations.length - 1 ? _locations[index + 1] : null;
        final nextLoc = index > 0 ? _locations[index - 1] : null;
        final distance = prevLoc != null ? calculateHaversineDistance(loc, prevLoc) : 0.0;
        final durationAtLocation = nextLoc != null 
            ? loc.timestamp.difference(nextLoc.timestamp).inMinutes 
            : 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.location_on, color: Colors.blue),
            title: Text(_formatTimestamp(loc.timestamp)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}',
                  style: AppTypography.captionSmall.copyWith(color: Colors.grey),
                ),
                if (durationAtLocation > 0)
                  Text(
                    'Đã ở: ${durationAtLocation}m',
                    style: AppTypography.overline.copyWith(color: Colors.orange),
                  ),
              ],
            ),
            trailing: distance > 0.01 
                ? Chip(
                    label: Text('${distance.toStringAsFixed(2)} km'),
                    avatar: Icon(Icons.arrow_upward, size: 14),
                  )
                : null,
            onTap: () => _viewOnMap(loc, previousLocation: prevLoc),
            isThreeLine: durationAtLocation > 0,
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final dateStr = '${timestamp.day}/${timestamp.month}/${timestamp.year}';

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    
    return '$timeStr - $dateStr';
  }

  void _viewOnMap(Location location, {Location? previousLocation}) {
    print('[DEBUG] _viewOnMap called: loc=$location, prev=$previousLocation');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          print('[DEBUG] Building map screen');
          return Scaffold(
            appBar: AppBar(
              title: const Text('Vị Trí Trên Bản Đồ'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: ChildLocationMap(
              selectedLocation: location,
              previousLocation: previousLocation,
            ),
          );
        },
      ),
    );
  }

  List<LocationCluster> _calculateMostVisited() {
    if (_locations.isEmpty) return [];
    
    const clusterRadius = 0.1; // km
    final clusters = <LocationCluster>[];
    final visited = <int>{};
    
    for (int i = 0; i < _locations.length; i++) {
      if (visited.contains(i)) continue;
      
      final cluster = LocationCluster(
        latitude: _locations[i].latitude,
        longitude: _locations[i].longitude,
        count: 1,
      );
      visited.add(i);
      
      for (int j = i + 1; j < _locations.length; j++) {
        if (visited.contains(j)) continue;
        
        final distance = calculateHaversineDistance(_locations[i], _locations[j]);
        if (distance <= clusterRadius) {
          cluster.count++;
          visited.add(j);
        }
      }
      clusters.add(cluster);
    }
    
    clusters.sort((a, b) => b.count.compareTo(a.count));
    return clusters.take(3).toList();
  }

  double _calculateTotalDistance() {
    if (_locations.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 1; i < _locations.length; i++) {
      total += calculateHaversineDistance(_locations[i - 1], _locations[i]);
    }
    return total;
  }

  double _calculateTotalTime() {
    if (_locations.isEmpty) return 0.0;
    final firstTimestamp = _locations.last.timestamp;
    final lastTimestamp = _locations.first.timestamp;
    final duration = lastTimestamp.difference(firstTimestamp);
    return duration.inMinutes / 60.0;
  }
}

class LocationCluster {
  double latitude;
  double longitude;
  int count;
  
  LocationCluster({
    required this.latitude,
    required this.longitude,
    required this.count,
  });
}
