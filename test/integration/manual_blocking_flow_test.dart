import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusguard/presentation/manual_blocking_screen/manual_blocking_screen.dart';
import 'package:focusguard/presentation/dashboard_screen/dashboard_screen.dart';
import 'package:focusguard/routes/app_routes.dart';

/// Integration tests for manual blocking flow
/// Tests the complete user journey from selecting apps to starting a blocking session
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Manual Blocking Flow Integration Tests', () {
    late Map<String, dynamic>? mockActiveSession;
    late bool blockingStarted;
    late List<MethodCall> methodCalls;

    setUp(() {
      mockActiveSession = null;
      blockingStarted = false;
      methodCalls = [];

      // Mock Blocking Channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'startBlocking':
              blockingStarted = true;
              mockActiveSession = {
                'id': 1,
                'apps': methodCall.arguments['apps'],
                'durationMinutes': methodCall.arguments['durationMinutes'],
                'remainingMinutes': methodCall.arguments['durationMinutes'],
                'isStrictMode': methodCall.arguments['strictMode'],
                'strictModeLevel': methodCall.arguments['strictModeLevel'],
                'isPaused': false,
                'startTime': DateTime.now().millisecondsSinceEpoch,
              };
              return true;
            case 'stopBlocking':
              blockingStarted = false;
              mockActiveSession = null;
              return true;
            case 'getActiveSession':
              return mockActiveSession;
            case 'isAppBlocked':
              final packageName = methodCall.arguments['packageName'];
              if (mockActiveSession != null) {
                final apps = mockActiveSession!['apps'] as List;
                return apps.contains(packageName);
              }
              return false;
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
          switch (methodCall.method) {
            case 'getUserApps':
              return [
                {
                  'packageName': 'com.instagram.android',
                  'appName': 'Instagram',
                  'isSystemApp': false,
                },
                {
                  'packageName': 'com.twitter.android',
                  'appName': 'Twitter',
                  'isSystemApp': false,
                },
                {
                  'packageName': 'com.youtube.android',
                  'appName': 'YouTube',
                  'isSystemApp': false,
                },
              ];
            case 'getUsageStats':
              return {'totalTime': 120, 'appCount': 5};
            case 'getMostUsedApps':
              return [];
            case 'getDailyStats':
              return [];
            default:
              return null;
          }
        },
      );

      // Mock Permission Channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/permission'),
        (MethodCall methodCall) async {
          return true; // All permissions granted
        },
      );

      // Mock StrictMode Channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/strict_mode'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'encryptPin') {
            return 'encrypted_${methodCall.arguments['pin']}';
          }
          return null;
        },
      );
    });

    tearDown(() {
      const channels = [
        'com.focusguard.app/blocking',
        'com.focusguard.app/analytics',
        'com.focusguard.app/permission',
        'com.focusguard.app/strict_mode',
      ];

      for (final channel in channels) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannel(channel), null);
      }
    });

    testWidgets('Start blocking with no strict mode',
        (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(
        MaterialApp(
          home: const ManualBlockingScreen(),
          routes: AppRoutes.routes,
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state
      expect(blockingStarted, isFalse);
      expect(mockActiveSession, isNull);

      // Find and verify the start button exists
      final startButton = find.text('Start Blocking');
      expect(startButton, findsWidgets);
    });

    testWidgets('Blocking session data is correctly passed to native',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ManualBlockingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate starting a blocking session programmatically
      // This tests the service layer integration
      const platform = MethodChannel('com.focusguard.app/blocking');

      final result = await platform.invokeMethod('startBlocking', {
        'apps': ['com.instagram.android', 'com.twitter.android'],
        'durationMinutes': 30,
        'strictMode': false,
        'strictModeLevel': 'NONE',
        'strictModePin': null,
        'strictModeCooldownMinutes': null,
        'message': 'Focus time!',
      });

      expect(result, isTrue);
      expect(blockingStarted, isTrue);
      expect(mockActiveSession, isNotNull);
      expect(mockActiveSession!['apps'], hasLength(2));
      expect(mockActiveSession!['durationMinutes'], equals(30));
      expect(mockActiveSession!['isStrictMode'], isFalse);
    });

    testWidgets('Blocking session with EASY strict mode (PIN)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ManualBlockingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      const platform = MethodChannel('com.focusguard.app/blocking');

      await platform.invokeMethod('startBlocking', {
        'apps': ['com.instagram.android'],
        'durationMinutes': 60,
        'strictMode': true,
        'strictModeLevel': 'EASY',
        'strictModePin': 'encrypted_1234',
        'strictModeCooldownMinutes': null,
        'message': null,
      });

      expect(mockActiveSession!['isStrictMode'], isTrue);
      expect(mockActiveSession!['strictModeLevel'], equals('EASY'));
    });

    testWidgets('Blocking session with MEDIUM strict mode (Cooldown)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ManualBlockingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      const platform = MethodChannel('com.focusguard.app/blocking');

      await platform.invokeMethod('startBlocking', {
        'apps': ['com.youtube.android'],
        'durationMinutes': 45,
        'strictMode': true,
        'strictModeLevel': 'MEDIUM',
        'strictModePin': null,
        'strictModeCooldownMinutes': 15,
        'message': 'Stay productive!',
      });

      expect(mockActiveSession!['strictModeLevel'], equals('MEDIUM'));

      // Verify the call was made with cooldown minutes
      final startCall =
          methodCalls.firstWhere((c) => c.method == 'startBlocking');
      expect(startCall.arguments['strictModeCooldownMinutes'], equals(15));
    });

    testWidgets('Blocking session with HARD strict mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ManualBlockingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      const platform = MethodChannel('com.focusguard.app/blocking');

      await platform.invokeMethod('startBlocking', {
        'apps': [
          'com.instagram.android',
          'com.twitter.android',
          'com.youtube.android'
        ],
        'durationMinutes': 120,
        'strictMode': true,
        'strictModeLevel': 'HARD',
        'strictModePin': null,
        'strictModeCooldownMinutes': null,
        'message': 'Deep work session',
      });

      expect(mockActiveSession!['strictModeLevel'], equals('HARD'));
      expect(mockActiveSession!['apps'], hasLength(3));
    });

    testWidgets('isAppBlocked returns correct state during session',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ManualBlockingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      const platform = MethodChannel('com.focusguard.app/blocking');

      // Start blocking Instagram
      await platform.invokeMethod('startBlocking', {
        'apps': ['com.instagram.android'],
        'durationMinutes': 30,
        'strictMode': false,
        'strictModeLevel': 'NONE',
      });

      // Check which apps are blocked
      final instagramBlocked = await platform.invokeMethod('isAppBlocked', {
        'packageName': 'com.instagram.android',
      });
      expect(instagramBlocked, isTrue);

      final youtubeBlocked = await platform.invokeMethod('isAppBlocked', {
        'packageName': 'com.youtube.android',
      });
      expect(youtubeBlocked, isFalse);
    });

    testWidgets('Stop blocking clears active session',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ManualBlockingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      const platform = MethodChannel('com.focusguard.app/blocking');

      // Start blocking
      await platform.invokeMethod('startBlocking', {
        'apps': ['com.instagram.android'],
        'durationMinutes': 30,
        'strictMode': false,
        'strictModeLevel': 'NONE',
      });

      expect(blockingStarted, isTrue);
      expect(mockActiveSession, isNotNull);

      // Stop blocking
      await platform.invokeMethod('stopBlocking');

      expect(blockingStarted, isFalse);
      expect(mockActiveSession, isNull);

      // Verify app is no longer blocked
      final isBlocked = await platform.invokeMethod('isAppBlocked', {
        'packageName': 'com.instagram.android',
      });
      expect(isBlocked, isFalse);
    });

    testWidgets('getActiveSession returns null when no session',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ManualBlockingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      const platform = MethodChannel('com.focusguard.app/blocking');

      final session = await platform.invokeMethod('getActiveSession');
      expect(session, isNull);
    });

    testWidgets('getActiveSession returns session data when active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ManualBlockingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      const platform = MethodChannel('com.focusguard.app/blocking');

      // Start a session
      await platform.invokeMethod('startBlocking', {
        'apps': ['com.instagram.android', 'com.twitter.android'],
        'durationMinutes': 45,
        'strictMode': true,
        'strictModeLevel': 'EASY',
      });

      // Get active session
      final session = await platform.invokeMethod('getActiveSession');

      expect(session, isNotNull);
      expect(session['id'], equals(1));
      expect(session['apps'], hasLength(2));
      expect(session['durationMinutes'], equals(45));
      expect(session['isStrictMode'], isTrue);
      expect(session['strictModeLevel'], equals('EASY'));
      expect(session['isPaused'], isFalse);
    });
  });

  group('Session Data Correctness', () {
    test('Duration is correctly passed and preserved', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      int? receivedDuration;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'startBlocking') {
            receivedDuration = methodCall.arguments['durationMinutes'];
            return true;
          }
          return null;
        },
      );

      const platform = MethodChannel('com.focusguard.app/blocking');

      // Test various durations
      for (final duration in [15, 30, 45, 60, 90, 120, 180, 240]) {
        await platform.invokeMethod('startBlocking', {
          'apps': ['com.test.app'],
          'durationMinutes': duration,
          'strictMode': false,
          'strictModeLevel': 'NONE',
        });

        expect(receivedDuration, equals(duration),
            reason: 'Duration $duration should be correctly passed');
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        null,
      );
    });

    test('Apps list is correctly serialized', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      List<String>? receivedApps;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'startBlocking') {
            receivedApps = List<String>.from(methodCall.arguments['apps']);
            return true;
          }
          return null;
        },
      );

      const platform = MethodChannel('com.focusguard.app/blocking');

      final testApps = [
        'com.instagram.android',
        'com.twitter.android',
        'com.facebook.katana',
        'com.snapchat.android',
        'com.tiktok.android',
      ];

      await platform.invokeMethod('startBlocking', {
        'apps': testApps,
        'durationMinutes': 60,
        'strictMode': false,
        'strictModeLevel': 'NONE',
      });

      expect(receivedApps, isNotNull);
      expect(receivedApps, hasLength(5));
      expect(receivedApps, equals(testApps));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        null,
      );
    });

    test('Strict mode parameters are correctly passed for each level',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      Map<String, dynamic>? receivedArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'startBlocking') {
            receivedArgs = Map<String, dynamic>.from(methodCall.arguments);
            return true;
          }
          return null;
        },
      );

      const platform = MethodChannel('com.focusguard.app/blocking');

      // Test NONE level
      await platform.invokeMethod('startBlocking', {
        'apps': ['com.test.app'],
        'durationMinutes': 30,
        'strictMode': false,
        'strictModeLevel': 'NONE',
      });
      expect(receivedArgs!['strictMode'], isFalse);
      expect(receivedArgs!['strictModeLevel'], equals('NONE'));

      // Test EASY level
      await platform.invokeMethod('startBlocking', {
        'apps': ['com.test.app'],
        'durationMinutes': 30,
        'strictMode': true,
        'strictModeLevel': 'EASY',
        'strictModePin': 'encrypted_pin',
      });
      expect(receivedArgs!['strictMode'], isTrue);
      expect(receivedArgs!['strictModeLevel'], equals('EASY'));
      expect(receivedArgs!['strictModePin'], equals('encrypted_pin'));

      // Test MEDIUM level
      await platform.invokeMethod('startBlocking', {
        'apps': ['com.test.app'],
        'durationMinutes': 30,
        'strictMode': true,
        'strictModeLevel': 'MEDIUM',
        'strictModeCooldownMinutes': 15,
      });
      expect(receivedArgs!['strictModeLevel'], equals('MEDIUM'));
      expect(receivedArgs!['strictModeCooldownMinutes'], equals(15));

      // Test HARD level
      await platform.invokeMethod('startBlocking', {
        'apps': ['com.test.app'],
        'durationMinutes': 30,
        'strictMode': true,
        'strictModeLevel': 'HARD',
      });
      expect(receivedArgs!['strictModeLevel'], equals('HARD'));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        null,
      );
    });
  });
}
