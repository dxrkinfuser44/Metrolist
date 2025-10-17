package com.metrolist.wear.navigation

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.navigation.NavHostController
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.metrolist.wear.auth.AuthRepository
import com.metrolist.wear.auth.UserState
import com.metrolist.wear.metrosync.MetroSyncClient
import com.metrolist.wear.ui.screens.AccountScreen
import com.metrolist.wear.ui.screens.BrowseScreen
import com.metrolist.wear.ui.screens.SignInScreen
import kotlinx.coroutines.launch

/**
 * Navigation routes for Wear OS app
 */
object WearRoutes {
    const val SIGN_IN = "sign_in"
    const val BROWSE = "browse"
    const val REMOTE = "remote"
    const val ACCOUNT = "account"
    const val QUICK_PICKS = "quick_picks"
    const val SEARCH = "search"
    const val LIBRARY = "library"
    const val DOWNLOADS = "downloads"
}

/**
 * Navigation host for the Wear OS app
 */
@Composable
fun WearNavHost(
    authRepository: AuthRepository,
    metroSyncClient: MetroSyncClient,
    userState: UserState,
    navController: NavHostController = rememberSwipeDismissableNavController(),
    startDestination: String = if (userState is UserState.SignedOut) WearRoutes.SIGN_IN else WearRoutes.BROWSE
) {
    SwipeDismissableNavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable(WearRoutes.SIGN_IN) {
            SignInScreen(
                authRepository = authRepository,
                onSignInSuccess = {
                    navController.navigate(WearRoutes.BROWSE) {
                        popUpTo(WearRoutes.SIGN_IN) { inclusive = true }
                    }
                }
            )
        }
        
        composable(WearRoutes.BROWSE) {
            BrowseScreen(
                onQuickPicksClick = { navController.navigate(WearRoutes.QUICK_PICKS) },
                onSearchClick = { navController.navigate(WearRoutes.SEARCH) },
                onLibraryClick = { navController.navigate(WearRoutes.LIBRARY) },
                onDownloadsClick = { navController.navigate(WearRoutes.DOWNLOADS) }
            )
        }
        
        composable(WearRoutes.ACCOUNT) {
            val scope = rememberCoroutineScope()
            when (val state = userState) {
                is UserState.SignedIn -> {
                    AccountScreen(
                        userId = state.userId,
                        email = state.email,
                        displayName = state.displayName,
                        onSignOut = {
                            scope.launch {
                                authRepository.signOut()
                                navController.navigate(WearRoutes.SIGN_IN) {
                                    popUpTo(0) { inclusive = true }
                                }
                            }
                        }
                    )
                }
                else -> {}
            }
        }
    }
}
