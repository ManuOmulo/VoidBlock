package com.focusguard.app.utils

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream

/**
 * Utility class for managing installed apps
 * Fetches and filters installed applications on the device
 */
class InstalledAppsManager(private val context: Context) {
    
    private val packageManager = context.packageManager
    
    /**
     * Get all installed apps (user and system)
     */
    fun getAllInstalledApps(includeSystemApps: Boolean = false): List<AppInfo> {
        val apps = mutableListOf<AppInfo>()
        
        val packages = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
        
        for (packageInfo in packages) {
            // Skip system apps if requested
            if (!includeSystemApps && isSystemApp(packageInfo)) {
                continue
            }
            
            // Skip our own app
            if (packageInfo.packageName == context.packageName) {
                continue
            }
            
            val appInfo = AppInfo(
                packageName = packageInfo.packageName,
                appName = getAppName(packageInfo),
                isSystemApp = isSystemApp(packageInfo),
                iconBase64 = getAppIconBase64(packageInfo)
            )
            
            apps.add(appInfo)
        }
        
        // Sort by app name
        return apps.sortedBy { it.appName.lowercase() }
    }
    
    /**
     * Get only user-installed apps
     */
    fun getUserApps(): List<AppInfo> {
        return getAllInstalledApps(includeSystemApps = false)
    }
    
    /**
     * Get app info by package name
     */
    fun getAppInfo(packageName: String): AppInfo? {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            AppInfo(
                packageName = appInfo.packageName,
                appName = getAppName(appInfo),
                isSystemApp = isSystemApp(appInfo),
                iconBase64 = getAppIconBase64(appInfo)
            )
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }
    
    /**
     * Check if an app is a system app
     */
    private fun isSystemApp(appInfo: ApplicationInfo): Boolean {
        return (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
    }
    
    /**
     * Get app name from ApplicationInfo
     */
    private fun getAppName(appInfo: ApplicationInfo): String {
        return try {
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            appInfo.packageName
        }
    }
    
    /**
     * Get app icon as Base64 string
     */
    private fun getAppIconBase64(appInfo: ApplicationInfo): String? {
        return try {
            val icon = packageManager.getApplicationIcon(appInfo)
            val bitmap = drawableToBitmap(icon)
            bitmapToBase64(bitmap)
        } catch (e: Exception) {
            null
        }
    }
    
    /**
     * Convert drawable to bitmap
     */
    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            if (drawable.bitmap != null) {
                return drawable.bitmap
            }
        }
        
        val bitmap = if (drawable.intrinsicWidth <= 0 || drawable.intrinsicHeight <= 0) {
            Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        } else {
            Bitmap.createBitmap(
                drawable.intrinsicWidth,
                drawable.intrinsicHeight,
                Bitmap.Config.ARGB_8888
            )
        }
        
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
    
    /**
     * Convert bitmap to Base64 string
     */
    private fun bitmapToBase64(bitmap: Bitmap): String {
        val byteArrayOutputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)
        val byteArray = byteArrayOutputStream.toByteArray()
        return Base64.encodeToString(byteArray, Base64.NO_WRAP)
    }
    
    /**
     * Search apps by name
     */
    fun searchApps(query: String, includeSystemApps: Boolean = false): List<AppInfo> {
        val allApps = getAllInstalledApps(includeSystemApps)
        val lowerQuery = query.lowercase()
        
        return allApps.filter {
            it.appName.lowercase().contains(lowerQuery) ||
            it.packageName.lowercase().contains(lowerQuery)
        }
    }
    
    /**
     * Categorize apps (basic categorization)
     */
    fun categorizeApps(apps: List<AppInfo>): Map<String, List<AppInfo>> {
        val categories = mutableMapOf<String, MutableList<AppInfo>>()
        
        apps.forEach { app ->
            val category = getCategoryForApp(app.packageName)
            categories.getOrPut(category) { mutableListOf() }.add(app)
        }
        
        return categories
    }
    
    /**
     * Get category for app (basic heuristic)
     */
    private fun getCategoryForApp(packageName: String): String {
        return when {
            packageName.contains("social", ignoreCase = true) -> "Social"
            packageName.contains("game", ignoreCase = true) -> "Games"
            packageName.contains("video", ignoreCase = true) || 
            packageName.contains("youtube", ignoreCase = true) ||
            packageName.contains("netflix", ignoreCase = true) -> "Video & Entertainment"
            packageName.contains("messenger", ignoreCase = true) ||
            packageName.contains("whatsapp", ignoreCase = true) ||
            packageName.contains("telegram", ignoreCase = true) -> "Messaging"
            packageName.contains("browser", ignoreCase = true) ||
            packageName.contains("chrome", ignoreCase = true) -> "Browsers"
            else -> "Other"
        }
    }
}

/**
 * Data class representing app information
 */
data class AppInfo(
    val packageName: String,
    val appName: String,
    val isSystemApp: Boolean,
    val iconBase64: String? = null
)
