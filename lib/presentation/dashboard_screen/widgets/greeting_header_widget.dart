import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Greeting header widget showing personalized greeting and current time
class GreetingHeaderWidget extends StatefulWidget {
  final VoidCallback? onSettingsPressed;

  const GreetingHeaderWidget({Key? key, this.onSettingsPressed}) : super(key: key);

  @override
  State<GreetingHeaderWidget> createState() => _GreetingHeaderWidgetState();
}

class _GreetingHeaderWidgetState extends State<GreetingHeaderWidget> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Update time every second to be accurate
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = _now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final is24Hour = MediaQuery.of(context).alwaysUse24HourFormat;
    final timeFormat = is24Hour ? DateFormat('HH:mm') : DateFormat('h:mm a');
    final dateFormat = DateFormat('EEEE, MMMM d');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getGreeting(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        dateFormat.format(_now),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      timeFormat.format(_now),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: CustomIconWidget(
              iconName: 'settings',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: widget.onSettingsPressed,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
