import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

/// App selection section showing selected apps count and change button
class AppSelectionSection extends StatelessWidget {
  final int selectedAppsCount;
  final List<Map<String, dynamic>> selectedApps;
  final VoidCallback onChangeApps;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const AppSelectionSection({
    Key? key,
    required this.selectedAppsCount,
    required this.selectedApps,
    required this.onChangeApps,
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
                    iconName: 'apps',
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Selection',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          '$selectedAppsCount ${selectedAppsCount == 1 ? 'app' : 'apps'} selected',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
                children: [
                  if (selectedApps.isNotEmpty) ...[
                    Container(
                      constraints: BoxConstraints(maxHeight: 20.h),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: selectedApps.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 1.h),
                        itemBuilder: (context, index) {
                          final app = selectedApps[index];
                          return Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CustomImageWidget(
                                  imageUrl: app['icon'] as String,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  semanticLabel: 'App icon for ${app['name']}',
                                ),
                                SizedBox(width: 3.w),
                                Expanded(
                                  child: Text(
                                    app['name'] as String,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 2.h),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onChangeApps,
                      icon: CustomIconWidget(
                        iconName: selectedAppsCount > 0 ? 'edit' : 'add',
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      label: Text(
                        selectedAppsCount > 0 ? 'Change Apps' : 'Select Apps',
                      ),
                    ),
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
