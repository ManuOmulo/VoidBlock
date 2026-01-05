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
    // Update every 15 seconds for UI sync (minutes only)
    _timer = Timer.periodic(Duration(seconds: 15), (_) => setState(() {}));
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
    final remainingData = _calculateRemaining();
    final remaining = remainingData['minutes'] as int;
    final isPaused = (_activeSession!['isPaused'] as bool?) ?? false;
    final apps = (_activeSession!['blockedApps'] as List?) ?? [];
    final isStrictMode = (_activeSession!['isStrictMode'] as bool?) ?? false;
    final strictModeLevel =
        (_activeSession!['strictModeLevel'] as String?) ?? 'NONE';

    // Debug: Print strict mode info
    print(
        'DEBUG ActiveSessionWidget: isStrictMode=$isStrictMode, strictModeLevel=$strictModeLevel, '
        'cooldownMinutes=${_activeSession!['strictModeCooldownMinutes']}, '
        'cooldownStartedAt=${_activeSession!['cooldownStartedAt']}, '
        'type=${_activeSession!['type']}');

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative circle
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                HapticFeedback.lightImpact();
              },
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPaused
                                ? Icons.pause_rounded
                                : Icons.timer_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPaused
                                    ? 'Session Paused'
                                    : (_activeSession!['type'] == 'schedule'
                                        ? 'Scheduled Focus'
                                        : 'Focus Session'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isPaused
                                          ? Colors.orangeAccent
                                          : Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    isPaused ? 'On Break' : 'Active',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${remaining}m',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              'remaining',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    if (apps.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(bottom: 24),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.apps_rounded,
                                color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Text(
                              '${apps.length} apps blocked',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isStrictMode && strictModeLevel != 'NONE')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildStrictModeBadge(strictModeLevel, theme),
                      ),
                    Row(
                      children: [
                        if (!isPaused && strictModeLevel != 'HARD')
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _pauseSession(),
                              icon: Icon(Icons.pause_rounded, size: 20),
                              label: Text('Pause'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: theme.colorScheme.primary,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        if (isPaused)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _resumeSession(),
                              icon: Icon(Icons.play_arrow_rounded, size: 20),
                              label: Text('Resume'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: theme.colorScheme.primary,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        if (isPaused && _activeSession!['type'] != 'schedule')
                          SizedBox(width: 12),
                        if (!isPaused && strictModeLevel != 'HARD')
                          SizedBox(width: 12),
                        if (_activeSession!['type'] != 'schedule')
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _stopSession(),
                              icon: Icon(Icons.stop_rounded, size: 20),
                              label: Text('End'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
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
        ],
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

    print(
        'DEBUG _pauseSession: strictModeLevel=$strictModeLevel, sessionId=$sessionId, isSchedule=$isSchedule');

    if (strictModeLevel != 'NONE') {
      try {
        print('DEBUG: Starting strict mode unlock...');
        await _handleStrictModeUnlock(strictModeLevel, sessionId, isSchedule);
        print('DEBUG: Strict mode unlock succeeded');
      } catch (e) {
        // Unlock failed or cancelled
        print('DEBUG: Strict mode unlock failed/cancelled: $e');
        return;
      }
    }

    print('DEBUG: Calling pauseBlocking()...');
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
        color: Colors.white.withValues(alpha: 0.2),
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
        // Start new cooldown
        print(
            'DEBUG MEDIUM: Starting new cooldown. isSchedule=$isSchedule, id=$id');
        if (isSchedule) {
          print('DEBUG: Calling startScheduleCooldown($id)');
          await strictModeService.startScheduleCooldown(id);
        } else {
          print('DEBUG: Calling startCooldown($id)');
          await strictModeService.startCooldown(id);
        }
        startTime = DateTime.now();
        print('DEBUG: Loading active session after starting cooldown...');
        await _loadActiveSession(); // Refresh to get updated cooldown time
        print('DEBUG: Active session reloaded');
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
        // Confirm cooldown completion based on type
        if (isSchedule) {
          final result =
              await strictModeService.confirmScheduleCooldownUnlock(id);
          if (result['success'] != true) {
            throw Exception('Cooldown not complete');
          }
        } else {
          final result = await strictModeService.confirmCooldownUnlock(id);
          if (result['success'] != true) {
            throw Exception('Cooldown not complete');
          }
        }
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

  Map<String, int> _calculateRemaining() {
    if (_activeSession == null) return {'minutes': 0, 'seconds': 0};

    final String type = _activeSession!['type'] as String? ?? 'manual';
    final int now = DateTime.now().millisecondsSinceEpoch;

    if (type == 'schedule') {
      final int endTime = _activeSession!['endTime'] as int? ?? 0;
      final int remainingMs = endTime - now;

      if (remainingMs <= 0) return {'minutes': 0, 'seconds': 0};

      return {
        'minutes': (remainingMs / (60 * 1000)).floor(),
        'seconds': ((remainingMs % (60 * 1000)) / 1000).floor(),
      };
    }

    // Manual session logic
    final int startTime = _activeSession!['startTime'] as int? ?? 0;
    final int durationMinutes = _activeSession!['durationMinutes'] as int? ?? 0;
    final bool isPaused = _activeSession!['isPaused'] as bool? ?? false;
    final int? pausedAt = _activeSession!['pausedAt'] as int?;
    final int accumulatedPausedMs =
        _activeSession!['accumulatedPausedMs'] as int? ?? 0;

    if (durationMinutes <= 0) {
      return {'minutes': 0, 'seconds': 0};
    }

    final int totalElapsedMs;
    if (isPaused && pausedAt != null) {
      totalElapsedMs = pausedAt - startTime - accumulatedPausedMs;
    } else {
      totalElapsedMs = now - startTime - accumulatedPausedMs;
    }

    final int totalDurationMs = durationMinutes * 60 * 1000;
    final int remainingMs = totalDurationMs - totalElapsedMs;

    if (remainingMs <= 0) return {'minutes': 0, 'seconds': 0};

    return {
      'minutes': (remainingMs / (60 * 1000)).floor(),
      'seconds': ((remainingMs % (60 * 1000)) / 1000).floor(),
    };
  }
}
