import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/location.dart' as location_model;
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/parent/child_location_map.dart';

/// Dedicated map screen with path visualization controls (Task 2.4)
class ChildMapScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final location_model.Location? selectedLocation;
  final location_model.Location? previousLocation;

  const ChildMapScreen({
    Key? key,
    required this.childId,
    required this.childName,
    this.selectedLocation,
    this.previousLocation,
  }) : super(key: key);

  @override
  State<ChildMapScreen> createState() => _ChildMapScreenState();
}

class _ChildMapScreenState extends State<ChildMapScreen> {
  bool _showPath = false;
  int _pathHours = 2;
  List<dynamic>? _pathLocations;
  bool _pathLoading = false;

  /// Load path data for child
  Future<void> _loadPathData() async {
    setState(() => _pathLoading = true);
    
    try {
      final startDate = DateTime.now().subtract(Duration(hours: _pathHours));
      final endDate = DateTime.now();
      
      print('[PATH_LOAD_MAP] Fetching path for ${widget.childName}, hours=$_pathHours');
      
      final apiService = ApiService();
      final locations = await apiService.getLocationHistory(
        widget.childId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        limit: 500,
      );

      if (locations.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không có dữ liệu đường đi')),
          );
        }
      }

      // Sort by timestamp ASC for path drawing
      locations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      print('[PATH_LOAD_MAP] Loaded ${locations.length} locations');

      if (mounted) {
        setState(() {
          _pathLocations = locations;
          _pathLoading = false;
        });
      }
    } catch (e) {
      print('[PATH_LOAD_MAP] Error: $e');
      if (mounted) {
        setState(() => _pathLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  /// Toggle path visualization
  void _togglePath(bool value) async {
    setState(() => _showPath = value);
    
    if (value) {
      await _loadPathData();
    } else {
      setState(() {
        _pathLocations = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.childName} - Bản Đồ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Path toggle widget
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Color(0xFFF5F7FA),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.parentPrimary.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Toggle switch row
                Row(
                  children: [
                    Icon(
                      Icons.route,
                      color: _showPath ? AppColors.parentPrimary : AppColors.textSecondary,
                      size: 20,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Hiển thị đường đi',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: _showPath,
                      onChanged: _togglePath,
                      activeColor: AppColors.parentPrimary,
                    ),
                  ],
                ),
                // Time range dropdown (only show if enabled)
                if (_showPath) ...[
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      SizedBox(width: AppSpacing.md),
                      Text(
                        'Khoảng thời gian:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.parentPrimary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: DropdownButton<int>(
                          value: _pathHours,
                          underline: SizedBox.shrink(),
                          items: [1, 2, 6, 12, 24].map((hours) {
                            return DropdownMenuItem(
                              value: hours,
                              child: Text(
                                '$hours h',
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _pathHours = value);
                              _loadPathData(); // Reload with new time range
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  // Loading/status indicator
                  if (_pathLoading)
                    Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: SizedBox(
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(AppColors.parentPrimary),
                        ),
                      ),
                    ),
                  if (!_pathLoading && _pathLocations != null && _pathLocations!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        '${_pathLocations!.length} điểm theo dõi',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          // Map
          Expanded(
            child: ChildLocationMap(
              focusedChildId: widget.childId,
              selectedLocation: widget.selectedLocation,
              previousLocation: widget.previousLocation,
              showPath: _showPath,
              pathLocations: _showPath ? _pathLocations : null,
            ),
          ),
        ],
      ),
    );
  }
}
