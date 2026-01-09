package com.voidblock.app.channels

import android.content.Context
import com.voidblock.app.utils.PinEncryptionUtil
import com.voidblock.app.utils.StrictModeManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Method channel handler for strict mode operations
 * Bridges Flutter UI to native StrictModeManager
 */
class StrictModeChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    
    companion object {
        const val CHANNEL_NAME = "com.voidblock.app/strict_mode"
    }
    
    private val strictModeManager = StrictModeManager(context)
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDefaultPreferences" -> getDefaultPreferences(result)
            "updateDefaultLevel" -> updateDefaultLevel(call, result)
            "attemptUnlockSession" -> attemptUnlockSession(call, result)
            "attemptUnlockSchedule" -> attemptUnlockSchedule(call, result)
            "startCooldown" -> startCooldown(call, result)
            "confirmCooldownUnlock" -> confirmCooldownUnlock(call, result)
            "startScheduleCooldown" -> startScheduleCooldown(call, result)
            "confirmScheduleCooldownUnlock" -> confirmScheduleCooldownUnlock(call, result)
            "encryptPin" -> encryptPin(call, result)
            else -> result.notImplemented()
        }
    }
    
    private fun getDefaultPreferences(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val database = com.voidblock.app.data.database.AppDatabase.getInstance(context)
                val prefs = database.strictModePreferencesDao().getPreferencesSync()
                
                if (prefs != null) {
                    val map = mapOf(
                        "defaultLevel" to prefs.defaultLevel,
                        "defaultCooldownMinutes" to prefs.defaultCooldownMinutes,
                        "emergencyUnlockEnabled" to prefs.emergencyUnlockEnabled,
                        "pinLockoutUntil" to prefs.pinLockoutUntil,
                        "failedPinAttempts" to prefs.failedPinAttempts
                    )
                    CoroutineScope(Dispatchers.Main).launch {
                        result.success(map)
                    }
                } else {
                    CoroutineScope(Dispatchers.Main).launch {
                        result.success(null)
                    }
                }
            } catch (e: Exception) {
                CoroutineScope(Dispatchers.Main).launch {
                    result.error("GET_PREFS_ERROR", e.message, null)
                }
            }
        }
    }
    
    private fun updateDefaultLevel(call: MethodCall, result: MethodChannel.Result) {
        val level = call.argument<String>("level") ?: run {
            result.error("INVALID_ARGS", "Level is required", null)
            return
        }
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val database = com.voidblock.app.data.database.AppDatabase.getInstance(context)
                database.strictModePreferencesDao().updateDefaultLevel(level)
                
                CoroutineScope(Dispatchers.Main).launch {
                    result.success(true)
                }
            } catch (e: Exception) {
                CoroutineScope(Dispatchers.Main).launch {
                    result.error("UPDATE_ERROR", e.message, null)
                }
            }
        }
    }
    
    private fun attemptUnlockSession(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = (call.argument<Number>("sessionId"))?.toLong() ?: run {
            result.error("INVALID_ARGS", "Session ID is required", null)
            return
        }
        val pin = call.argument<String>("pin")
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val unlockResult = strictModeManager.attemptUnlock(sessionId, pin)
                
                val map = mapOf(
                    "success" to unlockResult.success,
                    "reason" to unlockResult.reason,
                    "failedAttempts" to unlockResult.failedAttempts,
                    "lockoutUntil" to unlockResult.lockoutUntil
                )
                
                CoroutineScope(Dispatchers.Main).launch {
                    result.success(map)
                }
            } catch (e: Exception) {
                CoroutineScope(Dispatchers.Main).launch {
                    result.error("UNLOCK_ERROR", e.message, null)
                }
            }
        }
    }
    
    private fun attemptUnlockSchedule(call: MethodCall, result: MethodChannel.Result) {
        val scheduleId = (call.argument<Number>("scheduleId"))?.toLong() ?: run {
            result.error("INVALID_ARGS", "Schedule ID is required", null)
            return
        }
        val pin = call.argument<String>("pin")
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val unlockResult = strictModeManager.attemptScheduleUnlock(scheduleId, pin)
                
                val map = mapOf(
                    "success" to unlockResult.success,
                    "reason" to unlockResult.reason,
                    "failedAttempts" to unlockResult.failedAttempts,
                    "lockoutUntil" to unlockResult.lockoutUntil
                )
                
                CoroutineScope(Dispatchers.Main).launch {
                    result.success(map)
                }
            } catch (e: Exception) {
                CoroutineScope(Dispatchers.Main).launch {
                    result.error("UNLOCK_ERROR", e.message, null)
                }
            }
        }
    }
    
    private fun startCooldown(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = (call.argument<Number>("sessionId"))?.toLong() ?: run {
            result.error("INVALID_ARGS", "Session ID is required", null)
            return
        }
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val started = strictModeManager.startCooldown(sessionId)
                CoroutineScope(Dispatchers.Main).launch {
                    result.success(started)
                }
            } catch (e: Exception) {
                CoroutineScope(Dispatchers.Main).launch {
                    result.error("COOLDOWN_ERROR", e.message, null)
                }
            }
        }
    }
    
    private fun confirmCooldownUnlock(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = (call.argument<Number>("sessionId"))?.toLong() ?: run {
            result.error("INVALID_ARGS", "Session ID is required", null)
            return
        }
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val unlockResult = strictModeManager.confirmCooldownUnlock(sessionId)
                
                val map = mapOf(
                    "success" to unlockResult.success,
                    "reason" to unlockResult.reason
                )
                
                CoroutineScope(Dispatchers.Main).launch {
                    result.success(map)
                }
            } catch (e: Exception) {
                CoroutineScope(Dispatchers.Main).launch {
                    result.error("CONFIRM_ERROR", e.message, null)
                }
            }
        }
    }
    
    private fun encryptPin(call: MethodCall, result: MethodChannel.Result) {
        val pin = call.argument<String>("pin") ?: run {
            result.error("INVALID_ARGS", "PIN is required", null)
            return
        }
        
        try {
            val encrypted = PinEncryptionUtil.encryptPin(pin)
            result.success(encrypted)
        } catch (e: Exception) {
            result.error("ENCRYPTION_ERROR", e.message, null)
        }
    }
    
    private fun startScheduleCooldown(call: MethodCall, result: MethodChannel.Result) {
        val scheduleId = (call.argument<Number>("scheduleId"))?.toLong() ?: run {
            result.error("INVALID_ARGS", "Schedule ID is required", null)
            return
        }
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val started = strictModeManager.startScheduleCooldown(scheduleId)
                CoroutineScope(Dispatchers.Main).launch {
                    result.success(started)
                }
            } catch (e: Exception) {
                CoroutineScope(Dispatchers.Main).launch {
                    result.error("COOLDOWN_ERROR", e.message, null)
                }
            }
        }
    }
    
    private fun confirmScheduleCooldownUnlock(call: MethodCall, result: MethodChannel.Result) {
        val scheduleId = (call.argument<Number>("scheduleId"))?.toLong() ?: run {
            result.error("INVALID_ARGS", "Schedule ID is required", null)
            return
        }
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val unlockResult = strictModeManager.confirmScheduleCooldownUnlock(scheduleId)
                
                val map = mapOf(
                    "success" to unlockResult.success,
                    "reason" to unlockResult.reason
                )
                
                CoroutineScope(Dispatchers.Main).launch {
                    result.success(map)
                }
            } catch (e: Exception) {
                CoroutineScope(Dispatchers.Main).launch {
                    result.error("CONFIRM_ERROR", e.message, null)
                }
            }
        }
    }
}
