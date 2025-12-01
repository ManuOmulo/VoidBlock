import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog for entering PIN to unlock strict mode (Easy level)
/// Shows numeric keypad and handles PIN validation
class PinEntryDialog extends StatefulWidget {
  final int? remainingAttempts;
  final int? lockoutSeconds;

  const PinEntryDialog({
    Key? key,
    this.remainingAttempts,
    this.lockoutSeconds,
  }) : super(key: key);

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  String _pin = '';
  final int _pinLength = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show lockout message if locked
    if (widget.lockoutSeconds != null && widget.lockoutSeconds! > 0) {
      return _buildLockoutDialog(theme);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Icon(
              Icons.lock_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            SizedBox(height: 16),
            Text(
              'Enter PIN',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enter your PIN to stop blocking',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            // Remaining attempts warning
            if (widget.remainingAttempts != null &&
                widget.remainingAttempts! <= 3) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '${widget.remainingAttempts} attempts remaining',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 24),

            // PIN Display
            _buildPinDisplay(theme),

            SizedBox(height: 24),

            // Numeric Keypad
            _buildKeypad(theme),

            SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _pin.length >= 4 ? _handleSubmit : null,
                  child: Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockoutDialog(ThemeData theme) {
    final minutes = (widget.lockoutSeconds! / 60).ceil();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: 16),
            Text(
              'Too Many Attempts',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'You have been locked out for ${minutes} minutes due to too many failed PIN attempts.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDisplay(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        final isFilled = index < _pin.length;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 6),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(ThemeData theme) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], theme),
        SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6'], theme),
        SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9'], theme),
        SizedBox(height: 12),
        _buildKeypadRow(['', '0', 'back'], theme),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key.isEmpty) return SizedBox(width: 70, height: 60);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: key == 'back'
              ? _buildKeypadButton(
                  null,
                  Icons.backspace_outlined,
                  theme,
                  _handleBackspace,
                )
              : _buildKeypadButton(
                  key,
                  null,
                  theme,
                  () => _handleNumberPress(key),
                ),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton(
    String? text,
    IconData? icon,
    ThemeData theme,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: theme.colorScheme.onSurfaceVariant)
              : Text(
                  text!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  void _handleNumberPress(String number) {
    if (_pin.length < _pinLength) {
      HapticFeedback.selectionClick();
      setState(() => _pin += number);

      // Auto-submit when PIN is complete
      if (_pin.length == _pinLength) {
        Future.delayed(Duration(milliseconds: 300), _handleSubmit);
      }
    }
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  void _handleSubmit() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _pin);
  }
}
