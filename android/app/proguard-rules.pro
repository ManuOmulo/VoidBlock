-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
# Keep Stripe classes
-keep class com.stripe.** { *; }

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