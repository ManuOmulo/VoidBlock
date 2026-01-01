# FocusGuard

A powerful Android productivity app built with Flutter that helps you stay focused by blocking distracting apps. Features manual blocking, scheduled sessions, app usage limits, and multiple strict mode levels for enforced focus.

## ✨ Features

### 🔒 Manual Blocking

Start instant focus sessions with customizable duration and app selection.

### ⚡ Instant Focus

One-tap Pomodoro sessions (25 min) blocking your top 5 most-used apps.

### 📅 Scheduled Blocking

Create recurring schedules to automatically block apps during work hours, study time, or sleep.

### ⏱️ App Limits

Set daily usage limits for individual apps or groups. Get blocked when you exceed your limit.

### 🛡️ Strict Mode Levels

| Level  | Unlock Method                  |
| ------ | ------------------------------ |
| NONE   | Stop anytime                   |
| EASY   | PIN required                   |
| MEDIUM | Wait through cooldown period   |
| HARD   | Cannot stop until session ends |

### 📊 Analytics & Insights

Track your usage patterns, productivity scores, and get personalized recommendations.

---

## 📋 Prerequisites

- Flutter SDK (^3.29.2)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Android SDK (minSdk 26, targetSdk 35)

## 🛠️ Installation

```bash
# Install dependencies
flutter pub get

# Run the application
flutter run
```

---

## 📁 Project Structure

```
FocusGuard/
├── lib/                          # Flutter source code
│   ├── core/                     # Core utilities and exports
│   ├── presentation/             # UI screens and widgets
│   │   ├── dashboard_screen/     # Main hub with stats & quick actions
│   │   ├── manual_blocking_screen/  # Start instant blocking
│   │   ├── schedule_creator_screen/ # Create blocking schedules
│   │   ├── schedule_management_screen/ # Manage schedules
│   │   ├── app_limits/           # Set usage limits
│   │   ├── insights_screen/      # Analytics & reports
│   │   ├── strict_mode_lock_screen/  # Unlock screen during strict mode
│   │   └── settings_screen/      # App configuration
│   ├── services/                 # Business logic & native bridge
│   │   ├── blocking_service.dart   # Start/stop blocking sessions
│   │   ├── schedule_service.dart   # Schedule CRUD operations
│   │   ├── app_limit_service.dart  # Limit management & usage
│   │   ├── strict_mode_service.dart # Strict mode unlock flows
│   │   ├── analytics_service.dart  # Usage stats & insights
│   │   └── permission_service.dart # Android permissions
│   ├── routes/                   # App navigation
│   ├── theme/                    # Light/dark theme configuration
│   ├── widgets/                  # Reusable UI components
│   └── main.dart                 # Application entry point
│
├── android/app/src/main/kotlin/com/focusguard/app/  # Native Android
│   ├── channels/                 # MethodChannel implementations
│   │   ├── BlockingChannel.kt    # Session management
│   │   ├── ScheduleChannel.kt    # Schedule operations
│   │   ├── AppLimitChannel.kt    # Limit management
│   │   ├── StrictModeChannel.kt  # Unlock enforcement
│   │   └── AnalyticsChannel.kt   # Usage data
│   ├── services/
│   │   └── BlockingService.kt    # Foreground monitoring service
│   ├── data/database/            # Room database (DAOs, Entities)
│   ├── utils/                    # Native utilities
│   │   ├── StrictModeManager.kt  # Strict mode enforcement
│   │   ├── ScheduleManager.kt    # Schedule activation logic
│   │   └── ProductivityCalculator.kt # Score calculations
│   ├── activities/
│   │   └── BlockingOverlayActivity.kt # Shown when blocked app opened
│   └── receivers/                # Alarm & boot receivers
│
├── test/                         # Test suite
│   ├── models/                   # Model unit tests
│   ├── services/                 # Service unit tests (mocked channels)
│   └── integration/              # End-to-end flow tests
│
└── .agent/workflows/             # AI assistant workflows
    └── implement-feature.md      # Safe feature implementation guide
```

---

## 🧪 Testing

### Run All Flutter Tests

```bash
flutter test
```

### Run Model & Service Tests Only

```bash
flutter test test/models/ test/services/
```

### Run Integration Tests

```bash
flutter test test/integration/
```

### Run Native Kotlin Tests

```bash
cd android && ./gradlew test
```

### Test Coverage Summary

| Category            | Files | Tests | Coverage                                                             |
| ------------------- | ----- | ----- | -------------------------------------------------------------------- |
| **Models**          | 2     | 33    | Schedule, AppLimit serialization                                     |
| **Services**        | 4     | 73    | BlockingService, ScheduleService, AppLimitService, StrictModeService |
| **Integration**     | 4     | 59    | Blocking flows, schedules, limits, Instant Focus                     |
| **Native (Kotlin)** | 3     | 47    | StrictModeManager, ScheduleManager, ProductivityCalculator           |

---

## 🔐 Required Permissions

| Permission               | Purpose                                |
| ------------------------ | -------------------------------------- |
| `USAGE_STATS`            | Track app usage times                  |
| `OVERLAY`                | Show blocking screen over other apps   |
| `FOREGROUND_SERVICE`     | Monitor apps in background             |
| `POST_NOTIFICATIONS`     | Show session notifications             |
| `SCHEDULE_EXACT_ALARM`   | Trigger scheduled blocks reliably      |
| `RECEIVE_BOOT_COMPLETED` | Resume monitoring after device restart |

---

## 📱 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter UI Layer                        │
│  (Screens, Widgets, State Management)                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Services                          │
│  (BlockingService, ScheduleService, AppLimitService, etc.)  │
└─────────────────────────────────────────────────────────────┘
                              │
                    MethodChannel Bridge
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Native Android (Kotlin)                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Channels   │  │   Utils     │  │  Foreground Service │  │
│  │ (API layer) │  │ (Managers)  │  │    (Monitoring)     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                              │                               │
│                              ▼                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Room Database (SQLite)                      ││
│  │  Sessions | Schedules | Limits | UsageLogs | BlockedApps ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Build

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

---

## 🙏 Acknowledgments

- Built with [Flutter](https://flutter.dev) & [Dart](https://dart.dev)
- Native Android powered by Kotlin & Room Database
- Styled with Material Design 3
