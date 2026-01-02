package com.voidblock.app.data.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.voidblock.app.data.database.dao.*
import com.voidblock.app.data.database.entities.*

/**
 * Main Room database for VoidBlock application
 * Manages all persistent data for schedules, blocked apps, usage tracking, and strict mode
 */
@Database(
    entities = [
        ScheduleEntity::class,
        BlockedAppEntity::class,
        UsageLogEntity::class,
        StrictModeSessionEntity::class,
        BlockingSessionEntity::class,
        SessionBlockedAppEntity::class,
        StrictModePreferencesEntity::class,
        AppLimitEntity::class,
        AppLimitAppEntity::class,
        FocusSessionEntity::class
    ],
    version = 8,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    
    abstract fun scheduleDao(): ScheduleDao
    abstract fun blockedAppDao(): BlockedAppDao
    abstract fun usageLogDao(): UsageLogDao
    abstract fun strictModeSessionDao(): StrictModeSessionDao
    abstract fun blockingSessionDao(): BlockingSessionDao
    abstract fun sessionBlockedAppDao(): SessionBlockedAppDao
    abstract fun strictModePreferencesDao(): StrictModePreferencesDao
    abstract fun appLimitDao(): AppLimitDao
    abstract fun focusSessionDao(): FocusSessionDao
    
    companion object {
        private const val DATABASE_NAME = "voidblock_database"
        
        @Volatile
        private var INSTANCE: AppDatabase? = null
        
        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: buildDatabase(context).also { INSTANCE = it }
            }
        }
        
        private fun buildDatabase(context: Context): AppDatabase {
            return Room.databaseBuilder(
                context.applicationContext,
                AppDatabase::class.java,
                DATABASE_NAME
            )
                .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6, MIGRATION_6_7, MIGRATION_7_8)
                // Production: No fallback to destructive migration
                // If migration fails, app will crash - this forces us to write correct migrations
                .build()
        }
        
        private val MIGRATION_1_2 = object : androidx.room.migration.Migration(1, 2) {
            override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
                // Create blocking_sessions table
                database.execSQL("""
                    CREATE TABLE IF NOT EXISTS blocking_sessions (
                        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        startTime INTEGER NOT NULL,
                        endTime INTEGER,
                        durationMinutes INTEGER NOT NULL,
                        isActive INTEGER NOT NULL,
                        isPaused INTEGER NOT NULL DEFAULT 0,
                        isStrictMode INTEGER NOT NULL,
                        motivationalMessage TEXT,
                        pausedAt INTEGER,
                        remainingMinutes INTEGER,
                        createdAt INTEGER NOT NULL
                    )
                """.trimIndent())
                
                // Create session_blocked_apps table
                database.execSQL("""
                    CREATE TABLE IF NOT EXISTS session_blocked_apps (
                        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        sessionId INTEGER NOT NULL,
                        packageName TEXT NOT NULL,
                        appName TEXT NOT NULL,
                        FOREIGN KEY(sessionId) REFERENCES blocking_sessions(id) ON DELETE CASCADE
                    )
                """.trimIndent())
            }
        }

        private val MIGRATION_2_3 = object : androidx.room.migration.Migration(2, 3) {
            override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
                // Add is_paused column to schedules table
                // Note: Column name is is_paused (snake_case) to match ScheduleEntity @ColumnInfo annotation
                database.execSQL("ALTER TABLE schedules ADD COLUMN is_paused INTEGER NOT NULL DEFAULT 0")
            }
        }
        
        private val MIGRATION_3_4 = object : androidx.room.migration.Migration(3, 4) {
            override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
                // Add strict mode columns to blocking_sessions
                database.execSQL("ALTER TABLE blocking_sessions ADD COLUMN strict_mode_level TEXT NOT NULL DEFAULT 'NONE'")
                database.execSQL("ALTER TABLE blocking_sessions ADD COLUMN strict_mode_pin TEXT")
                database.execSQL("ALTER TABLE blocking_sessions ADD COLUMN strict_mode_cooldown_minutes INTEGER")
                database.execSQL("ALTER TABLE blocking_sessions ADD COLUMN cooldown_started_at INTEGER")
                database.execSQL("ALTER TABLE blocking_sessions ADD COLUMN cooldown_confirmed INTEGER NOT NULL DEFAULT 0")
                
                // Add strict mode columns to schedules
                database.execSQL("ALTER TABLE schedules ADD COLUMN strict_mode_level TEXT NOT NULL DEFAULT 'NONE'")
                database.execSQL("ALTER TABLE schedules ADD COLUMN strict_mode_pin TEXT")
                database.execSQL("ALTER TABLE schedules ADD COLUMN strict_mode_cooldown_minutes INTEGER")
                
                // Create strict_mode_preferences table
                database.execSQL("""
                    CREATE TABLE IF NOT EXISTS strict_mode_preferences (
                        id INTEGER PRIMARY KEY NOT NULL,
                        default_level TEXT NOT NULL DEFAULT 'NONE',
                        default_pin TEXT,
                        default_cooldown_minutes INTEGER NOT NULL DEFAULT 10,
                        emergency_unlock_enabled INTEGER NOT NULL DEFAULT 1,
                        pin_lockout_until INTEGER NOT NULL DEFAULT 0,
                        failed_pin_attempts INTEGER NOT NULL DEFAULT 0
                    )
                """.trimIndent())
                
                // Insert default preferences (use INSERT OR IGNORE to avoid errors on re-run)
                database.execSQL("INSERT OR IGNORE INTO strict_mode_preferences (id) VALUES (1)")
            }
        }
        
        private val MIGRATION_4_5 = object : androidx.room.migration.Migration(4, 5) {
            override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
                // Add cooldown tracking columns to schedules table
                database.execSQL("ALTER TABLE schedules ADD COLUMN cooldown_started_at INTEGER")
                database.execSQL("ALTER TABLE schedules ADD COLUMN cooldown_confirmed INTEGER NOT NULL DEFAULT 0")
            }
        }

        private val MIGRATION_5_6 = object : androidx.room.migration.Migration(5, 6) {
            override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
                // Create app_limits table
                database.execSQL("""
                    CREATE TABLE IF NOT EXISTS app_limits (
                        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        name TEXT NOT NULL,
                        limitMinutes INTEGER NOT NULL,
                        isActive INTEGER NOT NULL,
                        createdAt INTEGER NOT NULL,
                        is_strict_mode INTEGER NOT NULL,
                        strict_mode_level TEXT NOT NULL DEFAULT 'NONE',
                        strict_mode_pin TEXT,
                        strict_mode_cooldown_minutes INTEGER,
                        hard_mode_duration_minutes INTEGER,
                        hard_mode_ends_at INTEGER,
                        last_unlocked_at INTEGER,
                        unlocked_until_midnight INTEGER NOT NULL DEFAULT 0
                    )
                """.trimIndent())
                
                // Create app_limit_apps table
                database.execSQL("""
                    CREATE TABLE IF NOT EXISTS app_limit_apps (
                        limitId INTEGER NOT NULL,
                        packageName TEXT NOT NULL,
                        appName TEXT NOT NULL,
                        PRIMARY KEY(limitId, packageName),
                        FOREIGN KEY(limitId) REFERENCES app_limits(id) ON DELETE CASCADE
                    )
                """.trimIndent())
            }
        }

        private val MIGRATION_6_7 = object : androidx.room.migration.Migration(6, 7) {
            override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
                // Create focus_sessions table
                database.execSQL("""
                    CREATE TABLE IF NOT EXISTS focus_sessions (
                        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        startTime INTEGER NOT NULL,
                        endTime INTEGER,
                        type TEXT NOT NULL,
                        relatedId INTEGER,
                        durationMinutes INTEGER NOT NULL,
                        createdAt INTEGER NOT NULL
                    )
                """.trimIndent())
            }
        }

        private val MIGRATION_7_8 = object : androidx.room.migration.Migration(7, 8) {
            override fun migrate(database: androidx.sqlite.db.SupportSQLiteDatabase) {
                // Add accumulatedPausedMs column to blocking_sessions
                database.execSQL("ALTER TABLE blocking_sessions ADD COLUMN accumulatedPausedMs INTEGER NOT NULL DEFAULT 0")
            }
        }
    }
}
