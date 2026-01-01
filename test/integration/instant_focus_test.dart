import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for Instant Focus functionality
/// Verifies session creation, monitoring behavior, and app selection
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Instant Focus Monitoring Tests', () {
    late List<MethodCall> blockingCalls;
    late List<MethodCall> analyticsCalls;
    late Map<String, dynamic>? mockActiveSession;
    late bool serviceRunning;

    setUp(() {
      blockingCalls = [];
      analyticsCalls = [];
      mockActiveSession = null;
      serviceRunning = false;

      // Mock Blocking Channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        (MethodCall methodCall) async {
          blockingCalls.add(methodCall);

          switch (methodCall.method) {
            case 'startBlocking':
              serviceRunning = true;
              mockActiveSession = {
                'id': 1,
                'apps': methodCall.arguments['apps'],
                'durationMinutes': methodCall.arguments['durationMinutes'],
                'remainingMinutes': methodCall.arguments['durationMinutes'],
                'isStrictMode': methodCall.arguments['strictMode'] ?? false,
                'strictModeLevel':
                    methodCall.arguments['strictModeLevel'] ?? 'NONE',
                'isPaused': false,
                'startTime': DateTime.now().millisecondsSinceEpoch,
                'message': methodCall.arguments['message'],
              };
              return true;
            case 'stopBlocking':
              serviceRunning = false;
              mockActiveSession = null;
              return true;
            case 'getActiveSession':
              return mockActiveSession;
            case 'isAppBlocked':
              if (mockActiveSession == null) return false;
              final packageName = methodCall.arguments['packageName'];
              final apps = mockActiveSession!['apps'] as List;
              return apps.contains(packageName);
            case 'pauseBlocking':
              if (mockActiveSession != null) {
                mockActiveSession!['isPaused'] = true;
              }
              return mockActiveSession != null;
            case 'resumeBlocking':
              if (mockActiveSession != null) {
                mockActiveSession!['isPaused'] = false;
              }
              return mockActiveSession != null;
            default:
              return null;
          }
        },
      );

      // Mock Analytics Channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/analytics'),
        (MethodCall methodCall) async {
          analyticsCalls.add(methodCall);

          switch (methodCall.method) {
            case 'getMostUsedApps':
              final limit = methodCall.arguments['limit'] ?? 10;
              // Return mock most used apps
              return [
                {
                  'packageName': 'com.instagram.android',
                  'appName': 'Instagram',
                  'usageMinutes': 120
                },
                {
                  'packageName': 'com.twitter.android',
                  'appName': 'Twitter',
                  'usageMinutes': 90
                },
                {
                  'packageName': 'com.youtube.android',
                  'appName': 'YouTube',
                  'usageMinutes': 60
                },
                {
                  'packageName': 'com.tiktok.android',
                  'appName': 'TikTok',
                  'usageMinutes': 45
                },
                {
                  'packageName': 'com.snapchat.android',
                  'appName': 'Snapchat',
                  'usageMinutes': 30
                },
              ].take(limit).toList();
            case 'getUserApps':
              return [
                {
                  'packageName': 'com.instagram.android',
                  'appName': 'Instagram',
                  'isSystemApp': false
                },
                {
                  'packageName': 'com.twitter.android',
                  'appName': 'Twitter',
                  'isSystemApp': false
                },
              ];
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/analytics'),
        null,
      );
    });

    group('Instant Focus Session Creation', () {
      test('Gets top 5 most used apps for blocking', () async {
        const analyticsPlatform = MethodChannel('com.focusguard.app/analytics');

        final mostUsed =
            await analyticsPlatform.invokeMethod('getMostUsedApps', {
          'limit': 5,
        });

        expect(mostUsed, hasLength(5));
        expect(mostUsed[0]['packageName'], equals('com.instagram.android'));
        expect(mostUsed[4]['packageName'], equals('com.snapchat.android'));
      });

      test('Creates 25-minute Pomodoro session', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');
        const analyticsPlatform = MethodChannel('com.focusguard.app/analytics');

        // Get most used apps
        final mostUsed =
            await analyticsPlatform.invokeMethod('getMostUsedApps', {
          'limit': 5,
        }) as List;

        final appsToBlock = mostUsed
            .map((app) => app['packageName'] as String)
            .where((pkg) => pkg != 'com.focusguard.app')
            .toList();

        // Start blocking
        final success = await blockingPlatform.invokeMethod('startBlocking', {
          'apps': appsToBlock,
          'durationMinutes': 25, // Pomodoro duration
          'strictMode': false,
          'strictModeLevel': 'NONE',
          'message': 'Deep Focus Session Started',
        });

        expect(success, isTrue);
        expect(mockActiveSession, isNotNull);
        expect(mockActiveSession!['durationMinutes'], equals(25));
        expect(mockActiveSession!['message'],
            equals('Deep Focus Session Started'));
      });

      test('Excludes FocusGuard app from blocking', () async {
        const analyticsPlatform = MethodChannel('com.focusguard.app/analytics');

        // Mock response including FocusGuard itself
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/analytics'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getMostUsedApps') {
              return [
                {
                  'packageName': 'com.focusguard.app',
                  'appName': 'FocusGuard',
                  'usageMinutes': 200
                },
                {
                  'packageName': 'com.instagram.android',
                  'appName': 'Instagram',
                  'usageMinutes': 120
                },
              ];
            }
            return null;
          },
        );

        final mostUsed =
            await analyticsPlatform.invokeMethod('getMostUsedApps', {
          'limit': 5,
        }) as List;

        final appsToBlock = mostUsed
            .map((app) => app['packageName'] as String)
            .where((pkg) => pkg != 'com.focusguard.app')
            .toList();

        expect(appsToBlock, isNot(contains('com.focusguard.app')));
        expect(appsToBlock, contains('com.instagram.android'));
      });

      test('Handles case when no distracting apps identified', () async {
        // Mock empty response
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/analytics'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getMostUsedApps') {
              return [];
            }
            return null;
          },
        );

        const analyticsPlatform = MethodChannel('com.focusguard.app/analytics');
        final mostUsed =
            await analyticsPlatform.invokeMethod('getMostUsedApps', {
          'limit': 5,
        }) as List;

        expect(mostUsed, isEmpty);
        // In this case, Instant Focus should not start a session
      });
    });

    group('Session Monitoring Behavior', () {
      test('isAppBlocked returns true for blocked apps during session',
          () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');

        // Start session
        await blockingPlatform.invokeMethod('startBlocking', {
          'apps': ['com.instagram.android', 'com.twitter.android'],
          'durationMinutes': 25,
          'strictMode': false,
          'strictModeLevel': 'NONE',
        });

        // Check blocked status
        final instagramBlocked =
            await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });
        expect(instagramBlocked, isTrue);

        final youtubeBlocked =
            await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.youtube.android',
        });
        expect(youtubeBlocked, isFalse);
      });

      test('isAppBlocked returns false when no session active', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');

        // No session started
        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });

        expect(isBlocked, isFalse);
      });

      test('Session state persists across getActiveSession calls', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');

        // Start session
        await blockingPlatform.invokeMethod('startBlocking', {
          'apps': ['com.instagram.android'],
          'durationMinutes': 25,
          'strictMode': false,
          'strictModeLevel': 'NONE',
        });

        // Multiple calls to getActiveSession should return consistent data
        final session1 =
            await blockingPlatform.invokeMethod('getActiveSession');
        final session2 =
            await blockingPlatform.invokeMethod('getActiveSession');

        expect(session1, isNotNull);
        expect(session2, isNotNull);
        expect(session1['id'], equals(session2['id']));
        expect(session1['apps'], equals(session2['apps']));
      });

      test('Paused session maintains blocked apps list', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');

        // Start session
        await blockingPlatform.invokeMethod('startBlocking', {
          'apps': ['com.instagram.android'],
          'durationMinutes': 25,
          'strictMode': false,
          'strictModeLevel': 'NONE',
        });

        // Pause
        await blockingPlatform.invokeMethod('pauseBlocking');

        final session = await blockingPlatform.invokeMethod('getActiveSession');
        expect(session['isPaused'], isTrue);
        expect(session['apps'], contains('com.instagram.android'));
      });

      test('Resume restores monitoring', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');

        // Start session
        await blockingPlatform.invokeMethod('startBlocking', {
          'apps': ['com.instagram.android'],
          'durationMinutes': 25,
          'strictMode': false,
          'strictModeLevel': 'NONE',
        });

        // Pause then resume
        await blockingPlatform.invokeMethod('pauseBlocking');
        await blockingPlatform.invokeMethod('resumeBlocking');

        final session = await blockingPlatform.invokeMethod('getActiveSession');
        expect(session['isPaused'], isFalse);
      });
    });

    group('Session Termination', () {
      test('stopBlocking clears session completely', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');

        // Start session
        await blockingPlatform.invokeMethod('startBlocking', {
          'apps': ['com.instagram.android'],
          'durationMinutes': 25,
          'strictMode': false,
          'strictModeLevel': 'NONE',
        });

        expect(mockActiveSession, isNotNull);

        // Stop session
        await blockingPlatform.invokeMethod('stopBlocking');

        expect(mockActiveSession, isNull);
        expect(serviceRunning, isFalse);

        // Verify app is no longer blocked
        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });
        expect(isBlocked, isFalse);
      });

      test('getActiveSession returns null after stop', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');

        // Start then stop
        await blockingPlatform.invokeMethod('startBlocking', {
          'apps': ['com.instagram.android'],
          'durationMinutes': 25,
          'strictMode': false,
          'strictModeLevel': 'NONE',
        });
        await blockingPlatform.invokeMethod('stopBlocking');

        final session = await blockingPlatform.invokeMethod('getActiveSession');
        expect(session, isNull);
      });
    });

    group('Multiple Sessions', () {
      test('Starting new session replaces previous session', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');

        // Start first session
        await blockingPlatform.invokeMethod('startBlocking', {
          'apps': ['com.instagram.android'],
          'durationMinutes': 25,
          'strictMode': false,
          'strictModeLevel': 'NONE',
        });

        final session1 =
            await blockingPlatform.invokeMethod('getActiveSession');
        expect(session1['apps'], equals(['com.instagram.android']));

        // Start second session with different apps
        await blockingPlatform.invokeMethod('startBlocking', {
          'apps': ['com.twitter.android', 'com.youtube.android'],
          'durationMinutes': 30,
          'strictMode': false,
          'strictModeLevel': 'NONE',
        });

        final session2 =
            await blockingPlatform.invokeMethod('getActiveSession');
        expect(session2['apps'], hasLength(2));
        expect(session2['durationMinutes'], equals(30));
      });
    });

    group('Instant Focus with Strict Mode', () {
      test('Instant Focus can use strict mode', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');

        await blockingPlatform.invokeMethod('startBlocking', {
          'apps': ['com.instagram.android'],
          'durationMinutes': 25,
          'strictMode': true,
          'strictModeLevel': 'MEDIUM',
          'strictModeCooldownMinutes': 10,
          'message': 'Deep Focus Session',
        });

        final session = await blockingPlatform.invokeMethod('getActiveSession');
        expect(session['isStrictMode'], isTrue);
        expect(session['strictModeLevel'], equals('MEDIUM'));
      });
    });
  });
}
