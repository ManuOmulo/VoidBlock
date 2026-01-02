package com.voidblock.app.data.database.entities

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index

@Entity(
    tableName = "app_limit_apps",
    primaryKeys = ["limitId", "packageName"],
    foreignKeys = [
        ForeignKey(
            entity = AppLimitEntity::class,
            parentColumns = ["id"],
            childColumns = ["limitId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("limitId")]
)
data class AppLimitAppEntity(
    val limitId: Long,
    val packageName: String,
    val appName: String
)
