import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class SOSSuccessScreen extends StatefulWidget {
  final List<String> parentNames;
  final VoidCallback onDismiss;

  const SOSSuccessScreen({
    Key? key,
    required this.parentNames,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<SOSSuccessScreen> createState() => _SOSSuccessScreenState();
}

class _SOSSuccessScreenState extends State<SOSSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _animationController.forward();
    
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(color: AppColors.success.withOpacity(0.1)),
          
          // Content
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withOpacity(0.2),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 80,
                      color: AppColors.success,
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Message
                  Text(
                    '✅ Đã gửi cảnh báo',
                    style: AppTypography.h1.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Parents notified
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          'Ba mẹ đã nhận được thông báo:',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        ...widget.parentNames.map((name) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person, size: 16, color: AppColors.success),
                              SizedBox(width: 8),
                              Text(
                                name,
                                style: AppTypography.label.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Close button
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Đóng',
                      style: AppTypography.button.copyWith(
                        color: Colors.white,
                      ),
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
}
