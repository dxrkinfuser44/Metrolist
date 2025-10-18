package com.metrolist.wear.auth

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPasswordOption
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PasswordCredential
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.GetCredentialException
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.authDataStore: DataStore<Preferences> by preferencesDataStore(name = "auth")

/**
 * Repository for managing authentication state in Wear OS
 */
@Singleton
class AuthRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val credentialManager = CredentialManager.create(context)
    
    companion object {
        private val USER_ID_KEY = stringPreferencesKey("user_id")
        private val USER_EMAIL_KEY = stringPreferencesKey("user_email")
        private val USER_NAME_KEY = stringPreferencesKey("user_name")
        private val ID_TOKEN_KEY = stringPreferencesKey("id_token")
    }
    
    /**
     * Get the current user state
     */
    val userState: Flow<UserState> = context.authDataStore.data.map { preferences ->
        val userId = preferences[USER_ID_KEY]
        val email = preferences[USER_EMAIL_KEY]
        val name = preferences[USER_NAME_KEY]
        
        if (userId != null && email != null) {
            UserState.SignedIn(
                userId = userId,
                email = email,
                displayName = name
            )
        } else {
            UserState.SignedOut
        }
    }
    
    /**
     * Sign in using Credential Manager with Passkey support
     * This will use Google Password Manager to authenticate with passkeys
     */
    suspend fun signIn(): SignInResult {
        return try {
            // Request passkey authentication from Google Password Manager
            // This JSON structure is required for WebAuthn/Passkey authentication
            val requestJson = """
                {
                    "challenge": "${generateChallenge()}",
                    "rpId": "metrolist.app",
                    "userVerification": "required"
                }
            """.trimIndent()
            
            val publicKeyCredentialOption = GetPublicKeyCredentialOption(
                requestJson = requestJson,
                clientDataHash = null // Let the system generate this
            )
            
            // Also support traditional password credentials from Google Password Manager
            val passwordOption = GetPasswordOption()
            
            val request = GetCredentialRequest.Builder()
                .addCredentialOption(publicKeyCredentialOption)
                .addCredentialOption(passwordOption)
                .build()
            
            val result = credentialManager.getCredential(
                request = request,
                context = context
            )
            
            handleSignInResult(result)
        } catch (e: GetCredentialException) {
            SignInResult.Error("Sign-in cancelled or failed: ${e.message}")
        } catch (e: Exception) {
            SignInResult.Error("Sign-in error: ${e.message}")
        }
    }
    
    /**
     * Generate a random challenge for passkey authentication
     */
    private fun generateChallenge(): String {
        // Generate a base64-encoded random challenge
        val random = java.security.SecureRandom()
        val bytes = ByteArray(32)
        random.nextBytes(bytes)
        return android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING or android.util.Base64.URL_SAFE)
    }
    
    /**
     * Sign in with demo credentials for testing
     * This bypasses the actual credential flow
     */
    suspend fun signInDemo(): SignInResult {
        return try {
            // Save demo user info
            context.authDataStore.edit { preferences ->
                preferences[USER_ID_KEY] = "demo_user"
                preferences[USER_EMAIL_KEY] = "demo@metrolist.app"
                preferences[USER_NAME_KEY] = "Demo User"
            }
            
            SignInResult.Success(
                userId = "demo_user",
                email = "demo@metrolist.app",
                displayName = "Demo User"
            )
        } catch (e: Exception) {
            SignInResult.Error("Demo sign-in failed: ${e.message}")
        }
    }
    
    /**
     * Handle the sign-in result from Credential Manager
     * Supports both Passkey and Password credentials
     */
    private suspend fun handleSignInResult(result: GetCredentialResponse): SignInResult {
        val credential = result.credential
        
        return when (credential) {
            is PublicKeyCredential -> {
                try {
                    // Handle passkey authentication response
                    val authenticationResponseJson = credential.authenticationResponseJson
                    
                    // Parse the response to extract user information
                    // In a real app, you would verify this with your backend server
                    val userId = extractUserIdFromPasskey(authenticationResponseJson)
                    
                    // Save user info
                    context.authDataStore.edit { preferences ->
                        preferences[USER_ID_KEY] = userId
                        preferences[USER_EMAIL_KEY] = "$userId@metrolist.app"
                        preferences[USER_NAME_KEY] = "Passkey User"
                    }
                    
                    SignInResult.Success(
                        userId = userId,
                        email = "$userId@metrolist.app",
                        displayName = "Passkey User"
                    )
                } catch (e: Exception) {
                    SignInResult.Error("Failed to parse passkey credential: ${e.message}")
                }
            }
            is PasswordCredential -> {
                try {
                    // Handle password credential from Google Password Manager
                    val username = credential.id
                    val password = credential.password
                    
                    // In a real app, you would verify this with your backend server
                    // For now, we'll accept any saved password from Google Password Manager
                    
                    // Save user info
                    context.authDataStore.edit { preferences ->
                        preferences[USER_ID_KEY] = username
                        preferences[USER_EMAIL_KEY] = username
                        preferences[USER_NAME_KEY] = username
                    }
                    
                    SignInResult.Success(
                        userId = username,
                        email = username,
                        displayName = username
                    )
                } catch (e: Exception) {
                    SignInResult.Error("Failed to parse password credential: ${e.message}")
                }
            }
            else -> SignInResult.Error("Unexpected credential type: ${credential.type}")
        }
    }
    
    /**
     * Extract user ID from passkey authentication response
     */
    private fun extractUserIdFromPasskey(responseJson: String): String {
        return try {
            // Parse the JSON response to extract user handle/ID
            val json = org.json.JSONObject(responseJson)
            val response = json.optJSONObject("response")
            val userHandle = response?.optString("userHandle")
            
            if (!userHandle.isNullOrEmpty()) {
                // Decode base64 user handle
                val decoded = android.util.Base64.decode(userHandle, android.util.Base64.URL_SAFE)
                String(decoded)
            } else {
                // Fallback to a generated ID
                "passkey_user_${System.currentTimeMillis()}"
            }
        } catch (e: Exception) {
            // Fallback to a generated ID
            "passkey_user_${System.currentTimeMillis()}"
        }
    }
    
    /**
     * Sign out the current user
     */
    suspend fun signOut() {
        context.authDataStore.edit { preferences ->
            preferences.clear()
        }
    }
}

/**
 * Represents the user authentication state
 */
sealed class UserState {
    object SignedOut : UserState()
    data class SignedIn(
        val userId: String,
        val email: String,
        val displayName: String?
    ) : UserState()
}

/**
 * Result of a sign-in attempt
 */
sealed class SignInResult {
    data class Success(
        val userId: String,
        val email: String,
        val displayName: String?
    ) : SignInResult()
    
    data class Error(val message: String) : SignInResult()
}
