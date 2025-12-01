import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Navigation item configuration for bottom bar
class CustomBottomBarItem {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;

  const CustomBottomBarItem({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

/// Custom bottom navigation bar for productivity app
/// Implements thumb-zone accessibility with Material Design 3 styling
/// Provides instant access to core productivity functions
class CustomBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<CustomBottomBarItem>? items;

  const CustomBottomBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.items,
  }) : super(key: key);

  /// Default navigation items based on Mobile Navigation Hierarchy
  static List<CustomBottomBarItem> get defaultItems => [
        CustomBottomBarItem(
          route: '/dashboard-screen',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'Dashboard',
        ),
        CustomBottomBarItem(
          route: '/schedule-management-screen',
          icon: Icons.calendar_today_outlined,
          activeIcon: Icons.calendar_today,
          label: 'Schedules',
        ),
        CustomBottomBarItem(
          route: '/manual-blocking-screen',
          icon: Icons.block_outlined,
          activeIcon: Icons.block,
          label: 'Block',
        ),
        CustomBottomBarItem(
          route: '/insights-screen',
          icon: Icons.insights_outlined,
          activeIcon: Icons.insights,
          label: 'Insights',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigationItems = items ?? defaultItems;

    return Container(
      decoration: BoxDecoration(
        color: theme.bottomNavigationBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              navigationItems.length,
              (index) =>
                  _buildNavigationItem(context, navigationItems[index], index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context,
    CustomBottomBarItem item,
    int index,
  ) {
    final theme = Theme.of(context);
    final isSelected = currentIndex == index;
    final color = isSelected
        ? theme.bottomNavigationBarTheme.selectedItemColor
        : theme.bottomNavigationBarTheme.unselectedItemColor;

    return Expanded(
      child: InkWell(
        onTap: () {
          // Haptic feedback for blocking confirmations
          HapticFeedback.lightImpact();
          onTap(index);
          Navigator.pushNamed(context, item.route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color?.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  if (item.badgeCount != null && item.badgeCount! > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: item.badgeCount! > 9 ? 4 : 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          item.badgeCount! > 99
                              ? '99+'
                              : item.badgeCount.toString(),
                          style: TextStyle(
                            color: theme.colorScheme.onError,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOut,
                style: (isSelected
                        ? theme.bottomNavigationBarTheme.selectedLabelStyle
                        : theme
                            .bottomNavigationBarTheme.unselectedLabelStyle) ??
                    TextStyle(),
                child: Text(
                  item.label,
                  style: TextStyle(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
