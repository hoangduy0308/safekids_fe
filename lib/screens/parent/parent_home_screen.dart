import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'dart:ui';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/parent/notification_badge.dart';
import '../../widgets/parent/notification_panel.dart';
import '../../models/child_detail_data.dart';
import '../../services/api_service.dart';
import '../../services/geocode_service.dart';
import 'link_child_screen.dart';
import 'child_map_screen.dart';
import '../../models/location.dart' as location_model;

// Member Card with Micro-Interactions
class MemberCardWithInteraction extends StatefulWidget {
  final String name;
  final Color color;
  final Color bgColor;
  final String statusText;
  final VoidCallback onTap;

  const MemberCardWithInteraction({
    Key? key,
    required this.name,
    required this.color,
    required this.bgColor,
    required this.statusText,
    required this.onTap,
  }) : super(key: key);

  @override
  State<MemberCardWithInteraction> createState() => _MemberCardWithInteractionState();
}

class _MemberCardWithInteractionState extends State<MemberCardWithInteraction> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(duration: Duration(milliseconds: 300), vsync: this);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovering) {
    setState(() => _isHovering = isHovering);
    if (isHovering) {
      _scaleController.forward();
    } else {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap();
        _scaleController.forward().then((_) => _scaleController.reverse());
      },
      child: MouseRegion(
        onEnter: (_) => _onHover(true),
        onExit: (_) => _onHover(false),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.08).animate(
            CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: widget.bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(_isHovering ? 0.5 : 0.2),
                          blurRadius: _isHovering ? 16 : 8,
                          spreadRadius: _isHovering ? 3 : 1,
                          offset: Offset(0, _isHovering ? 4 : 2),
                        ),
                        BoxShadow(
                          color: widget.color.withOpacity(_isHovering ? 0.2 : 0.05),
                          blurRadius: _isHovering ? 24 : 12,
                          spreadRadius: _isHovering ? 6 : 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '👧',
                        style: AppTypography.display2.copyWith(color: widget.color),
                      ),
                    ),
                  ),
                  // Status indicator dot
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(widget.name, style: AppTypography.label),
              Container(
                margin: EdgeInsets.only(top: 4),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: widget.color.withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  widget.statusText,
                  style: AppTypography.captionSmall.copyWith(
                    color: widget.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({Key? key}) : super(key: key);

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _recentStatuses = [];
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late ConfettiController _confettiController;
  bool _showNotificationPanel = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadRecentStatuses();
    // Load notifications on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).loadNotifications();
    });
  }

  void _setupAnimations() {
    _fadeController = AnimationController(duration: Duration(milliseconds: 600), vsync: this);
    _slideController = AnimationController(duration: Duration(milliseconds: 800), vsync: this);
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentStatuses() async {
    try {
      final apiService = ApiService();
      final alertData = await apiService.getGeofenceAlerts(limit: 5);
      final alerts = (alertData['alerts'] as List);

      if (mounted) {
        setState(() {
          _recentStatuses = alerts.map((alert) {
            final isUnsafe = alert['type'] == 'exit';
            return {
              'name': alert['child']?['name'] ?? 'Một trẻ',
              'action': isUnsafe ? 'đã rời khỏi vùng an toàn' : 'đã vào vùng an toàn',
              'time': alert['timestamp'] ?? '',
              'icon': isUnsafe ? Icons.location_off : Icons.location_on,
              'color': isUnsafe ? AppColors.danger : AppColors.success,
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading statuses: $e');
      if (mounted) {
        // Optionally show an error message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải hoạt động gần đây')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.user?.name ?? 'Hdi';
    final linkedChildren = authProvider.user?.linkedUsersData
        .where((u) => u['role'] == 'child')
        .toList() ?? [];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadRecentStatuses,
            color: AppColors.parentPrimary,
            child: SafeArea(
              child: CustomScrollView(
            slivers: [
            // Header with Glassmorphism
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              expandedHeight: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Colors.transparent,
                ),
              ),
              title: _buildHeaderWithGlass(userName),
              centerTitle: false,
              toolbarHeight: 70,
            ),
            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Members Section
                    _buildMembersSection(linkedChildren),
                    SizedBox(height: AppSpacing.xl),
                    // Recent Status Section
                    _buildRecentStatusSection(),
                  ],
                ),
              ),
            ),
            ],
              ),
            ),
          ),
          // Notification Panel - Positioned below AppBar
          if (_showNotificationPanel)
            Consumer<NotificationProvider>(
              builder: (context, notificationProvider, _) {
                return Positioned(
                  top: AppBar().preferredSize.height + MediaQuery.of(context).padding.top + AppSpacing.md,
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: NotificationPanel(
                    notificationProvider: notificationProvider,
                    onClose: () {
                      setState(() => _showNotificationPanel = false);
                    },
                  ),
                );
              },
            ),
          // Confetti Effect
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: [
                AppColors.parentPrimary, // 40% Purple
                AppColors.parentPrimary,
                AppColors.parentPrimary,
                AppColors.parentPrimary,
                AppColors.success,       // 30% Green
                AppColors.success,
                AppColors.success,
                AppColors.info,          // 20% Blue
                AppColors.info,
                AppColors.warning,       // 10% Orange
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreetingPart() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Chào buổi sáng, ';
    } else if (hour >= 12 && hour < 17) {
      return 'Chào buổi chiều, ';
    } else if (hour >= 17 && hour < 21) {
      return 'Chào buổi tối, ';
    } else {
      return 'Chào bạn, ';
    }
  }

  Widget _buildHeaderWithGlass(String userName) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.8),
                border: Border.all(
                  color: AppColors.parentPrimary.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor.withOpacity(0.1),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppColors.parentPrimary.withOpacity(0.05),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: AppTypography.h2,
                            children: <TextSpan>[
                              TextSpan(
                                text: _getGreetingPart(),
                                style: const TextStyle(fontWeight: FontWeight.w300),
                              ),
                              TextSpan(
                                text: userName,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        if (notificationProvider.unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Bạn có ${notificationProvider.unreadCount} thông báo mới',
                            style: AppTypography.caption.copyWith(color: AppColors.info, fontWeight: FontWeight.w600),
                          ),
                        ]
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.lg),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _showNotificationPanel = !_showNotificationPanel);
                      if (_showNotificationPanel && notificationProvider.notifications.isEmpty) {
                        notificationProvider.loadNotifications();
                      }
                    },
                    child: Stack(
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.parentPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            size: 28,
                            color: notificationProvider.unreadCount > 0
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                        ),
                        Positioned(
                          top: -2,
                          right: -2,
                          child: NotificationBadge(
                            count: notificationProvider.unreadCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersSection(List<Map<String, dynamic>> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trẻ em của bạn',
          style: AppTypography.h3,
        ),
        SizedBox(height: AppSpacing.lg),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...children.asMap().entries.map((entry) {
                final child = entry.value;
                final isSafe = true; // TODO: Get from real data
                return Padding(
                  padding: EdgeInsets.only(right: AppSpacing.lg),
                  child: _buildMemberCard(
                    childId: child['_id'] ?? child['id'] ?? '',
                    name: child['name'] ?? 'Trẻ',
                    isSafe: isSafe,
                  ),
                );
              }),
              // Add Member Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LinkChildScreen()));
                },
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppColors.parentPrimary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.parentPrimary.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.parentPrimary.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(Icons.add, size: 32, color: AppColors.parentPrimary),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text('Thêm', style: AppTypography.label.copyWith(
                      color: AppColors.parentPrimary,
                      fontWeight: FontWeight.w600,
                    )),
                    Text('thành viên', style: AppTypography.captionSmall.copyWith(
                      color: AppColors.parentPrimary.withOpacity(0.7),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard({
    required String childId,
    required String name,
    required bool isSafe,
  }) {
    final color = isSafe ? AppColors.success : AppColors.danger;
    final bgColor = isSafe ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1);
    final statusText = isSafe ? 'An toàn' : 'Không an toàn';

    return MemberCardWithInteraction(
      name: name,
      color: color,
      bgColor: bgColor,
      statusText: statusText,
      onTap: () {
        HapticFeedback.mediumImpact();
        _showChildMapScreen(childId, name, isSafe);
      },
    );
  }

  void _showChildMapScreen(String childId, String childName, bool isSafe) async {
    final apiService = ApiService();
    
    // Show a simple loading indicator while fetching data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch real data from API
      late Map<String, dynamic> locationData;
      late List<Map<String, dynamic>> screenTimeData;
      
      try {
        locationData = await apiService.getChildLatestLocation(childId);
        debugPrint('[ChildDetail] Location API Response: $locationData');
      } catch (locErr) {
        debugPrint('[ChildDetail] Location API error: $locErr - Using fallback');
        locationData = {'data': null}; // Fallback
      }

      try {
        screenTimeData = await apiService.getScreenTimeUsageHistory(
          childId: childId,
          startDate: DateTime.now().toIso8601String(),
          endDate: DateTime.now().toIso8601String(),
        );
      } catch (stErr) {
        debugPrint('[ChildDetail] Screen time API error: $stErr - Using fallback');
        screenTimeData = []; // Fallback
      }

      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);

      // Parse location data from API response
      final location = locationData['data']?['location'];
      final batteryLevel = (location?['batteryLevel'] ?? location?['battery'] ?? 75) as int;
      
      // Get coordinates for reverse geocoding
      final latitude = (location?['latitude'] as num?)?.toDouble();
      final longitude = (location?['longitude'] as num?)?.toDouble();
      
      // Reverse geocode: convert lat/long to address using OpenStreetMap Nominatim
      String address = 'Không xác định';
      if (latitude != null && longitude != null) {
        debugPrint('[ChildDetail] Reverse geocoding: $latitude, $longitude');
        address = await GeocodeService.getAddress(latitude, longitude);
      }
      
      final updatedAt = (location?['timestamp'] ?? locationData['data']?['timestamp']) as String?;
      
      // inSafeZone: default from member card status
      final inSafeZone = isSafe;

      // Format last seen
      String lastSeen = 'Chưa cập nhật';
      if (updatedAt != null) {
        try {
          final lastTime = DateTime.parse(updatedAt);
          final diff = DateTime.now().difference(lastTime);
          if (diff.inMinutes < 1) {
            lastSeen = 'Vừa xong';
          } else if (diff.inMinutes < 60) {
            lastSeen = '${diff.inMinutes} phút trước';
          } else if (diff.inHours < 24) {
            lastSeen = '${diff.inHours} giờ trước';
          } else {
            lastSeen = '${diff.inDays} ngày trước';
          }
        } catch (_) {}
      }

      // Calculate screen time from list
      int screenTimeMinutes = 0;
      if (screenTimeData.isNotEmpty) {
        for (var item in screenTimeData) {
          screenTimeMinutes += (item['totalMinutes'] ?? 0) as int;
        }
      }

      final childDetail = ChildDetailData(
        childId: childId,
        name: childName,
        batteryLevel: batteryLevel,
        lastSeen: lastSeen,
        locationName: address,
        isInSafeZone: inSafeZone,
        screenTimeMinutes: screenTimeMinutes,
        screenTimeLimit: 240,
        selectedLocation: location != null ? location_model.Location.fromJson(location) : null,
      );

      // Navigate to the new map screen with the detail panel
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChildMapScreen(
              childId: childId,
              childName: childName,
              childDetail: childDetail,
              selectedLocation: childDetail.selectedLocation,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ChildDetail] Error loading data: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  Widget _buildRecentStatusSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: AppColors.parentPrimary.withOpacity(0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withOpacity(0.08),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.parentPrimary.withOpacity(0.03),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _fadeController,
                child: Text(
                  'Trạng thái gần đây',
                  style: AppTypography.h3,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              ..._recentStatuses.asMap().entries.map((entry) {
                final index = entry.key;
                final status = entry.value;
                return SlideTransition(
                  position: Tween<Offset>(begin: Offset(0.3, 0), end: Offset.zero).animate(
                    CurvedAnimation(
                      parent: _slideController,
                      curve: Interval((index * 0.2).clamp(0.0, 1.0), ((index + 1) * 0.2).clamp(0.0, 1.0), curve: Curves.easeOut),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: _buildStatusItem(
                      name: status['name'],
                      action: status['action'],
                      time: status['time'],
                      icon: status['icon'],
                      color: status['color'],
                      delay: index * 0.1,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required String name,
    required String action,
    required String time,
    required IconData icon,
    required Color color,
    required double delay,
  }) {
    final isUnsafe = action.contains('rời');

    String formattedTime = 'Vừa xong';
    try {
      final lastTime = DateTime.parse(time).toLocal();
      final diff = DateTime.now().difference(lastTime);
      if (diff.inMinutes < 1) {
        formattedTime = 'Vừa xong';
      } else if (diff.inMinutes < 60) {
        formattedTime = '${diff.inMinutes} phút trước';
      } else if (diff.inHours < 24) {
        formattedTime = '${diff.inHours} giờ trước';
      } else {
        formattedTime = '${diff.inDays} ngày trước';
      }
    } catch (_) {
      formattedTime = time.split('T').first;
    }

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isUnsafe ? color.withOpacity(0.5) : AppColors.divider,
          width: isUnsafe ? 1.5 : 1,
        ),
        boxShadow: isUnsafe
            ? [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
            ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$name ', style: AppTypography.label.copyWith(fontWeight: FontWeight.bold)),
                      TextSpan(text: action, style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
                    ]
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (isUnsafe)
            Icon(Icons.warning_amber_rounded, color: color, size: 24),
        ],
      ),
    );
  }
}
