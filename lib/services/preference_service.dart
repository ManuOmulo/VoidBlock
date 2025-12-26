import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static final PreferenceService _instance = PreferenceService._internal();
  factory PreferenceService() => _instance;
  PreferenceService._internal();

  static const String _keyPomodoroDuration = 'pomodoro_duration';
  static const String _keyBreakDuration = 'break_duration';
  static const String _keyEssentialApps = 'essential_apps';
  static const String _keyNudgesEnabled = 'nudges_enabled';
  static const String _keyNudgeThreshold = 'nudge_threshold';

  /// Get preferred pomodoro duration in minutes
  Future<int> getPomodoroDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPomodoroDuration) ?? 25;
  }

  /// Set preferred pomodoro duration
  Future<void> setPomodoroDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPomodoroDuration, minutes);
  }

  /// Get preferred break duration in minutes
  Future<int> getBreakDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBreakDuration) ?? 5;
  }

  /// Set preferred break duration
  Future<void> setBreakDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBreakDuration, minutes);
  }

  /// Get list of essential apps (whitelist)
  Future<List<String>> getEssentialApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyEssentialApps) ?? [];
  }

  /// Set essential apps
  Future<void> setEssentialApps(List<String> packageNames) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyEssentialApps, packageNames);
  }

  /// Check if a package is essential
  Future<bool> isEssentialApp(String packageName) async {
    final essentials = await getEssentialApps();
    return essentials.contains(packageName);
  }

  /// Check if nudges are enabled
  Future<bool> getNudgesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNudgesEnabled) ?? true;
  }

  /// Set nudges toggle
  Future<void> setNudgesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNudgesEnabled, enabled);
  }

  /// Get nudge threshold in minutes
  Future<int> getNudgeThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNudgeThreshold) ?? 20;
  }

  /// Set nudge threshold
  Future<void> setNudgeThreshold(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNudgeThreshold, minutes);
  }
}
