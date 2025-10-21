import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/parent/screentime_suggestions_widget.dart';
import 'edit_screentime_limit_screen.dart';

class ScreenTimeSettingsScreen extends StatefulWidget {
  @override
  _ScreenTimeSettingsScreenState createState() => _ScreenTimeSettingsScreenState();
}

class _ScreenTimeSettingsScreenState extends State<ScreenTimeSettingsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _children = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      // Load children from user profile API
      final profile = await ApiService().getProfile();
      final linkedUsers = profile['linkedUsers'] as List?;
      
      final children = linkedUsers != null 
          ? linkedUsers
              .whereType<Map<String, dynamic>>()
              .where((u) => u['role'] == 'child')
              .toList()
          : [];

      setState(() {
        _children = List<Map<String, dynamic>>.from(children);
        _loading = false;
      });

      // Load config and suggestions for each child
      for (int i = 0; i < _children.length; i++) {
        try {
          final childId = _children[i]['_id'] as String;
          
          // Load screen time config
          final config = await ApiService().getScreenTimeConfig(childId);
          _children[i]['config'] = config;
          
          // Load suggestions
          final suggestions = await ApiService().getScreenTimeSuggestions(childId);
          _children[i]['suggestions'] = suggestions;
          
          setState(() {
            _children = [..._children]; // Trigger rebuild
          });
        } catch (e) {
          print('Failed to load data for ${_children[i]['name']}: $e');
          // Continue without full data
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Không thể tải dữ liệu: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _onApplySuggestion() async {
    // Refresh children data when suggestion applied
    await _loadChildren();
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.childPrimary.withOpacity(0.1),
                  child: Icon(Icons.child_care, color: AppColors.childPrimary, size: 30),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child['name'],
                        style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                      ),
                      SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${child['age']} tuổi',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: AppColors.textLight, size: 16),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildQuickButton(
                    icon: Icons.access_time,
                    label: 'Giới hạn',
                    color: AppColors.parentPrimary,
                    onTap: () => _showLimitDialog(child),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildQuickButton(
                    icon: Icons.nightlight_round,
                    label: 'Giờ ngủ',
                    color: AppColors.parentAccent,
                    onTap: () => _showBedtimeDialog(child),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildQuickButton(
                    icon: Icons.analytics,
                    label: 'Báo cáo',
                    color: AppColors.success,
                    onTap: () => _showReportsDialog(child),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: AppSpacing.iconSm),
            SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.caption.copyWith(color: color).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLimitDialog(Map<String, dynamic> child) async {
    // Navigate to edit screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditScreenTimeLimitScreen(child: child),
      ),
    );

    // Reload if config was saved
    if (result == true) {
      _loadChildren();
    }
  }

  Future<void> _showBedtimeDialog(Map<String, dynamic> child) async {
    // Navigate to edit screen (same as limit, just opens with bedtime section visible)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditScreenTimeLimitScreen(child: child),
      ),
    );

    // Reload if config was saved
    if (result == true) {
      _loadChildren();
    }
  }

  Future<void> _showReportsDialog(Map<String, dynamic> child) async {
    // Implementation for showing reports
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Báo cáo sử dụng'),
        content: Text('Tính năng đang được phát triển'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Thời gian sử dụng'),
        backgroundColor: AppColors.parentPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.parentPrimary),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    'Đang tải dữ liệu...',
                    style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: AppSpacing.iconXl,
                        color: AppColors.danger,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _loadChildren,
                        icon: Icon(Icons.refresh),
                        label: Text('Thử lại'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.parentPrimary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _children.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: AppSpacing.iconXl,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: AppSpacing.md),
                          Text(
                            'Chưa có con nào được liên kết',
                            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadChildren,
                      color: AppColors.parentPrimary,
                      child: ListView.builder(
                        padding: EdgeInsets.all(AppSpacing.md),
                        itemCount: _children.length,
                        itemBuilder: (context, index) {
                          final child = _children[index];
                          
                          return Column(
                            children: [
                              // Suggestions widget
                              if (child['suggestions'] != null)
                                ScreenTimeSuggestionsWidget(
                                  childId: child['_id'],
                                  suggestions: child['suggestions'],
                                  onApplySuggestion: _onApplySuggestion,
                                ),
                              
                              SizedBox(height: AppSpacing.md),
                              
                              // Existing child card
                              _buildChildCard(child),
                              
                              SizedBox(height: AppSpacing.lg),
                            ],
                          );
                        },
                      ),
                    ),
    );
  }
}
