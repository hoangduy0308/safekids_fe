import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';

class AudioCallScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> otherUser;
  final String? callerId;

  const AudioCallScreen({
    Key? key,
    required this.conversationId,
    required this.otherUser,
    this.callerId,
  }) : super(key: key);

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  late SocketService _socketService;
  bool _isMuted = false;
  bool _useSpeaker = true;
  int _callDuration = 0;
  late DateTime _callStartTime;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService();
    _callStartTime = DateTime.now();
    _startCallTimer();
    
    // Listen for call ended from other party
    _socketService.onCallEnded = (data) {
      debugPrint('[AudioCallScreen] Call ended by other party');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call ended')),
        );
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      }
    };
  }

  void _startCallTimer() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _callDuration = DateTime.now().difference(_callStartTime).inSeconds;
        });
        _startCallTimer();
      }
    });
  }

  void _endCall() {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      _socketService.emitCallEnded({
        'senderId': userId.toString(),
        'receiverId': widget.otherUser['_id'].toString(),
        'conversationId': widget.conversationId,
      });
    }
    Navigator.pop(context);
  }

  String _formatCallDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Caller/Receiver Name
                    Text(
                      widget.otherUser['name'] ?? 'User',
                      style: AppTypography.h2.copyWith(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Avatar
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.childPrimary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (widget.otherUser['name'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: AppColors.childPrimary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg),

                    // Call Duration
                    Text(
                      _formatCallDuration(_callDuration),
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Control Buttons
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Button
                    GestureDetector(
                      onTap: () => setState(() => _isMuted = !_isMuted),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _isMuted ? Colors.red : Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                    // Speaker Button
                    GestureDetector(
                      onTap: () => setState(() => _useSpeaker = !_useSpeaker),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _useSpeaker ? Colors.blue : Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _useSpeaker ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                    // End Call Button
                    GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 28,
                        ),
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
  }

  @override
  void dispose() {
    _endCall();
    super.dispose();
  }
}
