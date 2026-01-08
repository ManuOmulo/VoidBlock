import 'package:flutter/material.dart';
import '../../services/app_limit_service.dart';
import '../../services/analytics_service.dart';
import '../app_selection_screen/app_selection_screen.dart';
import '../../../widgets/custom_image_widget.dart';

class CreateAppLimitScreen extends StatefulWidget {
  final AppLimit? limit;
  const CreateAppLimitScreen({Key? key, this.limit}) : super(key: key);

  @override
  State<CreateAppLimitScreen> createState() => _CreateAppLimitScreenState();
}

class _CreateAppLimitScreenState extends State<CreateAppLimitScreen> {
  final AppLimitService _appLimitService = AppLimitService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  int _limitMinutes = 60;
  List<String> _selectedPackageNames = [];
  Map<String, String?> _iconCache = {};
  bool _isStrictMode = false;
  String _strictModeLevel = 'NONE';
  String? _strictModePin;
  int _strictModeCooldownMinutes = 10;

  // Hard mode duration
  int _hardModeDays = 0;
  int _hardModeHours = 0;
  int _hardModeMinutes = 30;
  List<AppLimit> _existingLimits = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.limit?.name ?? '');
    if (widget.limit != null) {
      _limitMinutes = widget.limit!.limitMinutes;
      _selectedPackageNames =
          widget.limit!.apps.map((e) => e['packageName'] as String).toList();
      _isStrictMode = widget.limit!.isStrictMode;
      _strictModeLevel = widget.limit!.strictModeLevel;
      _strictModePin = widget.limit!.strictModePin;
      _strictModeCooldownMinutes =
          widget.limit!.strictModeCooldownMinutes ?? 10;

      if (_strictModeLevel == 'HARD' &&
          widget.limit!.hardModeDurationMinutes != null) {
        int total = widget.limit!.hardModeDurationMinutes!;
        _hardModeDays = total ~/ (24 * 60);
        _hardModeHours = (total % (24 * 60)) ~/ 60;
        _hardModeMinutes = total % 60;
      }
    }
    _fetchMissingIcons();
    _loadExistingLimits();
  }

  Future<void> _loadExistingLimits() async {
    final limits = await _appLimitService.getAllLimits();
    if (mounted) {
      setState(() => _existingLimits = limits);
    }
  }

  Future<void> _fetchMissingIcons() async {
    bool updated = false;
    for (var pkg in _selectedPackageNames) {
      if (!_iconCache.containsKey(pkg)) {
        final info = await _analyticsService.getAppInfo(pkg);
        if (info != null) {
          _iconCache[pkg] = info.iconBase64;
          updated = true;
        } else {
          _iconCache[pkg] = null;
        }
      }
    }
    if (updated && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPackageNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one app')),
      );
      return;
    }

    if (_limitMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily limit must be at least 1 minute')),
      );
      return;
    }

    // Resolve app names
    List<Map<String, String>> appsWithNames = [];
    for (var pkg in _selectedPackageNames) {
      final appInfo = await _analyticsService.getAppInfo(pkg);
      appsWithNames.add({
        'packageName': pkg,
        'appName': appInfo?.appName ?? pkg,
      });
    }

    int? hardModeTotal;
    if (_strictModeLevel == 'HARD') {
      hardModeTotal =
          (_hardModeDays * 24 * 60) + (_hardModeHours * 60) + _hardModeMinutes;
      if (hardModeTotal == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hard mode duration must be set')),
        );
        return;
      }
    }

    final limit = AppLimit(
      id: widget.limit?.id,
      name: _nameController.text,
      limitMinutes: _limitMinutes,
      isStrictMode: _isStrictMode,
      strictModeLevel: _strictModeLevel,
      strictModePin: _strictModePin,
      strictModeCooldownMinutes: _strictModeCooldownMinutes,
      hardModeDurationMinutes: hardModeTotal,
      apps: appsWithNames,
    );

    bool success;
    if (widget.limit == null) {
      final id = await _appLimitService.createLimit(limit);
      success = id != null;
    } else {
      success = await _appLimitService.updateLimit(limit);
    }

    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.limit == null ? 'Create App Limit' : 'Edit App Limit'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Limit Name',
                hintText: 'e.g., Social Media Limit',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'Selected Apps'),
            const SizedBox(height: 8),
            _buildAppSelectionTile(theme),
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'Daily Usage Limit'),
            const SizedBox(height: 8),
            _buildDurationPicker(theme),
            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'Strict Mode'),
            const SizedBox(height: 8),
            _buildStrictModeSelector(theme),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child:
                  Text(widget.limit == null ? 'Create Limit' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAppSelectionTile(ThemeData theme) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AppSelectionScreen()),
        );
        if (result != null && result is List<String>) {
          // Validate "One Limit Per App"
          final conflictingApps = <String>[];
          final validApps = <String>[];

          for (var pkg in result) {
            bool isConflict = false;
            for (var limit in _existingLimits) {
              // Skip current limit if we are editing it
              if (widget.limit != null && limit.id == widget.limit!.id)
                continue;

              // Check if app is in this limit
              if (limit.apps.any((a) => a['packageName'] == pkg)) {
                isConflict = true;
                break;
              }
            }
            if (isConflict) {
              conflictingApps.add(pkg);
            } else {
              validApps.add(pkg);
            }
          }

          if (conflictingApps.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Skipped ${conflictingApps.length} apps that already have limits set.',
                ),
                backgroundColor: theme.colorScheme.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }

          setState(() => _selectedPackageNames = validApps);
          _fetchMissingIcons();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.apps_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedPackageNames.isEmpty
                        ? 'Tap to select apps'
                        : '${_selectedPackageNames.length} apps selected',
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            if (_selectedPackageNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedPackageNames.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildAppIcon(_selectedPackageNames[index]),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(String packageName) {
    final iconBase64 = _iconCache[packageName];
    if (iconBase64 != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CustomImageWidget(
            imageUrl: 'data:image/png;base64,$iconBase64',
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey.shade200,
      child: const Icon(Icons.apps_rounded, size: 18, color: Colors.grey),
    );
  }

  Widget _buildDurationPicker(ThemeData theme) {
    int hours = _limitMinutes ~/ 60;
    int minutes = _limitMinutes % 60;

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: hours,
            decoration: const InputDecoration(
              labelText: 'Hours',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: List.generate(
                24,
                (i) => DropdownMenuItem(
                      value: i,
                      child: Text(i.toString()),
                    )),
            onChanged: (v) {
              setState(() {
                _limitMinutes = (v ?? 0) * 60 + minutes;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: minutes,
            decoration: const InputDecoration(
              labelText: 'Minutes',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: List.generate(
                60,
                (i) => DropdownMenuItem(
                      value: i,
                      child: Text(i.toString()),
                    )),
            onChanged: (v) {
              setState(() {
                _limitMinutes = hours * 60 + (v ?? 0);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStrictModeSelector(ThemeData theme) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          title: const Text('Enable Strict Mode'),
          subtitle: const Text('Prevent easy deletion of limits'),
          value: _isStrictMode,
          onChanged: (value) {
            setState(() {
              _isStrictMode = value;
              if (value)
                _strictModeLevel = 'EASY';
              else
                _strictModeLevel = 'NONE';
            });
          },
        ),
        if (_isStrictMode) ...[
          const SizedBox(height: 12),
          _buildLevelSelector(theme),
          const SizedBox(height: 16),
          if (_strictModeLevel == 'EASY') _buildPinInput(theme),
          if (_strictModeLevel == 'MEDIUM') _buildCooldownInput(theme),
          if (_strictModeLevel == 'HARD') _buildHardModeDurationInput(theme),
        ],
      ],
    );
  }

  Widget _buildLevelSelector(ThemeData theme) {
    return Row(
      children: [
        _buildLevelChip('EASY', Icons.pin_rounded, Colors.blue),
        const SizedBox(width: 8),
        _buildLevelChip('MEDIUM', Icons.timer_rounded, Colors.orange),
        const SizedBox(width: 8),
        _buildLevelChip('HARD', Icons.lock_rounded, Colors.red),
      ],
    );
  }

  Widget _buildLevelChip(String level, IconData icon, Color color) {
    final isSelected = _strictModeLevel == level;
    return Expanded(
      child: FilterChip(
        label: Text(
          level,
          style: TextStyle(
            color: isSelected ? Colors.white : color.withValues(alpha: 0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (val) => setState(() => _strictModeLevel = level),
        selectedColor: color,
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : color.withValues(alpha: 0.8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildPinInput(ThemeData theme) {
    return TextFormField(
      decoration: const InputDecoration(
        labelText: 'Unlock PIN',
        hintText: 'Enter 4-6 digit PIN',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      obscureText: true,
      onChanged: (val) => _strictModePin = val,
      validator: (val) => (_isStrictMode &&
              _strictModeLevel == 'EASY' &&
              (val == null || val.length < 4))
          ? 'Min 4 digits'
          : null,
    );
  }

  Widget _buildCooldownInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cooldown Duration (minutes)'),
        Slider(
          value: _strictModeCooldownMinutes.toDouble(),
          min: 1,
          max: 60,
          divisions: 59,
          onChanged: (val) =>
              setState(() => _strictModeCooldownMinutes = val.toInt()),
        ),
        Text('Wait $_strictModeCooldownMinutes minutes before unlocking'),
      ],
    );
  }

  Widget _buildHardModeDurationInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hard Mode Active For:'),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildTimeUnit('Days', 99, _hardModeDays,
                (v) => setState(() => _hardModeDays = v)),
            const SizedBox(width: 12),
            _buildTimeUnit('Hrs', 23, _hardModeHours,
                (v) => setState(() => _hardModeHours = v)),
            const SizedBox(width: 12),
            _buildTimeUnit('Mins', 59, _hardModeMinutes,
                (v) => setState(() => _hardModeMinutes = v)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Cannot delete until this period elapses.',
            style: TextStyle(color: Colors.red, fontSize: 12)),
      ],
    );
  }

  Widget _buildTimeUnit(
      String label, int max, int value, Function(int) onChanged) {
    return Expanded(
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            value: value,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder()),
            items: List.generate(max + 1,
                (i) => DropdownMenuItem(value: i, child: Text(i.toString()))),
            onChanged: (v) => onChanged(v ?? 0),
          ),
        ],
      ),
    );
  }
}
