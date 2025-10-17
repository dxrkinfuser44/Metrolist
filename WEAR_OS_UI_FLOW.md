# Wear OS UI Flow Diagram

## Screen Flow

```
┌─────────────────────────────────────────────────────────┐
│                     App Launch                          │
│                          ↓                              │
│              Check Authentication State                  │
└─────────────────────────────────────────────────────────┘
                          │
           ┌──────────────┴──────────────┐
           │                             │
     [SignedOut]                   [SignedIn]
           │                             │
           ↓                             ↓
┌──────────────────────┐      ┌──────────────────────┐
│   Sign-In Screen     │      │   Browse Screen      │
│                      │      │                      │
│  [Sign In] Button    │      │  • Quick Picks       │
│  [Demo Mode] Button  │      │  • Search            │
│                      │      │  • Library           │
│  Metrolist Logo      │      │  • Downloads         │
│  "Sign in to         │      │  • Account → ◉       │
│   continue"          │      │                      │
└──────────────────────┘      └──────────────────────┘
           │                             │
           │ (Tap Sign In)               │ (Tap Account)
           ↓                             ↓
┌──────────────────────┐      ┌──────────────────────┐
│  Remote Auth Flow    │      │  Account Screen      │
│                      │      │                      │
│  1. Request sent     │      │  User Profile        │
│     to phone         │      │  • Display Name      │
│  2. User signs in    │      │  • Email             │
│     on phone         │      │                      │
│  3. Credentials      │      │  [Sign Out] Button   │
│     returned         │      │                      │
│  4. Navigate to      │      └──────────────────────┘
│     Browse           │                 │
└──────────────────────┘      (Tap Sign Out)
           │                             ↓
           │                    Clear Credentials
           │                             │
           └─────────────────────────────┘
                          ↓
              Return to Sign-In Screen
```

## Authentication States

```
UserState (Sealed Class)
├── SignedOut
│   └── Shows: SignInScreen
│
└── SignedIn(userId, email, displayName)
    └── Shows: BrowseScreen / AccountScreen

SignInResult (Sealed Class)
├── Success(userId, email, displayName)
│   └── Navigate to BrowseScreen
│
└── Error(message)
    └── Show error message
```

## Component Architecture

```
┌────────────────────────────────────────────────────────┐
│                    MainActivity                         │
│  ┌──────────────────────────────────────────────────┐ │
│  │           WearApp Composable                     │ │
│  │  ┌────────────────────────────────────────────┐ │ │
│  │  │  Authentication State Observer             │ │ │
│  │  │    (authRepository.userState)              │ │ │
│  │  └────────────────────────────────────────────┘ │ │
│  │                     │                            │ │
│  │      ┌──────────────┴──────────────┐            │ │
│  │      │                             │            │ │
│  │  SignedOut                    SignedIn          │ │
│  │      │                             │            │ │
│  │      ↓                             ↓            │ │
│  │  SignInScreen        ┌─────────────────────┐   │ │
│  │      │                │   Screen Router     │   │ │
│  │      │                │                     │   │ │
│  │      │                │  • BrowseScreen     │   │ │
│  │      │                │  • AccountScreen    │   │ │
│  │      │                │  • RemoteScreen     │   │ │
│  │      │                └─────────────────────┘   │ │
│  └──────┼─────────────────────────────────────────┘ │
│         │                                            │
└─────────┼────────────────────────────────────────────┘
          │
          ↓
┌────────────────────────────────────────────────────────┐
│                 AuthRepository                          │
│  ┌──────────────────────────────────────────────────┐ │
│  │  Credential Manager API                          │ │
│  │  • signIn() - Remote Auth flow                  │ │
│  │  • signInDemo() - Testing mode                  │ │
│  │  • signOut() - Clear credentials                │ │
│  │  • userState - Observable Flow                  │ │
│  └──────────────────────────────────────────────────┘ │
│                     │                                  │
│                     ↓                                  │
│  ┌──────────────────────────────────────────────────┐ │
│  │  DataStore (Persistent Storage)                  │ │
│  │  • user_id                                       │ │
│  │  • user_email                                    │ │
│  │  • user_name                                     │ │
│  │  • id_token                                      │ │
│  └──────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────┘
```

## UI Component Hierarchy

```
SignInScreen
├── ScalingLazyColumn (Wear-optimized list)
│   ├── Title: "Metrolist"
│   ├── Subtitle: "Sign in to continue"
│   ├── Card: "Sign In" (Remote Auth)
│   ├── Card: "Demo Mode" (Testing)
│   ├── Card: Error Message (if error)
│   └── Text: Help message
└── TimeText (Always visible)

BrowseScreen
├── ScalingLazyColumn
│   ├── Title: "Metrolist"
│   ├── BrowseCard: "Quick Picks"
│   ├── BrowseCard: "Search"
│   ├── BrowseCard: "Library"
│   ├── BrowseCard: "Downloads"
│   └── BrowseCard: "Account"
└── TimeText

AccountScreen
├── ScalingLazyColumn
│   ├── Title: "Account"
│   ├── Card: User Info
│   │   ├── Display Name
│   │   └── Email
│   └── Button: "Sign Out"
└── TimeText
```

## Data Flow

```
User Action
    ↓
Composable UI
    ↓
AuthRepository Method
    ↓
Credential Manager API
    ↓
Remote Auth (Phone)
    ↓
Google Sign-In (Phone)
    ↓
Credentials Returned
    ↓
Save to DataStore
    ↓
Update userState Flow
    ↓
UI Recomposes
    ↓
Navigate to New Screen
```

## Key Features

### 1. Remote Auth Integration
- Uses Android Credential Manager
- Delegates to paired phone
- Seamless user experience
- No typing on watch needed

### 2. Demo Mode
- Test without configuration
- Bypass Google Sign-In
- Instant access to UI
- Development-friendly

### 3. Persistent State
- DataStore for credentials
- Survives app restarts
- Secure storage
- Observable Flow

### 4. Wear OS Optimized
- ScalingLazyColumn
- Card-based UI
- TimeText overlay
- Circular display support
- Minimal navigation depth

### 5. Error Handling
- Try-catch blocks
- User-friendly messages
- Graceful fallbacks
- Loading states

## Implementation Checklist

✅ Credential Manager dependencies
✅ AuthRepository with Remote Auth
✅ SignInScreen with dual options
✅ AccountScreen for management
✅ BrowseScreen enhancement
✅ State management (Flow)
✅ Persistent storage (DataStore)
✅ Demo mode for testing
✅ Error handling
✅ Loading states
✅ Navigation logic
✅ Hilt dependency injection
✅ Documentation
✅ Code comments
