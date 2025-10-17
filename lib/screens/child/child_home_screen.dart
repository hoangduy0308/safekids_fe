import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/socket_service.dart';
import '../../widgets/child/location_permission_dialog.dart';
import '../../widgets/child/link_request_dialog.dart';
import '../../widgets/common/offline_indicator.dart';
import './location_settings_screen.dart';
import '../../services/battery_service.dart';
import '../../widgets/battery_optimization_guide.dart';

/// Child Home Screen - Redesigned with "Misty Morning" Teal Theme
/// iOS-style liquid glass UI with neumorphic shadows
class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({Key? key}) : super(key: key);

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0; // Track selected tab in navbar
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final _locationService = LocationService();
  final _socketService = SocketService();
  final Set<String> _processedRequests = {}; // Track processed link request IDs

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    _animationController.forward();
    _initLocationTracking();
    _initSocketConnection();
  }

  Future<void> _initLocationTracking() async {
    await _locationService.initialize();
    
    // Task 2.5.8: Load location settings on startup
    await _loadLocationSettings();

    // Task 2.6.2: Start battery monitoring
    final batteryService = BatteryService();
    await batteryService.startMonitoring();

    // Task 2.6.4: Show battery optimization guide on first launch
    if (mounted) {
      BatteryOptimizationGuide.showGuideIfNeeded(context);
    }
    
    final hasPermission = await _locationService.checkAndRequestPermissions();
    if (!hasPermission && mounted) {
      showDialog(
        context: context,
        builder: (_) => LocationPermissionDialog(
          onGranted: () => _locationService.startTracking(),
        ),
      );
    } else {
      _locationService.startTracking();
    }
    
    // Listen for GPS status changes
    _locationService.addListener(_onLocationServiceChange);
  }

  /// Load location settings from SharedPreferences (Task 2.5.8)
  Future<void> _loadLocationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sharingEnabled = prefs.getBool('sharingEnabled') ?? true;
      final trackingInterval = prefs.getString('trackingInterval') ?? 'continuous';
      final pausedStr = prefs.getString('pausedUntil');
      final pausedUntil = pausedStr != null ? DateTime.parse(pausedStr) : null;

      debugPrint('[ChildHome] Loaded settings: sharing=$sharingEnabled, interval=$trackingInterval, paused=$pausedUntil');

      // If sharing disabled or paused, don't start tracking
      if (!sharingEnabled) {
        debugPrint('[ChildHome] Location sharing disabled - tracking not started');
        return;
      }

      if (pausedUntil != null && pausedUntil.isAfter(DateTime.now())) {
        debugPrint('[ChildHome] Location tracking paused until $pausedUntil - tracking not started');
        return;
      }

      // Apply tracking interval
      await _locationService.updateInterval(trackingInterval);
      debugPrint('[ChildHome] Applied tracking interval: $trackingInterval');
    } catch (e) {
      debugPrint('[ChildHome] Error loading location settings: $e');
    }
  }

  void _onLocationServiceChange() {
    // This will be called when tracking state changes
    // Could show notifications/dialogs here if needed
  }

  void _initSocketConnection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    
    if (userId != null) {
      _socketService.connect(userId);
      
      // Listen for link requests
      _socketService.onLinkRequest = (data) {
        final requestId = data['requestId'] ?? '';
        
        // Ignore if already processed
        if (_processedRequests.contains(requestId)) {
          debugPrint('[LinkRequest] Already processed: $requestId');
          return;
        }
        
        if (mounted) {
          // Mark as processed immediately
          _processedRequests.add(requestId);
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => LinkRequestDialog(
              requestId: requestId,
              senderName: data['sender']?['name'] ?? '',
              senderEmail: data['sender']?['email'] ?? '',
              senderRole: data['sender']?['role'] ?? '',
              message: data['message'],
            ),
          ).then((accepted) {
            if (accepted == true) {
              authProvider.refreshUser();
            }
          });
        }
      };

      // Listen for link removed
      _socketService.onLinkRemoved = (data) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${data['parentName']} đã xóa liên kết với bạn'),
              backgroundColor: Colors.orange,
            ),
          );
          authProvider.refreshUser();
        }
      };
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _locationService.removeListener(_onLocationServiceChange);
    _socketService.disconnect();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'Chào buổi sáng';
    if (hour >= 11 && hour < 13) return 'Chào buổi trưa';
    if (hour >= 13 && hour < 17) return 'Chào buổi chiều';
    if (hour >= 17 && hour < 21) return 'Chào buổi tối';
    return 'Chúc ngủ ngon';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.user?.name ?? 'Bạn';
    
    return Scaffold(
      // Soft UI background - Teal theme
      backgroundColor: Color(0xFFF5F7FA),
      extendBody: true, // IMPORTANT: Extend body behind navbar for see-through effect
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.childPrimary.withOpacity(0.05),
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
              // Simple header with app name and icons
              SliverToBoxAdapter(
                child: _buildMinimalHeader(authProvider),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              
              // Personalized Greeting
              SliverToBoxAdapter(
                child: _buildPersonalizedGreeting(userName),
              ),
              
              // Offline Indicator (appears when no network or queued locations)
              SliverToBoxAdapter(
                child: ChangeNotifierProvider<LocationService>.value(
                  value: _locationService,
                  child: const OfflineIndicator(),
                ),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              
              // SOS Card
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildSOSCard(context),
                  ),
                ),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              
              // Screen Time Widget
              SliverToBoxAdapter(
                child: _buildScreenTimeWidget(),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              
              // Activity Cards Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    'Hoạt động của bạn',
                    style: AppTypography.h3.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
              
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildActivityGrid(context),
                ),
              ),
              
              SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding for navbar
            ],
          ),
        ),
      ),
      
      // iOS Liquid Glass Bottom Navigation Bar
      bottomNavigationBar: _buildLiquidGlassNavBar(),
    );
  }

  /// Minimal header with app name and icons (giống Parent)
  Widget _buildMinimalHeader(AuthProvider authProvider) {
    final linkedParents = authProvider.user?.linkedUsersData
        .where((u) => u['role'] == 'parent')
        .toList() ?? [];
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
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
              // Linked parents badge
              if (linkedParents.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.childPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.childPrimary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.family_restroom,
                        color: AppColors.childPrimary,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${linkedParents.length}',
                        style: TextStyle(
                          color: AppColors.childPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(width: AppSpacing.sm),
              // Settings button (Task 2.5)
              _buildSoftIconButton(
                icon: Icons.settings,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LocationSettingsScreen(),
                    ),
                  );
                },
              ),
              SizedBox(width: AppSpacing.sm),
              // Logout button
              _buildSoftIconButton(
                icon: Icons.logout_rounded,
                onTap: () {
                  _showLogoutDialog(context, authProvider);
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
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: Offset(4, 4),
              blurRadius: 8,
            ),
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

  /// iOS-style liquid glass bottom navigation bar
  Widget _buildLiquidGlassNavBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 20),
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
                  icon: Icons.access_time_rounded,
                  label: 'Thời gian',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.notifications_rounded,
                  label: 'Thông báo',
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
              // Icon with liquid animation
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                padding: EdgeInsets.all(isActive ? 4 : 3), // Giảm: 5→4
                decoration: isActive ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.childPrimary.withOpacity(0.15),
                      AppColors.childPrimary.withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.childPrimary.withOpacity(0.2),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.childPrimary.withOpacity(0.15),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ) : null,
                child: Icon(
                  icon,
                  color: isActive 
                    ? AppColors.childPrimary
                    : AppColors.textSecondary.withOpacity(0.5),
                  size: isActive ? 22 : 20,
                ),
              ),
              SizedBox(height: 1),
              // Label text
              AnimatedDefaultTextStyle(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                style: TextStyle(
                  fontSize: isActive ? 9 : 8.5, // Giảm: 10→9, 9→8.5
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive 
                    ? AppColors.childPrimary
                    : AppColors.textSecondary.withOpacity(0.5),
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

  
  /// Large personalized greeting
  Widget _buildPersonalizedGreeting(String userName) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: _getGreeting(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
                letterSpacing: -0.5,
                fontFamily: 'Poppins',
              ),
            ),
            TextSpan(
              text: ', ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
            TextSpan(
              text: userName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Screen Time Widget for Child
  Widget _buildScreenTimeWidget() {
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
                    color: AppColors.childPrimary,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Thời gian hôm nay',
                    style: AppTypography.h3.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: AppSpacing.md),
          
          // Time display
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '2.3',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: AppColors.childPrimary,
                  height: 1,
                ),
              ),
              SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'giờ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Giới hạn: 3.0 giờ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Còn lại: 0.7 giờ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          SizedBox(height: AppSpacing.md),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.77,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.childPrimary,
                        AppColors.childPrimary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.childPrimary.withOpacity(0.3),
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

  Widget _buildSOSCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      height: 140, // Tăng chiều cao để nổi bật hơn
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF5252), // Đỏ sáng hơn
            Color(0xFFE91E63), // Hồng đỏ
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withOpacity(0.4),
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.danger.withOpacity(0.2),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSOSPress(context),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Icon SOS lớn với animation pulse
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.emergency,
                    color: Color(0xFFFF5252),
                    size: 44,
                  ),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'KHẨN CẤP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Nút SOS',
                        style: AppTypography.h2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Nhấn để gửi cảnh báo ngay',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityGrid(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          _buildActivityCard(
            Icons.access_time_rounded,
            'Thời gian sử dụng',
            'Xem thời gian bạn đã dùng thiết bị',
            AppColors.childAccent,
          ),
          SizedBox(height: AppSpacing.md),
          _buildActivityCard(
            Icons.chat_bubble_rounded,
            'Tin nhắn',
            'Chat với ba mẹ và gia đình',
            AppColors.childPrimary,
          ),
          SizedBox(height: AppSpacing.md),
          _buildActivityCard(
            Icons.assignment_rounded,
            'Nhiệm vụ',
            'Hoàn thành nhiệm vụ hàng ngày',
            AppColors.info,
          ),
          SizedBox(height: AppSpacing.md),
          _buildActivityCard(
            Icons.stars_rounded,
            'Phần thưởng',
            'Nhận thưởng khi hoàn thành tốt',
            AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(IconData icon, String title, String description, Color color) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Sắp có',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSOSPress(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🆘 Tính năng SOS đang được phát triển'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) async {
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
            child: Text('Đăng xuất', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true) {
      await authProvider.logout();
    }
  }
}
