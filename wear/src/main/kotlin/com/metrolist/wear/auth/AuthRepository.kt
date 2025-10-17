package com.metrolist.wear.auth

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialException
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
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
     * Sign in using Credential Manager with Remote Auth support
     * This will delegate to the paired phone for authentication
     */
    suspend fun signIn(): SignInResult {
        return try {
            // Configure Google Sign-In for Remote Auth
            // Note: Set a real Web Client ID from Google Cloud Console for production
            val googleIdOption = GetGoogleIdOption.Builder()
                .setFilterByAuthorizedAccounts(false)
                .setServerClientId("YOUR_WEB_CLIENT_ID.apps.googleusercontent.com") // Replace with actual client ID
                .setAutoSelectEnabled(true)
                .build()
            
            val request = GetCredentialRequest.Builder()
                .addCredentialOption(googleIdOption)
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
     * Handle the sign-in result from Credential Manager
     */
    private suspend fun handleSignInResult(result: GetCredentialResponse): SignInResult {
        val credential = result.credential
        
        return when (credential) {
            is CustomCredential -> {
                if (credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                    try {
                        val googleIdTokenCredential = GoogleIdTokenCredential.createFrom(credential.data)
                        
                        // Save user info
                        context.authDataStore.edit { preferences ->
                            preferences[USER_ID_KEY] = googleIdTokenCredential.id
                            preferences[USER_EMAIL_KEY] = googleIdTokenCredential.id // ID can be used as email
                            preferences[USER_NAME_KEY] = googleIdTokenCredential.displayName ?: ""
                            preferences[ID_TOKEN_KEY] = googleIdTokenCredential.idToken
                        }
                        
                        SignInResult.Success(
                            userId = googleIdTokenCredential.id,
                            email = googleIdTokenCredential.id,
                            displayName = googleIdTokenCredential.displayName
                        )
                    } catch (e: Exception) {
                        SignInResult.Error("Failed to parse Google credential: ${e.message}")
                    }
                } else {
                    SignInResult.Error("Unexpected credential type")
                }
            }
            else -> SignInResult.Error("Unexpected credential type")
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
