package com.voidblock.app.utils

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Utility class for PIN encryption/decryption using Android Keystore
 * Provides secure storage for strict mode PINs
 */
object PinEncryptionUtil {
    
    private const val KEYSTORE_ALIAS = "VoidBlock_PIN_Key"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val GCM_TAG_LENGTH = 128
    
    /**
     * Encrypt a PIN using Android Keystore
     * @param pin The PIN to encrypt (plain text)
     * @return Encrypted PIN with IV (Base64 encoded)
     */
    fun encryptPin(pin: String): String {
        try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
            
            val iv = cipher.iv
            val encrypted = cipher.doFinal(pin.toByteArray(Charsets.UTF_8))
            
            // Combine IV and encrypted data
            val combined = iv + encrypted
            return Base64.encodeToString(combined, Base64.NO_WRAP)
        } catch (e: Exception) {
            android.util.Log.e("PinEncryption", "Encryption failed", e)
            throw SecurityException("Failed to encrypt PIN", e)
        }
    }
    
    /**
     * Decrypt a PIN using Android Keystore
     * @param encryptedPin Encrypted PIN (Base64 encoded)
     * @return Decrypted PIN (plain text)
     */
    fun decryptPin(encryptedPin: String): String {
        try {
            val combined = Base64.decode(encryptedPin, Base64.NO_WRAP)
            
            // Extract IV and encrypted data
            val ivLength = 12 // GCM standard IV length
            val iv = combined.copyOfRange(0, ivLength)
            val encrypted = combined.copyOfRange(ivLength, combined.size)
            
            val cipher = Cipher.getInstance(TRANSFORMATION)
            val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), spec)
            
            val decrypted = cipher.doFinal(encrypted)
            return String(decrypted, Charsets.UTF_8)
        } catch (e: Exception) {
            android.util.Log.e("PinEncryption", "Decryption failed", e)
            throw SecurityException("Failed to decrypt PIN", e)
        }
    }
    
    /**
     * Validate a PIN against the encrypted version  
     * @param inputPin User-entered PIN
     * @param encryptedPin Stored encrypted PIN
     * @return True if PIN matches
     */
    fun validatePin(inputPin: String, encryptedPin: String): Boolean {
        return try {
            val decrypted = decryptPin(encryptedPin)
            inputPin == decrypted
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Get or create the encryption key from Android Keystore
     */
    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)
        
        // Check if key exists
        if (keyStore.containsAlias(KEYSTORE_ALIAS)) {
            return keyStore.getKey(KEYSTORE_ALIAS, null) as SecretKey
        }
        
        // Create new key
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE
        )
        
        val keyGenSpec = KeyGenParameterSpec.Builder(
            KEYSTORE_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        
        keyGenerator.init(keyGenSpec)
        return keyGenerator.generateKey()
    }
}
