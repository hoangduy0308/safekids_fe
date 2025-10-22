import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/empty_state_widget.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Hồ sơ')),
        body: Center(child: Text('Không có dữ liệu người dùng')),
      );
    }

    final isParent = user.role == 'parent';
    final linkedAccounts = user.linkedUsersData
        .where((u) => u['role'] == (isParent ? 'child' : 'parent'))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: RefreshIndicator(
                onRefresh: () async {
                  await authProvider.refreshUser();
                },
                color: isParent
                    ? AppColors.parentPrimary
                    : AppColors.childPrimary,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildModernHeader(context, user, isParent),
                      SizedBox(height: AppSpacing.lg),
                      _buildQuickStats(context, user, linkedAccounts, isParent),
                      SizedBox(height: AppSpacing.md),
                      _buildInfoCards(context, user),
                      SizedBox(height: AppSpacing.md),
                      _buildLinkedAccountsSection(
                        context,
                        linkedAccounts,
                        isParent,
                      ),
                      SizedBox(height: AppSpacing.md),
                      _buildActionButtons(context, authProvider),
                      SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Floating back button
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.sm,
            left: AppSpacing.sm,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor.withOpacity(0.1),
                    blurRadius: AppSpacing.sm,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          // Floating edit button
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor.withOpacity(0.1),
                    blurRadius: AppSpacing.sm,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.edit,
                  color: isParent
                      ? AppColors.parentPrimary
                      : AppColors.childPrimary,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditProfileScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, user, bool isParent) {
    final roleColor = isParent
        ? AppColors.parentPrimary
        : AppColors.childPrimary;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        60,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: Column(
        children: [
          // Avatar with ring - Larger and more prominent
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring with animation-ready design
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [roleColor, roleColor.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Avatar
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: roleColor.withOpacity(0.25),
                      blurRadius: AppSpacing.lg,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: AppTypography.h1
                        .copyWith(color: roleColor)
                        .copyWith(fontSize: 52, letterSpacing: -1),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          // Name - Larger for better hierarchy
          Text(
            user.name,
            style: AppTypography.h1
                .copyWith(color: AppColors.textPrimary)
                .copyWith(fontSize: 32, letterSpacing: -0.5, height: 1.2),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppSpacing.xs),
          // Email - Better readability
          Text(
            user.email,
            style: AppTypography.body
                .copyWith(color: AppColors.textSecondary)
                .copyWith(letterSpacing: 0.2),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppSpacing.md),
          // Role badge - More prominent
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: roleColor.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isParent ? Icons.family_restroom : Icons.child_care,
                    color: roleColor,
                    size: AppSpacing.iconSm,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    isParent ? 'Phụ Huynh' : 'Trẻ Em',
                    style: AppTypography.body
                        .copyWith(color: roleColor)
                        .copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    user,
    List linkedAccounts,
    bool isParent,
  ) {
    final createdDate = user.createdAt != null
        ? DateFormat('dd/MM/yyyy').format(user.createdAt)
        : 'N/A';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              Icons.people_outline,
              linkedAccounts.length.toString(),
              isParent ? 'Trẻ em' : 'Phụ huynh',
              isParent ? AppColors.parentSecondary : AppColors.childAccent,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: _buildStatCard(
              Icons.calendar_today_outlined,
              createdDate,
              'Tham gia',
              isParent ? AppColors.parentAccent : AppColors.childPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: AppSpacing.xs,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: AppSpacing.iconMd),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTypography.h3
                .copyWith(color: AppColors.textPrimary)
                .copyWith(letterSpacing: -0.3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.caption
                .copyWith(color: AppColors.textSecondary)
                .copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(BuildContext context, user) {
    final isParent = user.role == 'parent';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          if (user.phone != null && user.phone.isNotEmpty)
            _buildInfoCard(
              Icons.phone_outlined,
              'Số điện thoại',
              user.phone,
              isParent ? AppColors.parentPrimary : AppColors.childPrimary,
            ),
          if (user.age != null)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: _buildInfoCard(
                Icons.cake_outlined,
                'Tuổi',
                '${user.age} tuổi',
                isParent ? AppColors.parentAccent : AppColors.childAccent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: AppSpacing.xs,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: AppSpacing.iconMd),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondary)
                      .copyWith(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textPrimary)
                      .copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedAccountsSection(
    BuildContext context,
    List<Map<String, dynamic>> accounts,
    bool isParent,
  ) {
    final roleColor = isParent
        ? AppColors.parentSecondary
        : AppColors.childPrimary;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.08),
            blurRadius: AppSpacing.xs,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  isParent ? Icons.child_care : Icons.family_restroom,
                  color: roleColor,
                  size: AppSpacing.iconSm,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  isParent ? 'Con em được liên kết' : 'Phụ huynh đang theo dõi',
                  style: AppTypography.h3
                      .copyWith(color: AppColors.textPrimary)
                      .copyWith(letterSpacing: -0.3),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          if (accounts.isEmpty)
            EmptyStateWidget(
              icon: isParent
                  ? Icons.child_care_outlined
                  : Icons.family_restroom_outlined,
              title: isParent ? 'Chưa có liên kết nào' : 'Chưa có phụ huynh',
              message: isParent
                  ? 'Bạn chưa liên kết với tài khoản trẻ em nào.\nHãy thêm con em để bắt đầu theo dõi!'
                  : 'Tài khoản của bạn chưa được liên kết\nvới phụ huynh nào.',
              color: isParent
                  ? AppColors.parentSecondary
                  : AppColors.childPrimary,
            )
          else
            ...accounts
                .map((account) => _buildAccountCard(account, isParent))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account, bool isParent) {
    final avatarColor = isParent
        ? AppColors.childAccent
        : AppColors.parentPrimary;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Center(
                    child: Text(
                      (account['name'] ?? 'U')[0].toUpperCase(),
                      style: AppTypography.h3.copyWith(color: avatarColor),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account['name'] ?? 'Unknown',
                        style: AppTypography.body
                            .copyWith(color: AppColors.textPrimary)
                            .copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                      ),
                      SizedBox(height: AppSpacing.xxs),
                      Text(
                        account['email'] ?? '',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    'Liên kết',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.success)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AuthProvider authProvider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withOpacity(0.08),
              blurRadius: AppSpacing.sm,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              _showLogoutDialog(context, authProvider);
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                    size: AppSpacing.iconSm,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'Đăng xuất',
                    style: AppTypography.body
                        .copyWith(color: AppColors.danger)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
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
            child: Text(
              'Đăng xuất',
              style: AppTypography.button.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await authProvider.logout();
    }
  }
}
