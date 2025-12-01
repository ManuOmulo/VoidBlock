import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Advanced options section with strict mode, messages, and notifications
class AdvancedOptionsSection extends StatelessWidget {
  final bool strictModeEnabled;
  final Function(bool) onStrictModeChanged;
  final TextEditingController motivationalMessageController;
  final bool notificationsEnabled;
  final Function(bool) onNotificationsChanged;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const AdvancedOptionsSection({
    Key? key,
    required this.strictModeEnabled,
    required this.onStrictModeChanged,
    required this.motivationalMessageController,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.isExpanded,
    required this.onToggleExpand,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpand,
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'tune',
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'Advanced Options',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CustomIconWidget(
                    iconName: isExpanded ? 'expand_less' : 'expand_more',
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: strictModeEnabled
                          ? theme.colorScheme.errorContainer.withValues(
                              alpha: 0.2,
                            )
                          : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: strictModeEnabled
                            ? theme.colorScheme.error.withValues(alpha: 0.3)
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
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
                                      CustomIconWidget(
                                        iconName: 'lock',
                                        color: strictModeEnabled
                                            ? theme.colorScheme.error
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        size: 20,
                                      ),
                                      SizedBox(width: 2.w),
                                      Text(
                                        'Strict Mode',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: strictModeEnabled
                                                  ? theme.colorScheme.error
                                                  : null,
                                            ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 1.h),
                                  Text(
                                    'Prevents schedule modifications during active blocking periods',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: strictModeEnabled,
                              onChanged: onStrictModeChanged,
                            ),
                          ],
                        ),
                        if (strictModeEnabled) ...[
                          SizedBox(height: 2.h),
                          Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                CustomIconWidget(
                                  iconName: 'warning',
                                  color: theme.colorScheme.error,
                                  size: 16,
                                ),
                                SizedBox(width: 2.w),
                                Expanded(
                                  child: Text(
                                    'You won\'t be able to disable or modify this schedule until the blocking period ends',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  TextField(
                    controller: motivationalMessageController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: 'Motivational Message',
                      hintText: 'Enter a message to display during blocking...',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(3.w),
                        child: CustomIconWidget(
                          iconName: 'format_quote',
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  SwitchListTile(
                    value: notificationsEnabled,
                    onChanged: onNotificationsChanged,
                    title: Text(
                      'Schedule Notifications',
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      'Get notified when blocking starts and ends',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    secondary: CustomIconWidget(
                      iconName: 'notifications',
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
