import 'package:flutter/material.dart';

/// Dialog for setting up strict mode on a blocking session or schedule
/// Allows user to choose between Easy/Medium/Hard modes with appropriate configuration
class StrictModeSetupDialog extends StatefulWidget {
  final String? currentLevel; // NONE, EASY, MEDIUM, HARD
  final String? currentPin;
  final int? currentCooldownMinutes;

  const StrictModeSetupDialog({
    Key? key,
    this.currentLevel,
    this.currentPin,
    this.currentCooldownMinutes,
  }) : super(key: key);

  @override
  State<StrictModeSetupDialog> createState() => _StrictModeSetupDialogState();
}

class _StrictModeSetupDialogState extends State<StrictModeSetupDialog> {
  String _selectedLevel = 'NONE';
  String _pin = '';
  String _confirmPin = '';
  int _cooldownMinutes = 10;
  bool _showPinError = false;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.currentLevel ?? 'NONE';
    _cooldownMinutes = widget.currentCooldownMinutes ?? 10;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.security,
                      color: theme.colorScheme.primary, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Strict Mode',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Prevent yourself from stopping blocking early',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 24),

              // Level Selector
              _buildLevelOption(
                'NONE',
                'No Restriction',
                'Stop blocking anytime',
                Icons.lock_open,
                Colors.grey,
              ),
              SizedBox(height: 12),
              _buildLevelOption(
                'EASY',
                'PIN Protected',
                'Require PIN to stop',
                Icons.pin,
                Colors.blue,
              ),

              // PIN Entry (if Easy mode selected)
              if (_selectedLevel == 'EASY') ...[
                SizedBox(height: 16),
                _buildPinEntry(),
              ],

              SizedBox(height: 12),
              _buildLevelOption(
                'MEDIUM',
                'Cooldown Period',
                'Wait 5-20 mins before stopping',
                Icons.timer,
                Colors.orange,
              ),

              // Cooldown Selector (if Medium mode selected)
              if (_selectedLevel == 'MEDIUM') ...[
                SizedBox(height: 16),
                _buildCooldownSelector(),
              ],

              SizedBox(height: 12),
              _buildLevelOption(
                'HARD',
                'Absolute Lock',
                'Cannot stop until time expires',
                Icons.lock,
                Colors.red,
              ),

              // Warning for Hard mode
              if (_selectedLevel == 'HARD') ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You will NOT be able to stop this session early!',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _canSave() ? _handleSave : null,
                    child: Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelOption(
    String level,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isSelected = _selectedLevel == level;

    return InkWell(
      onTap: () => setState(() => _selectedLevel = level),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? color : theme.colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : null,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPinEntry() {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set PIN (4-6 digits)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'PIN',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            onChanged: (value) => setState(() => _pin = value),
          ),
          SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'Confirm PIN',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: _showPinError && _pin != _confirmPin
                  ? 'PINs do not match'
                  : null,
            ),
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            onChanged: (value) {
              setState(() {
                _confirmPin = value;
                _showPinError = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCooldownSelector() {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cooldown Duration',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildCooldownOption(5),
              SizedBox(width: 12),
              _buildCooldownOption(10),
              SizedBox(width: 12),
              _buildCooldownOption(20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCooldownOption(int minutes) {
    final theme = Theme.of(context);
    final isSelected = _cooldownMinutes == minutes;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _cooldownMinutes = minutes),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                '$minutes',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSave() {
    if (_selectedLevel == 'EASY') {
      return _pin.length >= 4 && _pin == _confirmPin;
    }
    return true;
  }

  void _handleSave() {
    Navigator.pop(context, {
      'level': _selectedLevel,
      'pin': _selectedLevel == 'EASY' ? _pin : null,
      'cooldownMinutes': _selectedLevel == 'MEDIUM' ? _cooldownMinutes : null,
    });
  }
}
