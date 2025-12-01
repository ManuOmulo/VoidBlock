import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/countdown_timer_widget.dart';
import './widgets/emergency_contact_widget.dart';
import './widgets/lock_icon_widget.dart';
import './widgets/restriction_message_widget.dart';

/// Strict Mode Lock Screen
/// Enforces blocking session integrity by preventing schedule modifications
/// during active strict mode periods
class StrictModeLockScreen extends StatefulWidget {
  const StrictModeLockScreen({Key? key}) : super(key: key);

  @override
  State<StrictModeLockScreen> createState() => _StrictModeLockScreenState();
}

class _StrictModeLockScreenState extends State<StrictModeLockScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Mock strict mode session data
  DateTime _sessionEndTime = DateTime.now().add(
    Duration(hours: 2, minutes: 30),
  );
  Duration _remainingTime = Duration(hours: 2, minutes: 30);
  Timer? _countdownTimer;
  bool _showMilestoneNotification = false;
  String _milestoneMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startCountdown();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _initializeAnimations() {
    // Pulsing animation for lock icon
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fade animation for milestone notifications
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _remainingTime = _sessionEndTime.difference(DateTime.now());

        if (_remainingTime.inSeconds <= 0) {
          _handleSessionComplete();
          timer.cancel();
        } else {
          _checkMilestones();
        }
      });
    });
  }

  void _checkMilestones() {
    final totalSeconds = Duration(hours: 2, minutes: 30).inSeconds;
    final remainingSeconds = _remainingTime.inSeconds;
    final progress = remainingSeconds / totalSeconds;

    // Halfway point notification
    if (progress <= 0.5 && progress > 0.49 && !_showMilestoneNotification) {
      _showMilestone('Halfway there! Keep going strong! 💪');
    }
    // Final 10 minutes notification
    else if (remainingSeconds <= 600 &&
        remainingSeconds > 590 &&
        !_showMilestoneNotification) {
      _showMilestone('Final 10 minutes! You\'ve got this! 🎯');
    }
  }

  void _showMilestone(String message) {
    setState(() {
      _showMilestoneNotification = true;
      _milestoneMessage = message;
    });
    _fadeController.forward();

    Future.delayed(Duration(seconds: 3), () {
      _fadeController.reverse().then((_) {
        setState(() {
          _showMilestoneNotification = false;
        });
      });
    });
  }

  void _handleSessionComplete() {
    HapticFeedback.heavyImpact();
    Navigator.pushReplacementNamed(context, '/dashboard-screen');
  }

  void _handleUnderstandButton() {
    HapticFeedback.mediumImpact();
    Navigator.pushReplacementNamed(context, '/dashboard-screen');
  }

  void _handleEmergencyContact() {
    HapticFeedback.heavyImpact();
    // In production, this would open native phone app with pre-configured contact
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Emergency Contact'),
        content: Text(
          'Opening phone app with emergency contact.\n\nNote: This is a demo. In production, this would launch your device\'s phone app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _countdownTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: theme.colorScheme.errorContainer.withValues(
          alpha: 0.05,
        ),
        appBar: CustomAppBar(
          variant: CustomAppBarVariant.blocking,
          title: 'Strict Mode Active',
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Main content
              SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      SizedBox(height: 40),
                      // Animated lock icon
                      LockIconWidget(pulseAnimation: _pulseAnimation),
                      SizedBox(height: 48),
                      // Countdown timer
                      CountdownTimerWidget(
                        remainingTime: _remainingTime,
                        sessionEndTime: _sessionEndTime,
                      ),
                      SizedBox(height: 48),
                      // Restriction message
                      RestrictionMessageWidget(),
                      SizedBox(height: 64),
                      // Action buttons
                      _buildActionButtons(theme),
                      SizedBox(height: 32),
                      // Emergency contact
                      EmergencyContactWidget(onTap: _handleEmergencyContact),
                    ],
                  ),
                ),
              ),
              // Milestone notification overlay
              if (_showMilestoneNotification)
                Positioned(
                  top: 16,
                  left: 24,
                  right: 24,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'celebration',
                            color: theme.colorScheme.onSecondary,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _milestoneMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        // I Understand button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleUnderstandButton,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomIconWidget(
                  iconName: 'check_circle',
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'I Understand',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        // Return to Dashboard text
        Text(
          'This will return you to the Dashboard',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
