# Wear OS UI Screens - Visual Mockup

This document provides a text-based visual representation of the Wear OS screens implemented.

---

## 1. Sign-In Screen (Initial)

```
╔════════════════════════════════════╗
║          ⌚ 12:34                  ║  ← TimeText (always visible)
║                                    ║
║                                    ║
║          Metrolist                 ║  ← App Title (Large)
║                                    ║
║      Sign in to continue           ║  ← Subtitle
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │                              │ ║
║  │         Sign In              │ ║  ← Primary Card
║  │      Use your phone          │ ║     (Remote Auth)
║  │                              │ ║
║  └──────────────────────────────┘ ║
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │                              │ ║
║  │       Demo Mode              │ ║  ← Demo Card
║  │       For testing            │ ║     (Quick testing)
║  │                              │ ║
║  └──────────────────────────────┘ ║
║                                    ║
║   Sign in will be handled          ║  ← Help Text
║    on your paired phone            ║
║                                    ║
╚════════════════════════════════════╝
```

### Interactions:
- **Tap "Sign In"** → Opens Credential Manager → Delegates to phone
- **Tap "Demo Mode"** → Instant sign-in as demo user
- **Scroll** → ScalingLazyColumn for comfortable viewing

---

## 2. Sign-In Screen (Loading)

```
╔════════════════════════════════════╗
║          ⌚ 12:34                  ║
║                                    ║
║                                    ║
║          Metrolist                 ║
║                                    ║
║      Sign in to continue           ║
║                                    ║
║                                    ║
║            ◐◐◐◐                   ║  ← Loading Spinner
║                                    ║
║      Authenticating...             ║  ← Status Text
║                                    ║
║                                    ║
║                                    ║
╚════════════════════════════════════╝
```

---

## 3. Sign-In Screen (Error)

```
╔════════════════════════════════════╗
║          ⌚ 12:34                  ║
║                                    ║
║          Metrolist                 ║
║      Sign in to continue           ║
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │        Sign In               │ ║
║  │     Use your phone           │ ║
║  └──────────────────────────────┘ ║
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │                              │ ║
║  │  ⚠️ Sign-in cancelled or     │ ║  ← Error Card
║  │     failed: [message]        │ ║     (Red text)
║  │                              │ ║
║  └──────────────────────────────┘ ║
║                                    ║
╚════════════════════════════════════╝
```

---

## 4. Browse Screen (Main)

```
╔════════════════════════════════════╗
║          ⌚ 12:34                  ║
║                                    ║
║                                    ║
║          Metrolist                 ║  ← App Title
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │      Quick Picks             │ ║  ← Browse Cards
║  │   Personalized for you       │ ║     (Scrollable list)
║  └──────────────────────────────┘ ║
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │         Search               │ ║
║  │   Find songs & artists       │ ║
║  └──────────────────────────────┘ ║
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │        Library               │ ║
║  │       Your music             │ ║
║  └──────────────────────────────┘ ║
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │       Downloads              │ ║
║  │     Offline playback         │ ║
║  └──────────────────────────────┘ ║
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │        Account               │ ║  ← NEW: Account Menu
║  │   Manage your account        │ ║
║  └──────────────────────────────┘ ║
║                                    ║
╚════════════════════════════════════╝
```

### Interactions:
- **Scroll** → View all menu items
- **Tap any card** → Navigate to that section
- **Tap Account** → Go to Account screen

---

## 5. Account Screen

```
╔════════════════════════════════════╗
║          ⌚ 12:34                  ║
║                                    ║
║                                    ║
║           Account                  ║  ← Screen Title
║                                    ║
║  ┌──────────────────────────────┐ ║
║  │                              │ ║
║  │       Demo User              │ ║  ← Display Name
║  │                              │ ║     (or actual user)
║  │   demo@metrolist.app         │ ║  ← Email
║  │                              │ ║
║  └──────────────────────────────┘ ║
║                                    ║
║           ┌──────────┐            ║
║           │ Sign Out │            ║  ← Sign Out Button
║           └──────────┘            ║
║                                    ║
║                                    ║
╚════════════════════════════════════╝
```

### Interactions:
- **Tap Sign Out** → Clear credentials → Return to Sign-In screen
- **Swipe back** → Return to Browse screen

---

## Design Patterns Used

### 1. ScalingLazyColumn
All screens use Wear OS's `ScalingLazyColumn` which:
- Scales items based on position (larger in center)
- Optimized for circular displays
- Natural scrolling behavior
- Better readability on small screens

### 2. Card Components
Primary interaction elements:
- Touch-friendly size
- Clear visual hierarchy
- Material Design elevation
- Consistent padding

### 3. TimeText Overlay
- Always visible at top
- Shows current time
- Doesn't interfere with content
- Standard Wear OS pattern

### 4. Typography Hierarchy
```
Title1  - App name (largest)
Title2  - Section headers
Title3  - Card titles
Body2   - Descriptions
Caption1 - Secondary text
Caption2 - Help text (smallest)
```

### 5. Color Scheme
- Background: Material theme background
- Primary: Blue (Sign In button)
- Secondary: Gray (Demo button)
- Error: Red (error messages)
- Surface: Elevated cards

---

## Responsive Behavior

### Small Displays (< 200dp)
- Cards stack vertically
- Adequate spacing between items
- Text truncates with ellipsis
- Minimum touch targets maintained

### Large Displays (> 200dp)
- More content visible
- Better spacing
- Larger text
- Enhanced readability

### Circular vs Square
- ScalingLazyColumn adapts automatically
- Content always within safe area
- No cutoff on circular edges

---

## Accessibility

### Screen Reader Support
- All Cards have proper labels
- Loading states announced
- Error messages read aloud
- Button actions described

### Touch Targets
- Minimum 48dp touch areas
- Card padding for easy taps
- Adequate spacing between items

### Text Readability
- High contrast text
- Material Design typography
- Proper text sizing
- No small text on watch

---

## State Transitions

```
SignInScreen
    ↓ (Tap Sign In)
    ↓
Loading State
    ↓ (Success)
    ↓
BrowseScreen
    ↓ (Tap Account)
    ↓
AccountScreen
    ↓ (Tap Sign Out)
    ↓
SignInScreen
```

---

## Animation

### Transitions
- Fade in/out between screens
- Swipe dismiss support
- Smooth scrolling
- Button press feedback

### Loading
- Circular progress indicator
- Indeterminate animation
- Non-blocking UI

### Cards
- Touch ripple effect
- Elevation change on press
- Smooth state changes

---

## Platform Features

### Wear OS Specific
✅ ScalingLazyColumn
✅ TimeText overlay
✅ Card-based navigation
✅ Swipe to dismiss
✅ Circular display optimization
✅ Material You theming

### Android Standard
✅ Jetpack Compose
✅ Material Design
✅ State hoisting
✅ Lifecycle awareness
✅ Configuration changes

---

## Summary

The UI implementation follows all Wear OS design guidelines:
- ✅ Glanceable content
- ✅ Simple navigation
- ✅ Touch-friendly targets
- ✅ Minimal text input
- ✅ Quick interactions
- ✅ Battery efficient

**Total Screens**: 3 main screens + loading states
**Interaction Model**: Card-based, swipe-dismissable
**Design System**: Material Design for Wear OS
**Accessibility**: Full screen reader support
