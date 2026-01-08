import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/app_export.dart';
import '../../../services/strict_mode_service.dart';
import '../../strict_mode_setup/pin_entry_dialog.dart';

/// Individual schedule card with swipe actions and status indicators
class ScheduleCardWidget extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onViewStats;
  final VoidCallback onDelete;
  final Function(bool) onToggle;
  const ScheduleCardWidget({
    Key? key,
    required this.schedule,
    required this.onEdit,
    required this.onDuplicate,
    required this.onViewStats,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = schedule['isActive'] as bool;
    final isStrictMode = schedule['isStrictMode'] as bool;
    final isCurrentlyRunning = schedule['isCurrentlyRunning'] as bool? ?? false;
    final hasConflict = schedule['hasConflict'] as bool? ?? false;

    return Slidable(
      key: ValueKey(schedule['id']),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => onDuplicate(),
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: Colors.white,
            icon: Icons.content_copy,
            label: 'Duplicate',
          ),
          SlidableAction(
            onPressed: (_) => onViewStats(),
            backgroundColor: theme.colorScheme.tertiary,
            foregroundColor: Colors.white,
            icon: Icons.bar_chart,
            label: 'Stats',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: hasConflict ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: hasConflict
              ? BorderSide(color: AppTheme.warningLight, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _showContextMenu(context, theme),
          onLongPress: () => _showContextMenu(context, theme),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  schedule['name'] as String,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8),
                              if (isStrictMode)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomIconWidget(
                                        iconName: 'lock',
                                        size: 12,
                                        color: theme.colorScheme.error,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Strict',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (schedule['isRecurring'] as bool? ?? false)
                                Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: CustomIconWidget(
                                    iconName: 'repeat',
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Next: ${schedule['nextActivation']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isActive,
                      onChanged:
                          isStrictMode && isCurrentlyRunning ? null : onToggle,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'apps',
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '${schedule['appCount']} apps',
                      style: theme.textTheme.bodySmall,
                    ),
                    SizedBox(width: 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.1,
                              ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isActive
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isCurrentlyRunning) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Currently Running',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ends in ${schedule['remainingTime']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (hasConflict) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.warningLight,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'warning',
                          size: 20,
                          color: AppTheme.warningLight,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Schedule conflict detected',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.warningLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showConflictResolution(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.warningLight,
                          ),
                          child: Text('Resolve'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                schedule['name'] as String,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'edit',
                color: theme.colorScheme.primary,
              ),
              title: Text('Edit Schedule'),
              onTap: () {
                Navigator.pop(context);
                _handleEdit(context);
              },
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEdit(BuildContext context) async {
    final isStrictMode = schedule['isStrictMode'] as bool? ?? false;

    if (!isStrictMode) {
      onEdit();
      return;
    }

    final level = schedule['strictModeLevel'] as String? ?? 'NONE';
    final strictModeService = StrictModeService();

    if (level == 'HARD') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Settings Locked'),
          content:
              Text('This schedule is in Hard Mode. Settings cannot be edited.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (level == 'MEDIUM') {
      final scheduleId = schedule['id'] as int;
      // Check cooldown - this part requires logic that might be complex to put in a card
      // Ideally we would have a 'getScheduleCooldownStatus' but for now let's implement the flow
      // Simplification: For Medium, we just enforce the cooldown start flow
      // NOTE: This assumes we can't easily check existing cooldown state without state management.
      // Better approach: Try to edit, if it's medium, we start the cooldown process.

      // Since we don't have the cooldown state here easily, we'll just show the cooldown dialog
      // This matches the implementation in ActiveSessionWidget for consistency

      // First, check if we are ALREADY in cooldown?
      // Since we can't easily, we will show a dialog explaining the cooldown

      /*
      // SIMPLIFICATION:
      // If Medium, we rely on the user to wait. 
      // But user requested: "wait for the cooldown period that was set to elapse before accessing"
      // This implies we need to START the cooldown.
      */

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Strict Mode Active'),
          content: Text(
            'This schedule is in Medium Strict Mode. You must wait the cooldown period to edit settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                // Start cooldown
                final success =
                    await strictModeService.startScheduleCooldown(scheduleId);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Cooldown started. You will be notified when you can edit.')),
                  );
                } else {
                  // If it failed, it might mean we are already in cooldown or ready to unlock
                  // Let's try to "confirm" unlock just in case
                  final unlockResult = await strictModeService
                      .confirmScheduleCooldownUnlock(scheduleId);
                  if (unlockResult['success'] == true) {
                    onEdit();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Wait for cooldown to finish.')),
                    );
                  }
                }
              },
              child: Text('Start Cooldown / Unlock'),
            ),
          ],
        ),
      );
      return;
    }

    if (level == 'EASY') {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => PinEntryDialog(
          remainingAttempts: 5, // Hardcoded for now
          lockoutSeconds: 0,
        ),
      );

      if (result != null) {
        final scheduleId = schedule['id'] as int;

        final unlockResult = await strictModeService.attemptUnlockSchedule(
          scheduleId: scheduleId,
          pin: result,
        );

        if (unlockResult['success'] == true) {
          onEdit();
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(unlockResult['reason'] ?? 'Incorrect PIN'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }
      return;
    }

    // Fallback
    onEdit();
  }

  void _showConflictResolution(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'warning',
                      color: AppTheme.warningLight,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Schedule Conflict',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: CustomIconWidget(
                        iconName: 'close',
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'This schedule overlaps with:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Work Focus Schedule',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Monday-Friday, 9:00 AM - 5:00 PM',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Resolution Options:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                  ),
                  child: Text('Adjust Time Range'),
                ),
                SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                  ),
                  child: Text('Keep Both (Priority Based)'),
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                  ),
                  child: Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
