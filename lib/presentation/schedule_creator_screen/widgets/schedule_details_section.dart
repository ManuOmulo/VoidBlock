import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Schedule details section with name input and suggested names
class ScheduleDetailsSection extends StatelessWidget {
  final TextEditingController nameController;
  final int characterCount;
  final int maxCharacters;
  final List<String> suggestedNames;
  final Function(String) onSuggestionTap;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const ScheduleDetailsSection({
    Key? key,
    required this.nameController,
    required this.characterCount,
    required this.maxCharacters,
    required this.suggestedNames,
    required this.onSuggestionTap,
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
                    iconName: 'edit_note',
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      'Schedule Details',
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
                  TextField(
                    controller: nameController,
                    maxLength: maxCharacters,
                    decoration: InputDecoration(
                      labelText: 'Schedule Name',
                      hintText: 'Enter a name for this schedule',
                      counterText: '$characterCount/$maxCharacters',
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(3.w),
                        child: CustomIconWidget(
                          iconName: 'label',
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  if (suggestedNames.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      'Suggested Names',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 1.h,
                      children: suggestedNames.map((name) {
                        return ActionChip(
                          label: Text(
                            name,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => onSuggestionTap(name),
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          avatar: CustomIconWidget(
                            iconName: 'lightbulb_outline',
                            color: theme.colorScheme.primary,
                            size: 16,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
