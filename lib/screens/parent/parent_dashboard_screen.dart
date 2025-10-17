import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/location.dart' as location_model;
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/parent/safe_zone_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../services/socket_service.dart';
import 'link_child_screen.dart';
import 'location_history_screen.dart';
import 'child_map_screen.dart';

/// Parent Dashboard Screen - Redesigned with "Purple Guardian" Design System
/// Inspired by SafeZ - Modern, Clean, High Contrast
class ParentDashboardScreen extends StatefulWidget {
  final location_model.Location? selectedLocation;
  final location_model.Location? previousLocation;

  const ParentDashboardScreen({
    Key? key,
    this.selectedLocation,
    this.previousLocation,
  }) : super(key: key);
  
  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _currentIndex = 0; // Track selected tab
  final SocketService _socketService = SocketService();
  String? _selectedChildId; // Track selected child for map focus
  
  @override
  void initState() {
    super.initState();
    _initializeSocket();
    
    // Refresh user data to load linked children
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.refreshUser();
    });
  }

  void _initializeSocket() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    
    if (userId != null) {
      _socketService.connect(userId);
      
      // Listen for link accepted event
      _socketService.onLinkAccepted = (data) {
        if (mounted) {
          final childName = data['acceptedBy']?['name'] ?? 'Trẻ em';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $childName đã chấp nhận yêu cầu liên kết!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Refresh user data to show new child
          authProvider.refreshUser();
        }
      };
    }
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    // Get linked children from real data
    final linkedChildren = authProvider.user?.linkedUsersData
        .where((u) => u['role'] == 'child')
        .toList() ?? [];
    
    // Convert to ChildAvatarData
    final children = linkedChildren.map((child) {
      return ChildAvatarData(
        id: child['_id'] ?? child['id'] ?? '',
        name: child['name'] ?? 'Trẻ',
        status: SafeZoneStatus.inSafeZone, // TODO: Get real status from location
        locationName: 'Đang cập nhật', // TODO: Get from last location
        locationIcon: '📍',
        avatarUrl: null,
      );
    }).toList();
    return Scaffold(
      // Soft UI background - inspired by SafeZ
      backgroundColor: Color(0xFFF5F7FA),
      extendBody: true, // IMPORTANT: Extend body behind navbar for see-through effect
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.parentPrimaryLight.withOpacity(0.05),
              Color(0xFFF5F7FA),
              Color(0xFFF5F7FA),
            ],
            stops: [0.0, 0.2, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false, // Don't apply safe area to bottom (navbar handles it)
          child: CustomScrollView(
            physics: BouncingScrollPhysics(), // iOS-style bounce
            slivers: [
              // Minimal header - no AppBar, just content
              SliverToBoxAdapter(
                child: _buildMinimalHeader(),
              ),
              
              // Content with generous white space
              SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(height: AppSpacing.md),
                
                  // Large personalized greeting - SafeZ style
                  _buildPersonalizedGreeting(),
                  
                  SizedBox(height: AppSpacing.lg), // Giảm: xxl → lg
                
                  // Safe Zone Avatar Row - larger, more prominent
                  _buildSafeZoneSection(children),
                  
                  SizedBox(height: AppSpacing.lg), // Spacing before screen time widget
                  
                  // 🆕 Screen Time Overview Widget
                  _buildScreenTimeWidget(children),
                  
                  SizedBox(height: AppSpacing.lg), // Giảm: xxl → lg
                  
                  // Recent Activity with soft shadows
                  _buildRecentActivitySection(),
                  
                  // Bottom padding for navbar (52px navbar + 16px extra space)
                  SizedBox(height: 70), // Giảm: 100 → 70
                ]),
              ),
            ],
          ),
        ),
      ),
      
      // Bottom Navigation Bar - iOS Liquid Glass style
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
  
  /// Bottom Navigation Bar - iOS Floating Rounded Style (giống Child)
  Widget _buildBottomNavBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 20), // Floating style
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
          child: Container(
            height: 56, // Tăng từ 52 → 56 để tránh overflow
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 4, // Tăng từ 2 → 4
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Trang chủ',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.people_alt_rounded,
                  label: 'Gia đình',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.notifications_rounded,
                  label: 'Cảnh báo',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.person_rounded,
                  label: 'Cá nhân',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// iOS-style liquid glass navigation item
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          // TODO: Navigate to different screens
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: 2), // Bỏ vertical padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with liquid animation và glass effect
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                padding: EdgeInsets.all(isActive ? 4 : 3), // Giảm: 5→4
                decoration: isActive ? BoxDecoration(
                  // Liquid glass bubble for active item
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.parentPrimary.withOpacity(0.15),
                      AppColors.parentPrimary.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  // Glass border
                  border: Border.all(
                    color: AppColors.parentPrimary.withOpacity(0.2),
                    width: 0.5,
                  ),
                  // Soft glow
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.parentPrimary.withOpacity(0.15),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ) : null,
                child: Icon(
                  icon,
                  color: isActive 
                    ? AppColors.parentPrimary
                    : AppColors.textSecondary.withOpacity(0.5),
                  size: isActive ? 22 : 20,
                ),
              ),
              SizedBox(height: 1),
              // Label text với smooth transition
              AnimatedDefaultTextStyle(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                style: GoogleFonts.poppins(
                  fontSize: isActive ? 9 : 8.5, // Giảm: 9.5→9, 9→8.5
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive 
                    ? AppColors.parentPrimary
                    : AppColors.textSecondary.withOpacity(0.5),
                  letterSpacing: 0,
                  height: 1.1,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Minimal header with just icons - SafeZ inspired
  Widget _buildMinimalHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs, // Giảm: sm → xs
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App name with bold typography
          Text(
            'SafeKids',
            style: AppTypography.h3.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              // Notification icon with soft background
              _buildSoftIconButton(
                icon: Icons.notifications_outlined,
                onTap: () {
                  // TODO: Notifications
                },
              ),
              SizedBox(width: AppSpacing.sm),
              // Logout button
              _buildSoftIconButton(
                icon: Icons.logout_rounded,
                onTap: () {
                  _showLogoutDialog();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Soft icon button with neumorphic feel
  Widget _buildSoftIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(0xFFF5F7FA),
          shape: BoxShape.circle,
          boxShadow: [
            // Soft outer shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: Offset(4, 4),
              blurRadius: 8,
            ),
            // Soft inner highlight
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              offset: Offset(-2, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
  
  /// Large personalized greeting - SafeZ "Hi, George!" style
  Widget _buildPersonalizedGreeting() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // Large greeting text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dynamic greeting with emoji
                Row(
                  children: [
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        fontSize: 28, // Giảm: 32 → 28
                        fontWeight: FontWeight.w300,
                        color: AppColors.textSecondary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2), // Giảm: 4 → 2
                // User name - BOLD like SafeZ
                Text(
                  'Hdi!',
                  style: TextStyle(
                    fontSize: 32, // Giảm: 36 → 32
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          // User avatar - large and circular like SafeZ
          Container(
            width: 52, // Giảm: 60 → 52
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.parentPrimary,
                  AppColors.parentPrimaryLight,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.parentPrimary.withOpacity(0.3),
                  blurRadius: 10, // Giảm: 12 → 10
                  offset: Offset(0, 3), // Giảm: 4 → 3
                ),
              ],
            ),
            child: Center(
              child: Text(
                'H',
                style: TextStyle(
                  fontSize: 22, // Giảm: 24 → 22
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Get time-based greeting text
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Chào buổi sáng';
    if (hour >= 12 && hour < 18) return 'Chào buổi chiều';
    if (hour >= 18 && hour < 22) return 'Chào buổi tối';
    return 'Chúc ngủ ngon';
  }
  
  /// Safe Zone Avatar Row Section with Soft UI (SafeZ-inspired)
  Widget _buildSafeZoneSection(List<ChildAvatarData> children) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // Soft neumorphic shadow - outer
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: Offset(6, 6),
            blurRadius: 16,
          ),
          // Soft highlight - inner
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            offset: Offset(-4, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gia đình',
                style: AppTypography.h3.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              // Soft badge
              if (children.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '${_getSafeChildrenCount(children)}/${children.length} an toàn',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          // Instagram-style avatar row or empty state
          children.isEmpty
              ? _buildEmptyChildrenState()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // "Tất cả" button
                    if (_selectedChildId != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedChildId = null; // Show all
                            });
                          },
                          icon: Icon(Icons.grid_view_rounded, size: 16),
                          label: Text('Xem tất cả'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.parentPrimary,
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ),
                    SafeZoneAvatarRow(
                      children: children,
                      onAvatarTap: (childId) {
                        // Focus map on selected child
                        setState(() {
                          _selectedChildId = childId;
                        });
                        debugPrint('[Dashboard] Selected child for map: $childId');
                        // Also show detail
                        _showChildDetail(childId, children);
                      },
                      onAddChildTap: () {
                        _showAddChildDialog();
                      },
                    ),
                  ],
                ),
        ],
      ),
    );
  }
  
  /// Empty state when no children linked
  Widget _buildEmptyChildrenState() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Chưa có thành viên nào',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Thêm trẻ em để bắt đầu theo dõi',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: _showAddChildDialog,
              icon: Icon(Icons.add, size: 20),
              label: Text('Thêm thành viên'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.parentPrimary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Screen Time Overview Widget - Compact Summary with Progress Bars
  Widget _buildScreenTimeWidget(List<ChildAvatarData> children) {
    // Return empty if no children
    if (children.isEmpty) {
      return SizedBox.shrink();
    }
    
    // ⚠️ MOCKUP DATA - Screen time feature chưa implement
    // TODO Story 3.x: Integrate real screen time data from API
    // - GET /api/screentime/usage/:childId
    // - Real-time tracking from child device
    final screenTimeData = children.map((child) {
      return {
        'name': child.name,
        'used': 0.0, // MOCKUP: Thời gian đã dùng (giờ)
        'limit': 3.0, // MOCKUP: Giới hạn (giờ)
        'status': 'ok', // MOCKUP: ok | warning | exceeded
      };
    }).toList();
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: Offset(4, 4),
            blurRadius: 12,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            offset: Offset(-3, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    color: AppColors.parentPrimary,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Thời gian sử dụng hôm nay',
                    style: AppTypography.h3.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  // TODO: Navigate to detailed screen time view
                },
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.parentPrimary,
                  size: 18,
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppSpacing.md),
          
          // Progress bars for each child
          ...screenTimeData.map((child) => _buildScreenTimeProgressItem(
            name: child['name'] as String,
            used: child['used'] as double,
            limit: child['limit'] as double,
            status: child['status'] as String,
          )),
        ],
      ),
    );
  }
  
  /// Individual screen time progress item
  Widget _buildScreenTimeProgressItem({
    required String name,
    required double used,
    required double limit,
    required String status,
  }) {
    final percentage = (used / limit).clamp(0.0, 1.0);
    final isOverLimit = used >= limit;
    final isNearLimit = used >= limit * 0.8 && used < limit;
    
    Color getStatusColor() {
      if (isOverLimit) return AppColors.danger;
      if (isNearLimit) return AppColors.warning;
      return AppColors.success;
    }
    
    IconData getStatusIcon() {
      if (isOverLimit) return Icons.error_outline_rounded;
      if (isNearLimit) return Icons.access_time_rounded;
      return Icons.check_circle_outline_rounded;
    }
    
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name, time, status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${used.toStringAsFixed(1)}h/${limit.toStringAsFixed(1)}h',
                    style: AppTypography.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 8),
                  // Status icon only
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: getStatusColor().withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: getStatusColor().withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      getStatusIcon(),
                      size: 16,
                      color: getStatusColor(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: 6),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        getStatusColor(),
                        getStatusColor().withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: getStatusColor().withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Recent Activity Section with Soft UI
  Widget _buildRecentActivitySection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(20), // Giảm: 24 → 20
        boxShadow: [
          // Soft neumorphic shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: Offset(4, 4), // Giảm: 6,6 → 4,4
            blurRadius: 12, // Giảm: 16 → 12
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            offset: Offset(-3, -3), // Giảm: -4,-4 → -3,-3
            blurRadius: 10, // Giảm: 12 → 10
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSpacing.xs), // Giảm: sm → xs
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hoạt động gần đây',
                  style: AppTypography.h3.copyWith(
                    fontSize: 18, // Giảm: 20 → 18
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // TODO: View all activity
                  },
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.parentPrimary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          _buildActivityItem(
            icon: Icons.exit_to_app,
            iconColor: AppColors.warning,
            title: 'Lisa rời Trường học',
            time: '15:30',
          ),
          Divider(
            height: 20,
            indent: 56,
            endIndent: 8,
            color: AppColors.divider.withOpacity(0.3),
          ),
          _buildActivityItem(
            icon: Icons.home,
            iconColor: AppColors.success,
            title: 'Max đã về đến Nhà',
            time: '15:45',
          ),
          Divider(
            height: 20,
            indent: 56,
            endIndent: 8,
            color: AppColors.divider.withOpacity(0.3),
          ),
          _buildActivityItem(
            icon: Icons.phone_android,
            iconColor: AppColors.info,
            title: 'Anna đã xem YouTube 45 phút',
            time: '14:20',
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          // Circular icon with soft shadow - SafeZ style
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  time,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Minimal chevron
          Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary.withOpacity(0.5),
            size: 20,
          ),
        ],
      ),
    );
  }
  
  int _getSafeChildrenCount(List<ChildAvatarData> children) {
    return children.where((c) => c.status == SafeZoneStatus.inSafeZone).length;
  }
  
  /* REMOVED: Unused dialogs - will implement in future stories
  /// Show Adjust Screen Time Limits Dialog
  void _showAdjustLimitsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust Screen Time Limits'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set daily screen time limits for each child:'),
            SizedBox(height: 16),
            ..._children.map((child) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.parentPrimaryLight,
                child: Text(child.name[0]),
              ),
              title: Text(child.name),
              trailing: Text('3h', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                // TODO: Show time picker for individual child
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Save limits
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Screen time limits updated!')),
              );
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
  
  /// Show Bedtime Mode Dialog
  void _showBedtimeModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bedtime, color: AppColors.parentPrimary),
            SizedBox(width: 8),
            Text('Bedtime Mode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enable bedtime mode to automatically restrict phone usage during sleep hours.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            Text('Default Schedule:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.nightlight, size: 20, color: AppColors.parentPrimary),
                SizedBox(width: 8),
                Text('9:00 PM - 6:30 AM'),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'All children will have limited access to their devices during this time.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Enable bedtime mode
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.bedtime, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Text('Bedtime mode enabled!'),
                    ],
                  ),
                  backgroundColor: AppColors.parentPrimary,
                ),
              );
            },
            icon: Icon(Icons.check, size: 18),
            label: Text('Enable'),
          ),
        ],
      ),
    );
  }
  */ // END OF REMOVED DIALOGS
  
  /// Build individual child stat card (for child detail sheet) with Liquid Glass
  Widget _buildChildStatCard({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required Color color,
    double? percentage,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.35),
                Colors.white.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with gradient background
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.25),
                  color.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          
          SizedBox(height: AppSpacing.sm),
          
          // Value
          Text(
            value,
            style: AppTypography.h2.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary.withOpacity(0.95),
            ),
          ),
          
          SizedBox(height: 2),
          
          // Label + subtitle
          Row(
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(width: 4),
                Text(
                  subtitle,
                  style: AppTypography.captionSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          
          // Progress bar (if percentage provided)
          if (percentage != null) ...[
            SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }
  
  void _showChildDetail(String childId, List<ChildAvatarData> children) {
    // Navigate to child map screen with path toggle (Task 2.4)
    final child = children.firstWhere(
      (c) => c.id == childId,
      orElse: () => ChildAvatarData(
        id: childId,
        name: 'Trẻ em',
        status: SafeZoneStatus.inSafeZone,
        locationName: '',
        locationIcon: '📍',
        avatarUrl: null,
      ),
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildMapScreen(
          childId: childId,
          childName: child.name,
        ),
      ),
    );
  }
  
  Widget _buildChildDetailSheet(String childId, List<ChildAvatarData> children) {
    final child = children.firstWhere(
      (c) => c.id == childId,
      orElse: () => children.first,
    );
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.arrow_back, color: AppColors.textPrimary),
                SizedBox(width: AppSpacing.md),
                Text(
                  child.name,
                  style: AppTypography.h3,
                ),
                Spacer(),
                Icon(Icons.settings, color: AppColors.textSecondary),
              ],
            ),
          ),
          
          // Status badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: child.status == SafeZoneStatus.inSafeZone
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  child.status == SafeZoneStatus.inSafeZone
                      ? Icons.check_circle
                      : Icons.location_on,
                  color: child.status == SafeZoneStatus.inSafeZone
                      ? AppColors.success
                      : AppColors.warning,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  child.status == SafeZoneStatus.inSafeZone
                      ? 'At ${child.locationName} - Safe Zone'
                      : 'Outside Safe Zones',
                  style: AppTypography.caption.copyWith(
                    color: child.status == SafeZoneStatus.inSafeZone
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          // Individual Child Stats Cards
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _buildChildStatCard(
                    icon: Icons.access_time,
                    label: 'Screen Time',
                    value: '2h 15m',
                    subtitle: 'today',
                    color: AppColors.parentPrimary,
                    percentage: 0.55, // 55% of daily limit
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildChildStatCard(
                    icon: Icons.battery_charging_full,
                    label: 'Battery',
                    value: '85%',
                    subtitle: 'remaining',
                    color: AppColors.success,
                    percentage: 0.85,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          // 🗺️ Empty map area (click child avatar to view detailed map with path controls)
          Expanded(
            child: Container(
              color: Color(0xFFF5F7FA),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.3),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Bấm vào child để xem bản đồ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: AppSpacing.lg),
          
          // Action buttons
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.phone),
                        label: Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.parentPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.navigation),
                        label: Text('Navigate'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationHistoryScreen(
                          childId: childId,
                          childName: child.name,
                        ),
                      ),
                    ),
                    icon: Icon(Icons.history),
                    label: Text('Lịch Sử Vị Trí'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showAddChildDialog() async {
    // Navigate to LinkChildScreen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LinkChildScreen(),
      ),
    );
    
    // Refresh data if link request was sent successfully
    if (result == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshUser();
    }
  }
  
  /// Show logout confirmation dialog
  void _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đăng xuất'),
        content: Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            child: Text('Đăng xuất'),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      // Navigation will be handled by AuthProvider
    }
  }
}
