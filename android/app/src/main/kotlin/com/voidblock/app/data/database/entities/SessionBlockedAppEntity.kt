package com.voidblock.app.data.database.entities

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.PrimaryKey

/**
 * Entity representing apps blocked during a manual blocking session
 * Links blocked packages to their parent blocking session
 */
@Entity(
    tableName = "session_blocked_apps",
    foreignKeys = [
        ForeignKey(
            entity = BlockingSessionEntity::class,
            parentColumns = ["id"],
            childColumns = ["sessionId"],
            onDelete = ForeignKey.CASCADE
        )
    ]
)
data class SessionBlockedAppEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val sessionId: Long,
    val packageName: String,
    val appName: String
)
