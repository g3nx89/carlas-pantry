---
name: android-expert
description: This skill should be used when the user asks to "add Android navigation", "implement Compose Navigation", "handle runtime permissions", "request camera permission", "configure AndroidManifest", "set up edge-to-edge UI", "implement bottom navigation", "configure Proguard", "optimize APK size", "handle Activity lifecycle", "use ViewModel with Compose", or "integrate collectAsStateWithLifecycle". Covers Android platform expertise for KMP projects. Delegates shared UI to compose-expert and Kotlin patterns to kotlin-expert.
allowed-tools: Read, Glob, Grep, Bash
---

# Android Expert

Android platform expertise for KMP projects. Covers Compose Navigation, Material3, permissions, lifecycle, and Android-specific patterns.

## When to Use

Auto-invoke when working with:
- Android navigation (Navigation Compose, routes, bottom nav)
- Runtime permissions (camera, notifications, biometric)
- Platform APIs (Intent, Context, Activity)
- Material3 theming and edge-to-edge UI
- Android build configuration (Proguard, APK optimization)
- AndroidManifest.xml configuration
- Android lifecycle (ViewModel, collectAsStateWithLifecycle)

## When NOT to Use

Delegate to specialized skills:
- **Compose UI components** → Use `compose-expert` skill
- **Kotlin language patterns** → Use `kotlin-expert` skill
- **Kotlin coroutines** → Use `kotlin-coroutines` skill
- **Gradle build issues** → Use `gradle-expert` skill

## Core Mental Model

**Single Activity Architecture + Compose Navigation**

```
MainActivity (Single Entry Point)
    ├── enableEdgeToEdge()
    ├── AppTheme { }
    └── NavHost
        ├── Route.Home → HomeScreen
        ├── Route.Profile(id) → ProfileScreen
        └── Route.Settings → SettingsScreen

Intent Filters (11+)
    ├── ACTION_MAIN (launcher)
    ├── ACTION_SEND (share)
    ├── ACTION_VIEW (deep links: myapp://, https://...)
    └── NFC_ACTION_NDEF_DISCOVERED
```

**Key Principles:**
1. **Type-Safe Navigation** - @Serializable routes, no strings
2. **Declarative Permissions** - Request contextually with Accompanist
3. **Edge-to-Edge + Insets** - Scaffold handles system bars
4. **ViewModel + Flow → State** - Survive config changes
5. **Platform Isolation** - Android code in app module or `androidMain/`

## Reference Map

| Topic | Reference File | When to Read |
|-------|----------------|--------------|
| Navigation patterns | `references/android-navigation.md` | Type-safe routes, NavHost, Bottom nav, Deep links |
| Permission handling | `references/android-permissions.md` | Runtime permissions, Accompanist, Version-specific |
| Proguard / R8 | `references/proguard-rules.md` | Code shrinking, obfuscation, keep rules |
| Lifecycle & ViewModel | `references/android-lifecycle.md` | ViewModel, StateFlow, effects, process death |

## 1. Type-Safe Navigation

> **Full patterns:** See `references/android-navigation.md`

### Key Pattern: @Serializable Routes

```kotlin
@Serializable
sealed class Route {
    @Serializable object Home : Route()
    @Serializable data class Profile(val userId: String) : Route()
    @Serializable data class Detail(val itemId: String) : Route()
}
```

### NavHost Quick Setup

```kotlin
NavHost(
    navController = navController,
    startDestination = Route.Home
) {
    composable<Route.Home> { HomeScreen(nav) }
    composable<Route.Profile> { entry ->
        val profile = entry.toRoute<Route.Profile>()
        ProfileScreen(profile.userId, nav)
    }
}
```

### Navigation Actions

| Action | Code |
|--------|------|
| Navigate | `navController.navigate(Route.Profile(id))` |
| Pop back | `navController.popBackStack()` |
| New stack | `navigate(route) { popUpTo(Route.Home) }` |

## 2. Runtime Permissions

> **Full patterns:** See `references/android-permissions.md`

### Key Pattern: Accompanist Permissions

```kotlin
@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun CameraFeature() {
    val permissionState = rememberPermissionState(Manifest.permission.CAMERA)

    when {
        permissionState.status.isGranted -> CameraPreview()
        permissionState.status.shouldShowRationale -> RationaleDialog(...)
        else -> Button(onClick = { permissionState.launchPermissionRequest() })
    }
}
```

### Permission Categories

| Category | Examples | Request Type |
|----------|----------|--------------|
| Network | INTERNET, ACCESS_NETWORK_STATE | Auto-granted |
| Media | CAMERA, RECORD_AUDIO | Runtime |
| Notifications | POST_NOTIFICATIONS (Android 13+) | Runtime |
| Location | ACCESS_COARSE_LOCATION | Runtime |

### Best Practices

1. **Request contextually** - When user needs the feature, not at app launch
2. **Show rationale** - Explain why before requesting
3. **Handle permanent denial** - Offer Settings link

## 3. Material3 + Edge-to-Edge

### Edge-to-Edge Setup

```kotlin
class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()  // Android 15+ immersive UI
        super.onCreate(savedInstanceState)
        setContent { AppTheme { AccountScreen() } }
    }
}
```

### Scaffold with Insets

```kotlin
Scaffold(
    topBar = { AppTopBar() },
    bottomBar = { AppBottomBar() }
) { innerPadding ->
    // Scaffold automatically handles system bar insets
    Content(modifier = Modifier.padding(innerPadding))
}
```

### Custom Inset Handling

```kotlin
Box(modifier = Modifier.fillMaxSize().systemBarsPadding()) {
    // Content draws edge-to-edge with safe padding
}
```

## 4. ViewModel + Lifecycle

### ViewModel Pattern

```kotlin
class FeedViewModel : ViewModel() {
    private val _feedState = MutableStateFlow<FeedState>(FeedState.Loading)
    val feedState: StateFlow<FeedState> = _feedState.asStateFlow()

    fun loadFeed() {
        viewModelScope.launch {
            _feedState.value = FeedState.Loading
            _feedState.value = FeedState.Success(repository.getFeed())
        }
    }
}
```

### Compose Integration

```kotlin
@Composable
fun FeedScreen(viewModel: FeedViewModel = viewModel()) {
    val feedState by viewModel.feedState.collectAsStateWithLifecycle()
    // Observe state with lifecycle awareness
}
```

### Lifecycle Effects

| Effect | Use Case |
|--------|----------|
| `LifecycleResumeEffect` | Resume/pause actions (connect/disconnect) |
| `DisposableEffect` | Resource cleanup (release ExoPlayer) |
| `LaunchedEffect` | One-time side effects |

## 5. Platform APIs

### Context & Activity Access

```kotlin
@Composable
fun ShareButton(text: String) {
    val context = LocalContext.current

    Button(onClick = {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        context.startActivity(Intent.createChooser(intent, "Share via"))
    }) { Text("Share") }
}
```

### Get Activity Reference

```kotlin
tailrec fun Context.getActivity(): ComponentActivity =
    when (this) {
        is ComponentActivity -> this
        is ContextWrapper -> baseContext.getActivity()
        else -> throw IllegalStateException("Context not an Activity")
    }
```

## 6. Build Configuration

### Android Block Essentials

```gradle
android {
    namespace = 'com.example.app'
    compileSdk = 36

    defaultConfig {
        minSdk = 26
        targetSdk = 36
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}
```

### Key Dependencies

```gradle
dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.accompanist.permissions)
}
```

## 7. KMP Android Source Sets

### Module Layout

```
app/
├── src/
│   ├── main/
│   │   ├── java/com/.../       # Compose UI
│   │   ├── res/                # Resources
│   │   └── AndroidManifest.xml
│   └── androidMain/            # KMP platform-specific
│       └── kotlin/
└── build.gradle
```

### Platform-Specific Code

```kotlin
// shared/src/androidMain/kotlin/Platform.android.kt
actual fun openExternalUrl(url: String, context: Any) {
    val ctx = context as Context
    ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
}
```

## Anti-Patterns to Avoid

| DON'T | DO |
|-------|-----|
| String-based navigation | Type-safe @Serializable routes |
| Request permissions eagerly | Request contextually before feature use |
| Ignore edge-to-edge | Handle insets with Scaffold |
| Use GlobalScope | Use viewModelScope or rememberCoroutineScope |
| Hardcode system bar heights | Use WindowInsets APIs |
| Block main thread | Use viewModelScope.launch(Dispatchers.IO) |

## Quick Reference

| Task | Pattern |
|------|---------|
| Navigate | `navController.navigate(Route.Profile(id))` |
| Request Permission | `rememberPermissionState().launchPermissionRequest()` |
| Access Context | `val context = LocalContext.current` |
| Get Activity | `val activity = context.getActivity()` |
| Open URL | `Intent(ACTION_VIEW, Uri.parse(url))` |
| Share Text | `Intent(ACTION_SEND).putExtra(EXTRA_TEXT, text)` |
| Observe Flow | `flow.collectAsStateWithLifecycle()` |
| Lifecycle Effect | `LifecycleResumeEffect { ... }` |
| Handle Insets | `Modifier.systemBarsPadding()` |
| Theme | `MaterialTheme(colorScheme = ...) { }` |

## Typical File Locations

- `app/src/main/java/com/.../ui/MainActivity.kt`
- `app/src/main/java/com/.../ui/navigation/routes/Routes.kt`
- `app/src/main/java/com/.../ui/navigation/AppNavigation.kt`
- `app/src/main/AndroidManifest.xml`
- `app/build.gradle`

## Additional Resources

- `references/android-navigation.md` - Complete navigation patterns
- `references/android-permissions.md` - Permission handling patterns
