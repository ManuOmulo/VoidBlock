import 'package:flutter_test/flutter_test.dart';
import 'package:voidblock/services/app_limit_service.dart';

void main() {
  group('AppLimit Model', () {
    group('JSON Serialization', () {
      test('toJson serializes all fields correctly', () {
        final limit = AppLimit(
          id: 1,
          name: 'Social Media Limit',
          limitMinutes: 60,
          isActive: true,
          isStrictMode: true,
          strictModeLevel: 'MEDIUM',
          strictModePin: 'encrypted_pin',
          strictModeCooldownMinutes: 15,
          hardModeDurationMinutes: null,
          hardModeEndsAt: null,
          lastUnlockedAt: null,
          unlockedUntilMidnight: false,
          apps: [
            {'packageName': 'com.instagram.android', 'appName': 'Instagram'},
            {'packageName': 'com.twitter.android', 'appName': 'Twitter'},
          ],
        );

        final json = limit.toJson();

        expect(json['id'], equals(1));
        expect(json['name'], equals('Social Media Limit'));
        expect(json['limitMinutes'], equals(60));
        expect(json['isActive'], isTrue);
        expect(json['isStrictMode'], isTrue);
        expect(json['strictModeLevel'], equals('MEDIUM'));
        expect(json['strictModePin'], equals('encrypted_pin'));
        expect(json['strictModeCooldownMinutes'], equals(15));
        expect(json['apps'], hasLength(2));
      });

      test('fromJson deserializes all fields correctly', () {
        final json = {
          'id': 2,
          'name': 'Gaming Limit',
          'limitMinutes': 120,
          'isActive': false,
          'isStrictMode': false,
          'strictModeLevel': 'NONE',
          'strictModePin': null,
          'strictModeCooldownMinutes': null,
          'hardModeDurationMinutes': 1440,
          'hardModeEndsAt': 1704067200000,
          'lastUnlockedAt': null,
          'unlockedUntilMidnight': true,
          'apps': [
            {'packageName': 'com.game1', 'appName': 'Game 1'},
          ],
        };

        final limit = AppLimit.fromJson(json);

        expect(limit.id, equals(2));
        expect(limit.name, equals('Gaming Limit'));
        expect(limit.limitMinutes, equals(120));
        expect(limit.isActive, isFalse);
        expect(limit.isStrictMode, isFalse);
        expect(limit.strictModeLevel, equals('NONE'));
        expect(limit.hardModeDurationMinutes, equals(1440));
        expect(limit.hardModeEndsAt, equals(1704067200000));
        expect(limit.unlockedUntilMidnight, isTrue);
        expect(limit.apps, hasLength(1));
      });

      test('round-trip serialization preserves data', () {
        final original = AppLimit(
          id: 5,
          name: 'Test Limit',
          limitMinutes: 45,
          isActive: true,
          isStrictMode: true,
          strictModeLevel: 'HARD',
          apps: ['com.app1', 'com.app2'],
        );

        final json = original.toJson();
        final restored = AppLimit.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.limitMinutes, equals(original.limitMinutes));
        expect(restored.isActive, equals(original.isActive));
        expect(restored.isStrictMode, equals(original.isStrictMode));
        expect(restored.strictModeLevel, equals(original.strictModeLevel));
        expect(restored.apps.length, equals(original.apps.length));
      });
    });

    group('Default Values', () {
      test('fromJson handles missing optional fields with defaults', () {
        final minimalJson = {
          'name': 'Minimal Limit',
          'limitMinutes': 30,
        };

        final limit = AppLimit.fromJson(minimalJson);

        expect(limit.id, isNull);
        expect(limit.isActive, isTrue); // Default
        expect(limit.isStrictMode, isFalse); // Default
        expect(limit.strictModeLevel, equals('NONE')); // Default
        expect(limit.unlockedUntilMidnight, isFalse); // Default
        expect(limit.apps, isEmpty);
      });

      test('fromJson handles null apps list', () {
        final jsonWithNullApps = {
          'name': 'Test',
          'limitMinutes': 60,
          'apps': null,
        };

        final limit = AppLimit.fromJson(jsonWithNullApps);

        expect(limit.apps, isEmpty);
      });
    });

    group('Strict Mode Levels', () {
      test('NONE level - no protection', () {
        final limit = AppLimit(
          name: 'No Protection',
          limitMinutes: 60,
          isStrictMode: false,
          strictModeLevel: 'NONE',
        );

        final json = limit.toJson();
        expect(json['isStrictMode'], isFalse);
        expect(json['strictModeLevel'], equals('NONE'));
        expect(json['strictModePin'], isNull);
        expect(json['strictModeCooldownMinutes'], isNull);
      });

      test('EASY level - PIN protection', () {
        final limit = AppLimit(
          name: 'PIN Protected',
          limitMinutes: 60,
          isStrictMode: true,
          strictModeLevel: 'EASY',
          strictModePin: 'encrypted_1234',
        );

        final json = limit.toJson();
        expect(json['isStrictMode'], isTrue);
        expect(json['strictModeLevel'], equals('EASY'));
        expect(json['strictModePin'], isNotNull);
      });

      test('MEDIUM level - cooldown protection', () {
        final limit = AppLimit(
          name: 'Cooldown Protected',
          limitMinutes: 60,
          isStrictMode: true,
          strictModeLevel: 'MEDIUM',
          strictModeCooldownMinutes: 30,
        );

        final json = limit.toJson();
        expect(json['strictModeLevel'], equals('MEDIUM'));
        expect(json['strictModeCooldownMinutes'], equals(30));
      });

      test('HARD level - time-locked protection', () {
        final limit = AppLimit(
          name: 'Hard Locked',
          limitMinutes: 60,
          isStrictMode: true,
          strictModeLevel: 'HARD',
          hardModeDurationMinutes: 1440, // 24 hours
        );

        final json = limit.toJson();
        expect(json['strictModeLevel'], equals('HARD'));
        expect(json['hardModeDurationMinutes'], equals(1440));
      });
    });

    group('Limit Minutes Validation', () {
      test('common limit durations', () {
        // 30 minutes
        final limit30 = AppLimit(name: 'Test', limitMinutes: 30);
        expect(limit30.limitMinutes, equals(30));

        // 1 hour
        final limit60 = AppLimit(name: 'Test', limitMinutes: 60);
        expect(limit60.limitMinutes, equals(60));

        // 2 hours
        final limit120 = AppLimit(name: 'Test', limitMinutes: 120);
        expect(limit120.limitMinutes, equals(120));
      });

      test('edge case: very short limit', () {
        final shortLimit = AppLimit(name: 'Short', limitMinutes: 1);
        expect(shortLimit.limitMinutes, equals(1));
      });

      test('edge case: very long limit', () {
        final longLimit =
            AppLimit(name: 'Long', limitMinutes: 1440); // 24 hours
        expect(longLimit.limitMinutes, equals(1440));
      });
    });

    group('Unlock State', () {
      test('unlockedUntilMidnight flag', () {
        final unlockedLimit = AppLimit(
          name: 'Unlocked',
          limitMinutes: 60,
          unlockedUntilMidnight: true,
        );

        expect(unlockedLimit.unlockedUntilMidnight, isTrue);
      });

      test('lastUnlockedAt timestamp', () {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final limit = AppLimit(
          name: 'Recently Unlocked',
          limitMinutes: 60,
          lastUnlockedAt: timestamp,
        );

        expect(limit.lastUnlockedAt, equals(timestamp));
      });

      test('hardModeEndsAt timestamp', () {
        final futureTime =
            DateTime.now().add(Duration(hours: 24)).millisecondsSinceEpoch;
        final limit = AppLimit(
          name: 'Hard Locked',
          limitMinutes: 60,
          isStrictMode: true,
          strictModeLevel: 'HARD',
          hardModeEndsAt: futureTime,
        );

        expect(limit.hardModeEndsAt, equals(futureTime));
        expect(limit.hardModeEndsAt! > DateTime.now().millisecondsSinceEpoch,
            isTrue);
      });
    });

    group('Apps List', () {
      test('supports string package names', () {
        final limit = AppLimit(
          name: 'Test',
          limitMinutes: 60,
          apps: ['com.app1', 'com.app2', 'com.app3'],
        );

        expect(limit.apps, hasLength(3));
        expect(limit.apps[0], equals('com.app1'));
      });

      test('supports map with packageName and appName', () {
        final limit = AppLimit(
          name: 'Test',
          limitMinutes: 60,
          apps: [
            {'packageName': 'com.instagram.android', 'appName': 'Instagram'},
            {'packageName': 'com.facebook.katana', 'appName': 'Facebook'},
          ],
        );

        expect(limit.apps, hasLength(2));
        expect(limit.apps[0]['packageName'], equals('com.instagram.android'));
        expect(limit.apps[0]['appName'], equals('Instagram'));
      });

      test('empty apps list', () {
        final limit = AppLimit(
          name: 'Empty',
          limitMinutes: 60,
          apps: [],
        );

        expect(limit.apps, isEmpty);
      });
    });
  });
}
