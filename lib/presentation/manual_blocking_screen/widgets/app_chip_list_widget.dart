import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Widget displaying selected apps as horizontal scrollable chips
/// Each chip shows app icon and name with remove functionality
class AppChipListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> selectedApps;
  final Function(int) onRemoveApp;

  const AppChipListWidget({
    Key? key,
    required this.selectedApps,
    required this.onRemoveApp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (selectedApps.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            CustomIconWidget(
              iconName: 'info_outline',
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No apps selected. Go back to select apps to block.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: selectedApps.length,
        separatorBuilder: (context, index) => SizedBox(width: 12),
        itemBuilder: (context, index) {
          final app = selectedApps[index];
          return _buildAppChip(context, theme, app, index);
        },
      ),
    );
  }

  Widget _buildAppChip(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> app,
    int index,
  ) {
    final iconBase64 = app['iconBase64'] as String?;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: iconBase64 != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(iconBase64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => CustomIconWidget(
                        iconName: 'apps',
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  )
                : CustomIconWidget(
                    iconName: app['icon'] as String? ?? 'apps',
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app['name'] as String? ?? 'Unknown App',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  app['package'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          InkWell(
            onTap: () => onRemoveApp(index),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(4),
              child: CustomIconWidget(
                iconName: 'close',
                color: theme.colorScheme.error,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
