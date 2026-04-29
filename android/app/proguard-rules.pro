# Flutter obfuscation
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Room Database
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>(...);
}
-keep class androidx.room.concurrent.RoomMq { *; }
-keep class androidx.room.concurrent.PooledConnection { *; }
-keep class androidx.room.concurrent.ConnectionEvent { *; }
-keep class androidx.room.Dao { *; }
-keep class androidx.room.Entity { *; }
-keep class * extends androidx.room.RoomDatabase
-keep class com.voidblock.app.data.database.** { *; }

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepnames class kotlinx.coroutines.android.AndroidExceptionPreHandler {}
-keepnames class kotlinx.coroutines.android.AndroidDispatcherFactory {}
-keep class kotlinx.coroutines.android.** { *; }

# Keep Flutter/Native channel classes
-keep class com.voidblock.app.channels.** { *; }
-keep class com.voidblock.app.services.** { *; }

# WorkManager
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# Lifecycle components
-keep class androidx.lifecycle.** { *; }