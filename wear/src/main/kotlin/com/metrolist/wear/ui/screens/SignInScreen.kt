package com.metrolist.wear.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Card
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.metrolist.wear.auth.AuthRepository
import com.metrolist.wear.auth.SignInResult
import kotlinx.coroutines.launch

/**
 * Sign-In screen for Wear OS
 * Uses Credential Manager for Remote Auth (delegation to phone)
 */
@Composable
fun SignInScreen(
    authRepository: AuthRepository,
    onSignInSuccess: () -> Unit
) {
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(32.dp))
        }
        
        item {
            Text(
                text = "Metrolist",
                style = MaterialTheme.typography.title1,
                modifier = Modifier.padding(vertical = 8.dp)
            )
        }
        
        item {
            Text(
                text = "Sign in to continue",
                style = MaterialTheme.typography.body2,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }
        
        item {
            Spacer(modifier = Modifier.height(8.dp))
        }
        
        if (isLoading) {
            item {
                CircularProgressIndicator(
                    modifier = Modifier.size(48.dp)
                )
            }
            
            item {
                Text(
                    text = "Authenticating...",
                    style = MaterialTheme.typography.caption1,
                    textAlign = TextAlign.Center
                )
            }
        } else {
            item {
                Card(
                    onClick = {
                        isLoading = true
                        errorMessage = null
                        scope.launch {
                            when (val result = authRepository.signIn()) {
                                is SignInResult.Success -> {
                                    isLoading = false
                                    onSignInSuccess()
                                }
                                is SignInResult.Error -> {
                                    isLoading = false
                                    errorMessage = result.message
                                }
                            }
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "Sign In",
                            style = MaterialTheme.typography.title3
                        )
                        Text(
                            text = "Use your phone",
                            style = MaterialTheme.typography.caption1,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }
            }
            
            // Demo mode button for development/testing
            item {
                Card(
                    onClick = {
                        isLoading = true
                        errorMessage = null
                        scope.launch {
                            when (val result = authRepository.signInDemo()) {
                                is SignInResult.Success -> {
                                    isLoading = false
                                    onSignInSuccess()
                                }
                                is SignInResult.Error -> {
                                    isLoading = false
                                    errorMessage = result.message
                                }
                            }
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "Demo Mode",
                            style = MaterialTheme.typography.title3
                        )
                        Text(
                            text = "For testing",
                            style = MaterialTheme.typography.caption1,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }
            }
            
            if (errorMessage != null) {
                item {
                    Card(
                        onClick = {},
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                    ) {
                        Text(
                            text = errorMessage ?: "",
                            style = MaterialTheme.typography.caption1,
                            color = MaterialTheme.colors.error,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(16.dp)
                        )
                    }
                }
            }
            
            item {
                Spacer(modifier = Modifier.height(8.dp))
            }
            
            item {
                Text(
                    text = "Sign in will be handled\non your paired phone",
                    style = MaterialTheme.typography.caption2,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 24.dp)
                )
            }
        }
    }
}

/**
 * Account info screen shown after sign-in
 */
@Composable
fun AccountScreen(
    userId: String,
    email: String,
    displayName: String?,
    onSignOut: () -> Unit
) {
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        item {
            Spacer(modifier = Modifier.height(32.dp))
        }
        
        item {
            Text(
                text = "Account",
                style = MaterialTheme.typography.title2,
                modifier = Modifier.padding(vertical = 8.dp)
            )
        }
        
        item {
            Card(
                onClick = {},
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (displayName != null) {
                        Text(
                            text = displayName,
                            style = MaterialTheme.typography.title3,
                            textAlign = TextAlign.Center
                        )
                    }
                    Text(
                        text = email,
                        style = MaterialTheme.typography.caption1,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }
        }
        
        item {
            Button(
                onClick = onSignOut,
                colors = ButtonDefaults.secondaryButtonColors(),
                modifier = Modifier.padding(horizontal = 16.dp)
            ) {
                Text("Sign Out")
            }
        }
    }
}
