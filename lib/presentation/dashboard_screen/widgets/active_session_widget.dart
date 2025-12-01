import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/blocking_service.dart';
import '../../../services/strict_mode_service.dart';
import '../../../presentation/strict_mode_setup/pin_entry_dialog.dart';
import '../../../presentation/strict_mode_setup/cooldown_screen.dart';
import '../../../presentation/strict_mode_setup/hard_mode_locked_dialog.dart';

/// Widget to display the currently active blocking session
class ActiveSessionWidget extends StatefulWidget {
  const ActiveSessionWidget({Key? key}) : super(key: key);

  @override
  State<ActiveSessionWidget> createState() => ActiveSessionWidgetState();
}

class ActiveSessionWidgetState extends State<ActiveSessionWidget> {
  final BlockingService _blockingService = BlockingService();
  Map<String, dynamic>? _activeSession;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadActiveSession();
    // Update every minute
    _timer = Timer.periodic(Duration(minutes: 1), (_) => _loadActiveSession());
  }

  Future<void> refresh() async {
    await _loadActiveSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveSession() async {
    try {
      final session = await _blockingService.getActiveSession();
      if (mounted) {
        setState(() => _activeSession = session);
      }
    } catch (e) {
      print('Error loading active session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSession == null || _activeSession!['isActive'] != true) {
      return SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final remaining = (_activeSession!['remainingMinutes'] as int?) ?? 0;
    final isPaused = (_activeSession!['isPaused'] as bool?) ?? false;
    final apps = (_activeSession!['blockedApps'] as List?) ?? [];
    final isStrictMode = (_activeSession!['isStrictMode'] as bool?) ?? false;
    final strictModeLevel =
        (_activeSession!['strictModeLevel'] as String?) ?? 'NONE';
    final sessionId = (_activeSession!['id'] as int?) ?? 0;

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            // Could navigate to session details
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPaused ? Icons.pause_circle : Icons.block,
                      color: Colors.white,
                      size: 32,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPaused
                                ? 'Blocking Paused'
                                : (_activeSession!['type'] == 'schedule'
                                    ? 'Scheduled Blocking'
                                    : 'Active Blocking'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isStrictMode && strictModeLevel != 'NONE') ...[
                            SizedBox(height: 4),
                            _buildStrictModeBadge(strictModeLevel, theme),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      '${remaining}min',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Blocking ${apps.length} apps',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    // Show pause button for non-strict and Easy/Medium strict modes
                    // Hard mode has no pause functionality
                    if (!isPaused && strictModeLevel != 'HARD')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pauseSession(),
                          icon: Icon(Icons.pause, size: 18),
                          label: Text('Pause'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    if (isPaused)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _resumeSession(),
                          icon: Icon(Icons.play_arrow, size: 18),
                          label: Text('Resume'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    if (!isPaused && strictModeLevel != 'HARD')
                      SizedBox(width: 8),
                    if (_activeSession!['type'] != 'schedule')
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _stopSession(),
                          icon: Icon(Icons.stop, size: 18),
                          label: Text('End'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.5)),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pauseSession() async {
    HapticFeedback.mediumImpact();

    // Check for strict mode
    final strictModeLevel =
        (_activeSession!['strictModeLevel'] as String?) ?? 'NONE';
    final sessionId = (_activeSession!['id'] as int?) ?? 0;
    final isSchedule = _activeSession!['type'] == 'schedule';

    if (strictModeLevel != 'NONE') {
      try {
        await _handleStrictModeUnlock(strictModeLevel, sessionId, isSchedule);
      } catch (e) {
        // Unlock failed or cancelled
        return;
      }
    }

    final success = await _blockingService.pauseBlocking();
    if (success) {
      _loadActiveSession();
    }
  }

  Future<void> _resumeSession() async {
    HapticFeedback.mediumImpact();
    final success = await _blockingService.resumeBlocking();
    if (success) {
      _loadActiveSession();
    }
  }

  Future<void> _stopSession() async {
    HapticFeedback.mediumImpact();

    // Check for strict mode
    final strictModeLevel =
        (_activeSession!['strictModeLevel'] as String?) ?? 'NONE';
    final sessionId = (_activeSession!['id'] as int?) ?? 0;
    final isSchedule = _activeSession!['type'] == 'schedule';

    if (strictModeLevel != 'NONE') {
      try {
        await _handleStrictModeUnlock(strictModeLevel, sessionId, isSchedule);
      } catch (e) {
        // Unlock failed or cancelled
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Blocking Session?'),
        content: Text('Are you sure you want to end this session early?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('End Session'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      print('DEBUG: Stopping session...');
      final success = await _blockingService.stopBlocking();
      print('DEBUG: Stop session result: $success');

      // Wait a bit for DB update
      await Future.delayed(Duration(milliseconds: 500));
      await _loadActiveSession();
    }
  }

  Widget _buildStrictModeBadge(String level, ThemeData theme) {
    final Map<String, Map<String, dynamic>> levelConfig = {
      'EASY': {
        'icon': Icons.pin,
        'label': 'PIN Protected',
        'color': Colors.blue
      },
      'MEDIUM': {
        'icon': Icons.timer,
        'label': 'Cooldown',
        'color': Colors.orange
      },
      'HARD': {'icon': Icons.lock, 'label': 'Locked', 'color': Colors.red},
    };

    final config = levelConfig[level] ?? levelConfig['EASY']!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'], color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            config['label'],
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStrictModeUnlock(
      String level, int id, bool isSchedule) async {
    final strictModeService = StrictModeService();

    if (level == 'EASY') {
      // Show PIN entry dialog
      final pin = await showDialog<String>(
        context: context,
        builder: (context) => PinEntryDialog(),
      );

      if (pin != null) {
        // Call appropriate unlock method based on type
        final result = isSchedule
            ? await strictModeService.attemptUnlockSchedule(
                scheduleId: id,
                pin: pin,
              )
            : await strictModeService.attemptUnlockSession(
                sessionId: id,
                pin: pin,
              );

        if (result['success'] == true) {
          return; // Unlock successful, proceed
        } else {
          // Show error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['reason'] ?? 'Incorrect PIN'),
                backgroundColor: Colors.red,
              ),
            );
          }
          throw Exception('PIN unlock failed');
        }
      } else {
        throw Exception('PIN entry cancelled');
      }
    } else if (level == 'MEDIUM') {
      // Show cooldown screen
      final cooldownMinutes =
          _activeSession!['strictModeCooldownMinutes'] as int? ?? 10;
      final cooldownStartedAt = _activeSession!['cooldownStartedAt'] as int?;

      DateTime startTime;
      if (cooldownStartedAt != null && cooldownStartedAt > 0) {
        startTime = DateTime.fromMillisecondsSinceEpoch(cooldownStartedAt);
      } else {
        // Start new cooldown (only works for sessions, not schedules)
        if (!isSchedule) {
          await strictModeService.startCooldown(id);
          startTime = DateTime.now();
          await _loadActiveSession(); // Refresh to get updated cooldown time
        } else {
          startTime = DateTime.now();
        }
      }

      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => CooldownScreen(
            cooldownMinutes: cooldownMinutes,
            cooldownStartTime: startTime,
          ),
          fullscreenDialog: true,
        ),
      );

      if (confirmed == true) {
        // For schedules, we can't confirm cooldown in the same way
        if (!isSchedule) {
          final result = await strictModeService.confirmCooldownUnlock(id);
          if (result['success'] != true) {
            throw Exception('Cooldown not complete');
          }
        }
        // For schedules, just proceed if cooldown time has elapsed
      } else {
        throw Exception('Cooldown cancelled');
      }
    } else if (level == 'HARD') {
      // Show hard mode locked dialog
      final endTime = _activeSession!['endTime'] as int?;
      if (endTime != null) {
        await showDialog(
          context: context,
          builder: (context) => HardModeLockedDialog(
            endTime: DateTime.fromMillisecondsSinceEpoch(endTime),
            isSchedule: _activeSession!['type'] == 'schedule',
          ),
        );
      }
      throw Exception('Hard mode locked');
    }
  }
}
