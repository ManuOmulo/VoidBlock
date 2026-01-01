---
description: How to implement new features safely without breaking existing functionality
---

# Implementing New Features

This workflow ensures new code integrates safely with existing implementation and all tests pass.

## Pre-Implementation Checklist

1. **Run existing tests first** to establish a baseline:

   ```bash
   flutter test test/models/ test/services/
   ```

   // turbo
   All tests must pass before starting.

2. **Review exported contracts** before modifying any service:

   - Check `lib/services/` for existing method signatures
   - Check `android/app/src/main/kotlin/.../channels/` for native method contracts
   - DO NOT change existing method signatures without updating all callers

3. **Check for strict mode protection** before modifying blocking/schedule/limit deletion:
   - HARD mode prevents deletion during active sessions
   - Tests verify this behavior - don't bypass it

## Implementation Rules

### Adding New Features

1. **Extend, don't modify** existing classes when possible
2. **Add new methods** rather than changing existing method signatures
3. **New fields must be optional** or have defaults for backward compatibility
4. **Add corresponding tests** for any new functionality

### Modifying Existing Code

1. **Identify all callers** before changing any function:

   ```bash
   grep -r "functionName" lib/
   ```

   // turbo

2. **Update tests first** to reflect new expected behavior (TDD approach)
3. **Run tests after each significant change**:
   ```bash
   flutter test test/services/
   ```
   // turbo

### Database Changes

1. **NEVER delete columns** from existing entities
2. **New columns must be nullable** or have defaults
3. **Test migration by running on existing data**

## Post-Implementation Verification

1. **Run the full test suite**:

   ```bash
   flutter test
   ```

   // turbo

2. **Run native tests** if Kotlin code was modified:

   ```bash
   cd android && ./gradlew test
   ```

   // turbo

3. **Manual verification** on device for critical flows:
   - Start a manual blocking session
   - Create/edit a schedule
   - Set an app limit
   - Verify strict mode unlock works per level

## Critical Files - Handle With Care

These files have complex logic - extra caution required:

- `BlockingChannel.kt` - Session lifecycle
- `StrictModeManager.kt` - Unlock enforcement
- `ScheduleManager.kt` - Time-based activation
- `AppDatabase.kt` - Database migrations

## If Tests Fail After Changes

1. **Don't modify the test to pass** - understand WHY it failed
2. **Check if you changed a contract** that other code depends on
3. **Revert and try a different approach** if the failure indicates a design problem
