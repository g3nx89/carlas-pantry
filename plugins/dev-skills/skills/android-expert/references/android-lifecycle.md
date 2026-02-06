# Android Lifecycle & ViewModel Patterns

Comprehensive patterns for managing ViewModel state, lifecycle effects, and configuration change survival in Compose-based Android apps.

---

## ViewModel with StateFlow

### Standard Pattern

```kotlin
class FeedViewModel(
    private val repository: FeedRepository
) : ViewModel() {
    private val _uiState = MutableStateFlow<FeedUiState>(FeedUiState.Loading)
    val uiState: StateFlow<FeedUiState> = _uiState.asStateFlow()

    init {
        loadFeed()
    }

    fun loadFeed() {
        viewModelScope.launch {
            _uiState.value = FeedUiState.Loading
            try {
                val items = repository.getFeed()
                _uiState.value = FeedUiState.Success(items)
            } catch (e: Exception) {
                _uiState.value = FeedUiState.Error(e.message ?: "Unknown error")
            }
        }
    }

    fun refresh() {
        loadFeed()
    }
}

sealed interface FeedUiState {
    data object Loading : FeedUiState
    data class Success(val items: List<FeedItem>) : FeedUiState
    data class Error(val message: String) : FeedUiState
}
```

### Compose Integration

```kotlin
@Composable
fun FeedScreen(viewModel: FeedViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    when (val state = uiState) {
        is FeedUiState.Loading -> LoadingIndicator()
        is FeedUiState.Success -> FeedList(state.items)
        is FeedUiState.Error -> ErrorMessage(
            message = state.message,
            onRetry = viewModel::refresh
        )
    }
}
```

**Key:** Always use `collectAsStateWithLifecycle()` instead of `collectAsState()` to stop collection when the lifecycle is inactive (saves battery, prevents crashes).

---

## Lifecycle Effects in Compose

### LifecycleResumeEffect

Execute actions when screen resumes/pauses. Ideal for connections, sensors, or media playback.

```kotlin
@Composable
fun VideoPlayer(url: String) {
    val player = remember { ExoPlayer.Builder(context).build() }

    LifecycleResumeEffect(url) {
        player.play()
        onPauseOrDispose {
            player.pause()
        }
    }

    AndroidView(factory = { PlayerView(it).apply { this.player = player } })
}
```

### DisposableEffect

Execute cleanup when leaving composition or key changes.

```kotlin
@Composable
fun SensorListener(sensorManager: SensorManager) {
    DisposableEffect(Unit) {
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) { /* handle */ }
            override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
        }
        sensorManager.registerListener(listener, sensor, SENSOR_DELAY_UI)

        onDispose {
            sensorManager.unregisterListener(listener)
        }
    }
}
```

### LaunchedEffect

One-time side effects triggered by key changes.

```kotlin
@Composable
fun UserProfile(userId: String) {
    val viewModel: ProfileViewModel = viewModel()

    LaunchedEffect(userId) {
        viewModel.loadProfile(userId)
    }

    // UI content
}
```

---

## Effect Selection Guide

| Effect | Trigger | Cleanup | Use Case |
|--------|---------|---------|----------|
| `LaunchedEffect(key)` | Key changes | Automatic (coroutine cancel) | API calls, one-time loads |
| `DisposableEffect(key)` | Key changes | `onDispose {}` | Listeners, callbacks, resources |
| `LifecycleResumeEffect` | Resume/Pause | `onPauseOrDispose {}` | Media, sensors, connections |
| `SideEffect` | Every recomposition | None | Logging, analytics |

---

## SavedStateHandle (Process Death Survival)

```kotlin
class SearchViewModel(
    private val savedState: SavedStateHandle
) : ViewModel() {
    val query = savedState.getStateFlow("query", "")

    fun updateQuery(newQuery: String) {
        savedState["query"] = newQuery
    }
}
```

**When to use:** For user input that should survive process death (search queries, scroll positions, form data). Regular StateFlow survives configuration changes but NOT process death.

---

## ViewModel Factory with Hilt

```kotlin
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val repository: ProfileRepository,
    private val savedState: SavedStateHandle
) : ViewModel() {
    private val userId: String = checkNotNull(savedState["userId"])
    // ...
}

@Composable
fun ProfileScreen(userId: String) {
    val viewModel: ProfileViewModel = hiltViewModel()
    // ViewModel automatically receives SavedStateHandle with nav args
}
```

---

## Common Anti-Patterns

| DON'T | DO | Why |
|-------|-----|-----|
| `collectAsState()` | `collectAsStateWithLifecycle()` | Lifecycle-aware collection stops when inactive |
| Store Context in ViewModel | Pass via function params | Context leaks, survives config changes |
| Use `GlobalScope` | Use `viewModelScope` | Automatic cancellation on ViewModel clear |
| Fetch data in `@Composable` | Fetch in ViewModel `init` or explicit call | Composables recompose frequently |
| Multiple StateFlows for related state | Single sealed interface UiState | Atomic state updates, no inconsistency |
| `remember` for persistent state | ViewModel | `remember` lost on config change |

---

## Testing ViewModel

```kotlin
@Test
fun `loadFeed success updates state`() = runTest {
    val fakeRepo = FakeFeedRepository(items = listOf(testItem))
    val viewModel = FeedViewModel(fakeRepo)

    viewModel.uiState.test {
        assertEquals(FeedUiState.Loading, awaitItem())
        assertEquals(FeedUiState.Success(listOf(testItem)), awaitItem())
        cancelAndIgnoreRemainingEvents()
    }
}

@Test
fun `loadFeed error updates state`() = runTest {
    val fakeRepo = FakeFeedRepository(error = IOException("Network error"))
    val viewModel = FeedViewModel(fakeRepo)

    viewModel.uiState.test {
        assertEquals(FeedUiState.Loading, awaitItem())
        val errorState = awaitItem() as FeedUiState.Error
        assertEquals("Network error", errorState.message)
        cancelAndIgnoreRemainingEvents()
    }
}
```

**Testing tools:**
- `runTest` - Virtual time, auto-advances delays
- Turbine `.test {}` - Flow assertion DSL
- Fake implementations over mocks for repositories
