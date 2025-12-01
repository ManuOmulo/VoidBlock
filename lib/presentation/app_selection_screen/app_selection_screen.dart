import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../services/analytics_service.dart';
import '../../widgets/custom_app_bar.dart';
import './widgets/app_list_item_widget.dart';
import './widgets/category_filter_chip_widget.dart';
import './widgets/empty_search_widget.dart';
import './widgets/search_bar_widget.dart';
import './widgets/selected_apps_bottom_bar_widget.dart';

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({Key? key}) : super(key: key);

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedAppPackages = {};
  final AnalyticsService _analyticsService = AnalyticsService();

  String _selectedCategory = 'All';
  bool _isLoading = true;
  List<InstalledApp> _installedApps = [];
  List<InstalledApp> _filteredApps = [];

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
    _searchController.addListener(_filterApps);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _isLoading = true);

    try {
      // Load only user apps (not system apps)
      final apps = await _analyticsService.getUserApps();

      setState(() {
        _installedApps = apps;
        _filteredApps = List.from(apps);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading apps: $e');
      setState(() => _isLoading = false);

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load apps. Please try again.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadInstalledApps,
            ),
          ),
        );
      }
    }
  }

  void _filterApps() {
    setState(() {
      String query = _searchController.text.toLowerCase();
      _filteredApps = _installedApps.where((app) {
        bool matchesSearch = app.appName.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query);
        bool matchesCategory = _selectedCategory == 'All' ||
            _getCategory(app.packageName) == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  String _getCategory(String packageName) {
    // Basic categorization logic
    final pkg = packageName.toLowerCase();
    if (pkg.contains('social') ||
        pkg.contains('facebook') ||
        pkg.contains('instagram') ||
        pkg.contains('twitter') ||
        pkg.contains('snapchat')) {
      return 'Social';
    } else if (pkg.contains('game')) {
      return 'Games';
    } else if (pkg.contains('video') ||
        pkg.contains('youtube') ||
        pkg.contains('netflix') ||
        pkg.contains('spotify') ||
        pkg.contains('tiktok')) {
      return 'Entertainment';
    } else if (pkg.contains('office') ||
        pkg.contains('productivity') ||
        pkg.contains('outlook') ||
        pkg.contains('slack') ||
        pkg.contains('notion') ||
        pkg.contains('todoist')) {
      return 'Productivity';
    }
    return 'Other';
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _filterApps();
    });
  }

  void _toggleAppSelection(String package) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedAppPackages.contains(package)) {
        _selectedAppPackages.remove(package);
      } else {
        _selectedAppPackages.add(package);
      }
    });
  }

  void _selectAllInCategory() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (var app in _filteredApps) {
        _selectedAppPackages.add(app.packageName);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _filterApps();
  }

  Future<void> _refreshApps() async {
    await _loadInstalledApps();
  }

  void _continueWithSelection() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _selectedAppPackages.toList());
  }

  Map<String, int> _getCategoryCounts() {
    Map<String, int> counts = {'All': _installedApps.length};
    for (var app in _installedApps) {
      String category = _getCategory(app.packageName);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryCounts = _getCategoryCounts();
    final categories = [
      'All',
      'Social',
      'Games',
      'Entertainment',
      'Productivity',
      'Other',
    ];

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Select Apps',
        variant: CustomAppBarVariant.standard,
        actions: [
          TextButton(
            onPressed: _filteredApps.isEmpty ? null : _selectAllInCategory,
            child: Text(
              'Select All',
              style: theme.textTheme.labelLarge?.copyWith(
                color: _filteredApps.isEmpty
                    ? theme.colorScheme.onSurface.withOpacity(0.3)
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading installed apps...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Search Bar
                SizedBox(height: 2.h),
                SearchBarWidget(
                  controller: _searchController,
                  onChanged: (_) => _filterApps(),
                  onClear: _clearSearch,
                ),
                SizedBox(height: 2.h),

                // Category Filter Chips
                Container(
                  height: 6.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      String category = categories[index];
                      int count = categoryCounts[category] ?? 0;
                      if (count == 0 && category != 'All')
                        return SizedBox.shrink();

                      return CategoryFilterChipWidget(
                        category: category,
                        count: count,
                        isSelected: _selectedCategory == category,
                        onTap: () => _selectCategory(category),
                      );
                    },
                  ),
                ),
                SizedBox(height: 2.h),

                // Apps List
                Expanded(
                  child: _filteredApps.isEmpty
                      ? EmptySearchWidget(
                          searchQuery: _searchController.text,
                          onClearSearch: _clearSearch,
                        )
                      : RefreshIndicator(
                          onRefresh: _refreshApps,
                          child: ListView.builder(
                            itemCount: _filteredApps.length,
                            itemBuilder: (context, index) {
                              final app = _filteredApps[index];

                              // Convert to map format for AppListItemWidget
                              final appData = {
                                "package": app.packageName,
                                "name": app.appName,
                                "category": _getCategory(app.packageName),
                                "icon": app.iconBase64 != null
                                    ? "data:image/png;base64,${app.iconBase64}"
                                    : null,
                                "semanticLabel": "${app.appName} app icon",
                              };

                              return AppListItemWidget(
                                app: appData,
                                isSelected: _selectedAppPackages
                                    .contains(app.packageName),
                                onTap: () =>
                                    _toggleAppSelection(app.packageName),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: SelectedAppsBottomBarWidget(
        selectedCount: _selectedAppPackages.length,
        onContinue: _continueWithSelection,
      ),
    );
  }
}
