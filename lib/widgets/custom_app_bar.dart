import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App bar variant types for different screen contexts
enum CustomAppBarVariant {
  /// Standard app bar with back button and actions
  standard,

  /// App bar with search functionality
  search,

  /// App bar for blocking enforcement screens
  blocking,

  /// Transparent app bar for overlay screens
  transparent,
}

/// Custom app bar for productivity app
/// Implements Contemporary Minimalist Productivity design
/// Provides contextual controls based on screen state
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final CustomAppBarVariant variant;
  final VoidCallback? onSearchTap;
  final bool centerTitle;
  final double elevation;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    Key? key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.variant = CustomAppBarVariant.standard,
    this.onSearchTap,
    this.centerTitle = false,
    this.elevation = 0,
    this.backgroundColor,
    this.foregroundColor,
    this.bottom,
  }) : super(key: key);

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (variant) {
      case CustomAppBarVariant.search:
        return _buildSearchAppBar(context, theme);
      case CustomAppBarVariant.blocking:
        return _buildBlockingAppBar(context, theme);
      case CustomAppBarVariant.transparent:
        return _buildTransparentAppBar(context, theme);
      case CustomAppBarVariant.standard:
      default:
        return _buildStandardAppBar(context, theme);
    }
  }

  /// Standard app bar with clean design
  Widget _buildStandardAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!) : null),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      systemOverlayStyle: theme.brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      bottom: bottom,
    );
  }

  /// Search-enabled app bar with search icon
  Widget _buildSearchAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!) : null),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      systemOverlayStyle: theme.brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      actions: [
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () {
            HapticFeedback.lightImpact();
            onSearchTap?.call();
          },
          tooltip: 'Search',
        ),
        ...?actions,
      ],
      bottom: bottom,
    );
  }

  /// Blocking enforcement app bar with countdown timer
  Widget _buildBlockingAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      title:
          titleWidget ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock, size: 20, color: theme.colorScheme.error),
              SizedBox(width: 8),
              if (title != null)
                Text(
                  title!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
      leading: leading,
      automaticallyImplyLeading: false, // Prevent navigation during blocking
      centerTitle: true,
      elevation: elevation,
      backgroundColor:
          backgroundColor ??
          theme.colorScheme.errorContainer.withValues(alpha: 0.1),
      foregroundColor: foregroundColor ?? theme.colorScheme.error,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  /// Transparent app bar for overlay screens
  Widget _buildTransparentAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!) : null),
      leading:
          leading ??
          (automaticallyImplyLeading && Navigator.canPop(context)
              ? IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                )
              : null),
      automaticallyImplyLeading: false,
      centerTitle: centerTitle,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: foregroundColor ?? theme.colorScheme.onSurface,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Custom app bar with progress indicator for blocking sessions
class CustomAppBarWithProgress extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final double progress;
  final List<Widget>? actions;
  final VoidCallback? onEmergencyExit;

  const CustomAppBarWithProgress({
    Key? key,
    required this.title,
    required this.progress,
    this.actions,
    this.onEmergencyExit,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          title: Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: theme.colorScheme.errorContainer.withValues(
            alpha: 0.1,
          ),
          foregroundColor: theme.colorScheme.error,
          automaticallyImplyLeading: false,
          leading: onEmergencyExit != null
              ? IconButton(
                  icon: Icon(Icons.emergency),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    onEmergencyExit?.call();
                  },
                  tooltip: 'Emergency Exit',
                )
              : null,
          actions: actions,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: theme.brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.colorScheme.errorContainer.withValues(
            alpha: 0.2,
          ),
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.error),
          minHeight: 4,
        ),
      ],
    );
  }
}
