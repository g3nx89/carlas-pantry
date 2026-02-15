# Data and Storage Debugging Reference

CLI-only techniques for StrictMode policy enforcement, SQLite/Room database inspection and performance tracing, and SharedPreferences manipulation.

> For UI/layout and memory debugging, see debug-ui-memory.md. For crash analysis and monkey testing, see debug-crashes-monkey.md. For system simulation, see debug-system-simulation.md.

## StrictMode from CLI

StrictMode detects accidental disk/network access on the main thread.

### Enabling in Code (Reference)

```kotlin
if (BuildConfig.DEBUG) {
  StrictMode.setThreadPolicy(
    StrictMode.ThreadPolicy.Builder()
      .detectAll()
      .penaltyLog()
      .build()
  )
  StrictMode.setVmPolicy(
    StrictMode.VmPolicy.Builder()
      .detectAll()
      .penaltyLog()
      .build()
  )
}
```

### CLI Controls

```bash
# Toggle visual indicator (device/build-specific)
adb shell setprop persist.sys.strictmode.visual 1   # Enable
adb shell setprop persist.sys.strictmode.visual 0   # Disable

# Monitor violations in logcat
adb logcat | grep -i strictmode
```

### Device-Wide StrictMode via ADB (No Code Changes)

Enable StrictMode for any app without modifying source code:

```bash
# Method 1: Global settings (screen flash on violations)
adb shell settings put global development_settings_enabled 1
adb shell settings put global strict_mode_enabled 1

# Method 2: System properties (force-enable for ALL apps)
adb shell setprop persist.sys.strictmode.disable false
adb shell setprop debug.strictmode 1

# Filtered logcat for StrictMode only
adb logcat -v long StrictMode:* *:S

# Extra detail level
adb shell setprop log.tag.StrictMode DEBUG
```

**Note**: On Android 9+, some global settings are limited to debuggable apps. Method 2 with system properties is more broadly effective on emulators and rooted devices.

Violations appear in logcat under StrictMode tags. Enable during development to catch disk/network main-thread issues that only surface in production.

## Database Debugging (SQLite / Room)

> **Note:** For basic SQLite/database CLI commands (`run-as`, `sqlite3`, pull-to-host), see `adb-io-system.md` File Operations section. This section covers debugging-specific patterns.

### Debugging Patterns

```bash
# Quick table check without entering interactive shell
adb shell run-as com.example.app sqlite3 databases/mydb.db ".tables"

# Check Room metadata (migration version, identity hash)
adb shell run-as com.example.app sqlite3 databases/mydb.db \
  "SELECT * FROM room_master_table;"

# Dump specific table for comparison
adb shell run-as com.example.app sqlite3 databases/mydb.db \
  -header -csv "SELECT * FROM users;" > users_dump.csv

# Verify schema after Room migration
adb shell run-as com.example.app sqlite3 databases/mydb.db ".schema users"
```

### Copy and Inspect Offline

When you need full database exploration, copy to host:

```bash
adb shell "run-as com.example.app cp databases/mydb.db /sdcard/mydb.db"
adb pull /sdcard/mydb.db .
sqlite3 mydb.db    # On host machine
```

### SQL Performance Tracing (No Code Changes)

Enable verbose SQL statement logging and slow query detection purely via ADB:

```bash
# Log ALL SQL statements to logcat
adb shell setprop log.tag.SQLiteStatements VERBOSE
# Output: D/SQLiteStatements: UPDATE User SET name='...' WHERE id=...

# Log SQL execution times
adb shell setprop log.tag.SQLiteTime VERBOSE
# Output: D/SQLiteTime: Query took 35ms

# Flag any query exceeding a threshold (ms)
adb shell setprop db.log.slow_query_threshold 200
# Any query >200ms appears in logcat

# Monitor SQL activity
adb logcat -v time SQLiteStatements:V SQLiteTime:V *:S
```

Zero-code database debugging: set properties, reproduce the flow, and inspect logcat for slow or unexpected queries. Requires app restart after setting properties.

### Content Providers via CLI

Query system or app Content Providers without code:

```bash
# Query system settings
adb shell content query --uri content://settings/system

# Query SMS (if permissions allow)
adb shell content query --uri content://sms --projection address,body --sort "date DESC"

# Query contacts
adb shell content query --uri content://contacts/phones
```

Useful for reading system state and verifying data. App Room databases typically do not expose ContentProviders unless explicitly configured.

## SharedPreferences from CLI

SharedPreferences are XML files under `/data/data/<package>/shared_prefs/`.

```bash
# Read preferences
adb shell "run-as com.example.app cat shared_prefs/settings.xml"

# Pull for editing
adb shell "run-as com.example.app cat shared_prefs/settings.xml" > settings.xml

# Edit locally, then push back
adb shell "run-as com.example.app sh -c 'cat > shared_prefs/settings.xml'" < settings.xml
```

### Full Round-Trip Modification (cp-based)

When the `cat` redirect method fails (permission issues on some devices):

```bash
# Copy out via /sdcard intermediary
adb shell "run-as com.example.app cp shared_prefs/settings.xml /sdcard/settings.xml"
adb pull /sdcard/settings.xml .

# Edit locally with any editor
# ... edit settings.xml ...

# Push back via /sdcard intermediary
adb push settings.xml /sdcard/settings.xml
adb shell "run-as com.example.app cp /sdcard/settings.xml shared_prefs/settings.xml"

# Alternative: exec-out to avoid /sdcard entirely
adb exec-out run-as com.example.app cat shared_prefs/settings.xml > local.xml
```

**Critical**: Pushing back preferences while the app is running has no effect until the app is killed and restarted. The in-memory SharedPreferences cache takes precedence:

```bash
adb shell am force-stop com.example.app
# Now restart — app loads the modified XML
```

### Dump Loaded Preferences (Runtime Inspection)

```bash
adb shell dumpsys activity preferences com.example.app
```

Prints currently loaded preference files and their values without pulling XML files. Useful for quick runtime inspection.

Use these techniques to flip feature flags, simulate corrupted preferences, or reset state between test runs.
