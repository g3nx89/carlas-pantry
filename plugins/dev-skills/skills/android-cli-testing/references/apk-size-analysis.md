# APK Size Analysis Reference

CLI workflows for APK and AAB size analysis, optimization verification, and CI-integrated size regression tracking.

> For benchmark execution and regression detection, see `benchmark-cli.md`. For CI pipeline integration, see `ci-pipeline-config.md`. For R8/ProGuard impact on Baseline Profiles, see `benchmark-cli.md` > R8/Obfuscation Gotcha.

> **TL;DR**: Analyze APK with `apkanalyzer apk file-size/download-size`, compare builds with `apkanalyzer apk compare`, measure AAB with `bundletool get-size total`, verify R8 with `apkanalyzer dex packages`, track CI size via `size-history.json` comparison, check DEX method count against 64K limit.

## Size Breakdown with apkanalyzer

Location: `$ANDROID_HOME/cmdline-tools/latest/bin/apkanalyzer`

```bash
# Overall size
apkanalyzer apk file-size app-release.apk
apkanalyzer apk download-size app-release.apk  # Compressed download size

# Human-readable output
apkanalyzer -h apk file-size app-release.apk

# List all files with sizes (path, raw_size, download_size)
apkanalyzer files list app-release.apk

# Size by component
apkanalyzer files list app-release.apk | head -20
apkanalyzer dex packages --defined-only app-release.apk | head -20

# Resources breakdown
apkanalyzer resources configs --type drawable app-release.apk

# List resource names for a config/type
apkanalyzer resources names --config default --type drawable app-release.apk

# Print specific resource value
apkanalyzer resources value --config default --name app_name --type string app-release.apk

# Decode binary XML
apkanalyzer resources xml --file /res/layout/activity_main.xml app-release.apk

# DEX method/reference count (64K limit monitoring)
apkanalyzer dex references app-release.apk

# App summary (ID, version code, version name)
apkanalyzer apk summary app-release.apk

# Manifest inspection
apkanalyzer manifest print app-release.apk
apkanalyzer manifest min-sdk app-release.apk
apkanalyzer manifest target-sdk app-release.apk
apkanalyzer manifest permissions app-release.apk
apkanalyzer manifest debuggable app-release.apk

# Device features required
apkanalyzer apk features app-release.apk
```

## APK Comparison

```bash
# Full comparison (old_size new_size diff path)
apkanalyzer apk compare old-release.apk new-release.apk

# Only files that changed, no directories
apkanalyzer apk compare --different-only --files-only old-release.apk new-release.apk

# With patch-size estimates (BsDiff-style)
apkanalyzer apk compare --patch-size old-release.apk new-release.apk
```

Example output format:
```
39086736  48855615   9768879  /
10678448  11039232    360784  /classes.dex
18968956  18968956         0  /lib/
  110576    110100      -476  /AndroidManifest.xml
```

## Size Tracking with bundletool

```bash
# Build universal APK from AAB
bundletool build-apks --bundle=app-release.aab --output=app.apks --mode=universal

# Device-specific APK set
bundletool build-apks --connected-device --bundle=app-release.aab --output=app.apks

# From device spec JSON
bundletool build-apks --device-spec=pixel6.json --bundle=app-release.aab --output=app.apks

# Total estimated download size (MIN and MAX across configs)
bundletool get-size total --apks=app.apks
# Output: MIN,MAX (bytes)

# Size broken down by ABI
bundletool get-size total --apks=app.apks --dimensions=ABI

# Size broken down by all dimensions
bundletool get-size total --apks=app.apks --dimensions=ALL

# Size for specific device
bundletool get-size total --apks=app.apks --device-spec=pixel6.json

# Size of specific modules only
bundletool get-size total --apks=app.apks --modules=base,feature1

# Generate device spec from connected device
bundletool get-device-spec --output=device-spec.json
```

Device spec JSON format:
```json
{
  "supportedAbis": ["arm64-v8a", "armeabi-v7a"],
  "supportedLocales": ["en", "fr"],
  "screenDensity": 420,
  "sdkVersion": 33
}
```

## R8/ProGuard Analysis from CLI

### Mapping File Analysis

```bash
# Count kept classes (lines with -> mapping = classes R8 kept)
grep -c '^\S.* -> ' build/outputs/mapping/release/mapping.txt
# Compare to total classes in source for removal ratio

# Count obfuscated methods
grep -c '^\s' build/outputs/mapping/release/mapping.txt

# Verify specific class was removed (no mapping = removed by R8)
grep 'com.example.UnusedClass' build/outputs/mapping/release/mapping.txt

# Retrace obfuscated stack trace
$ANDROID_HOME/cmdline-tools/latest/bin/retrace mapping.txt stacktrace.txt
```

### Optimization Verification

```bash
# Verify R8 is enabled in build output
./gradlew assembleRelease 2>&1 | grep -i "r8\|minify\|shrink"

# Compare debug vs release DEX method counts
apkanalyzer dex references app-debug.apk
apkanalyzer dex references app-release.apk

# Check what R8 removed: --show-removed flag
apkanalyzer dex packages --show-removed \
  --proguard-mappings build/outputs/mapping/release/mapping.txt \
  app-release.apk

# With ProGuard mapping for deobfuscation of package tree
apkanalyzer dex packages --proguard-mappings mapping.txt app-release.apk

# Show removed classes/methods (what R8 stripped)
apkanalyzer dex packages --show-removed --proguard-folder build/outputs/mapping/ app-release.apk
```

### Kotlin Metadata Stripping

R8 automatically strips unused Kotlin metadata annotations. To verify:

```bash
# Check if kotlin.Metadata annotations remain in release APK
apkanalyzer dex packages --defined-only app-release.apk | grep -i "kotlin.Metadata"
# Minimal or no output = metadata properly stripped

# Aggressive stripping rule (add to proguard-rules.pro):
# -assumenosideeffects class kotlin.jvm.internal.Intrinsics { *; }
```

## R8 Full Mode vs Compatibility Mode

AGP 8+ defaults to R8 full mode (`android.enableR8.fullMode=true` in `gradle.properties`), producing ~5-15% smaller DEX than compatibility mode.

```bash
# Verify active mode (present and true = full mode)
grep 'android.enableR8.fullMode' gradle.properties

# Verify R8 optimizations: check remaining classes
apkanalyzer dex packages app-release.apk --defined-only | wc -l
```

**Gotcha:** Full mode breaks libraries relying on reflection without keep rules. If a library crashes only in release builds after AGP upgrade, add `-keep` rules or revert with `android.enableR8.fullMode=false`.

## Resource Shrinking Verification

### Unused Resources Detection

```bash
# Run lint check for unused resources only
./gradlew :app:lintDebug -Dlint.baselines.continue=true 2>&1 | grep UnusedResources

# Generate XML report
./gradlew :app:lint
# Report at: app/build/reports/lint-results-debug.xml

# Count unused resources from lint XML
grep -c 'UnusedResources' app/build/reports/lint-results-debug.xml
```

### Resource Table Analysis

```bash
# Verify shrinkResources removed entries
apkanalyzer resources packages app-release.apk

# Compare resource counts: debug vs release
apkanalyzer resources names --config default --type drawable app-debug.apk | wc -l
apkanalyzer resources names --config default --type drawable app-release.apk | wc -l

# Check for dummy/placeholder resources (shrinkResources replaces with empty files)
apkanalyzer files list app-release.apk | awk '$2 == 0 {print $0}' | head -20
```

## Native Library Size Analysis

### Per-ABI Breakdown

```bash
# List native libs with sizes
apkanalyzer files list app-release.apk | grep '\.so$'
# Output shows /lib/arm64-v8a/libfoo.so  raw_size  download_size

# Per-ABI size totals
for abi in armeabi-v7a arm64-v8a x86 x86_64; do
  SIZE=$(apkanalyzer files list app-release.apk | grep "/lib/$abi/" | awk '{sum+=$2} END {print sum}')
  echo "$abi: $SIZE bytes"
done

# AAB per-ABI size analysis
bundletool get-size total --apks=app.apks --dimensions=ABI
```

### Symbol Stripping Verification

```bash
# Check if .so is stripped (look for "stripped" in output)
file lib/arm64-v8a/libnative.so
# Stripped:     "ELF 64-bit LSB shared object, ARM aarch64, ... stripped"
# Not stripped: "ELF 64-bit LSB shared object, ARM aarch64, ... not stripped"

# Check for debug sections with readelf
readelf -S lib/arm64-v8a/libnative.so | grep -c debug
# 0 = properly stripped, >0 = debug info present

# NDK strip command
$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/*/bin/llvm-strip --strip-unneeded libnative.so

# Verify with llvm-readelf from NDK
$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/*/bin/llvm-readelf -S libnative.so | grep -E "\.debug|\.symtab"

# Check exported symbols count (fewer = smaller)
nm -D libnative.so | wc -l
```

## DEX File Analysis

### Method Count Tools

```bash
# apkanalyzer: total method references
apkanalyzer dex references app-release.apk

# Per-DEX method references
apkanalyzer dex references --files classes.dex app-release.apk

# List all DEX files
apkanalyzer dex list app-release.apk

# Class tree with defined/referenced counts per package
# Columns: type(P/C/M/F) state(x/k/r/d) defined referenced name
apkanalyzer dex packages --defined-only app-release.apk

# Smali bytecode for a class
apkanalyzer dex code --class com.example.MainActivity app-release.apk

# dex-method-counts: per-package breakdown (https://github.com/mihaip/dex-method-counts)
./dex-method-counts app-release.apk
# Output: hierarchical package tree with method counts

# With per-class detail
./dex-method-counts --include-classes app-release.apk

# Dexcount Gradle plugin (per-build tracking)
# plugins { id("com.getkeepsafe.dexcount") }
# Prints method/field count after each build
```

### 64K Reference Limit Monitoring

```bash
# Per-DEX method reference count
apkanalyzer dex references app-release.apk

# Alert threshold: flag when primary DEX exceeds 60K references (buffer for growth)
REFS=$(apkanalyzer dex references --files classes.dex app-release.apk)
[ "$REFS" -gt 60000 ] && echo "WARNING: primary DEX at $REFS/65536 references"

# Top reference contributors by package
apkanalyzer dex packages app-release.apk --defined-only | sort -t$'\t' -k4 -rn | head -20
```

Additional DEX files add ~100-200KB each plus class loading latency on pre-API-21 devices (legacy multidex).

### Bytecode Inspection

```bash
# Inspect DEX bytecode for a specific method
apkanalyzer dex code --class com.example.MyClass --method myMethod app-release.apk

# With ProGuard mapping for obfuscated APKs
apkanalyzer dex code --class a.b.C --method d \
  --proguard-mappings build/outputs/mapping/release/mapping.txt app-release.apk
```

Use case: verify R8 inlined a method (absent from output) or check for unexpectedly large method bodies.

### Multidex Overhead

```bash
# Count DEX files
apkanalyzer dex list app-release.apk | wc -l

# Size of each DEX
apkanalyzer files list app-release.apk | grep 'classes.*\.dex'

# Method distribution across DEX files
for dex in $(apkanalyzer dex list app-release.apk); do
  REFS=$(apkanalyzer dex references --files "$dex" app-release.apk)
  echo "$dex: $REFS method refs"
done
```

## Download vs Install vs On-Disk Size

Three distinct size measurements relevant to Google Play:

- **Download size**: Compressed APK/split transferred over network. Google Play limit: 150MB for AAB (200MB with on-demand). `apkanalyzer apk download-size` approximates this.
- **Install size**: Uncompressed on-device size. Always larger than download. `bundletool get-size total` estimates this.
- **On-disk size**: Install size + runtime data/cache. Not predictable from CLI.

```bash
# Predict download size (closest to Play Store reporting)
apkanalyzer apk download-size app-release.apk

# For AABs, bundletool is more accurate
bundletool build-apks --bundle=app-release.aab --output=app.apks
bundletool get-size total --apks=app.apks
# Output: MIN,MAX bytes (range across all device configs)

# Per-device prediction
bundletool get-size total --apks=app.apks \
  --device-spec=pixel6.json --dimensions=ABI,SCREEN_DENSITY
```

Play Store impact: every 6MB increase in APK size results in approximately 1% decrease in install conversion rate.

## CI Size Tracking

### Simple Threshold Enforcement

```bash
#!/bin/bash
# Fail CI if APK exceeds size threshold
MAX_SIZE_BYTES=20971520  # 20 MB
APK="app/build/outputs/apk/release/app-release.apk"

ACTUAL=$(stat -f%z "$APK" 2>/dev/null || stat -c%s "$APK" 2>/dev/null)
if [ "$ACTUAL" -gt "$MAX_SIZE_BYTES" ]; then
  echo "APK size regression: ${ACTUAL} bytes exceeds limit of ${MAX_SIZE_BYTES} bytes"
  exit 1
fi
echo "APK size OK: ${ACTUAL} bytes (limit: ${MAX_SIZE_BYTES})"
```

### AAB Size Tracking in CI

```bash
# Build, measure, compare in CI
bundletool build-apks --bundle=app.aab --output=current.apks
CURRENT=$(bundletool get-size total --apks=current.apks | tail -1 | cut -d, -f1)
BASELINE=$(cat .size-baseline)
DIFF=$((CURRENT - BASELINE))
if [ $DIFF -gt 524288 ]; then  # 512KB threshold
  echo "FAIL: Size increased by $DIFF bytes (threshold: 524288)"
  exit 1
fi
```

### Baseline Comparison Script

```bash
#!/bin/bash
# ci/check-apk-size.sh — multi-metric baseline tracking
APK="$1"
BASELINE_FILE=".apk-size-baseline"

CURRENT_SIZE=$(apkanalyzer apk file-size "$APK")
CURRENT_DOWNLOAD=$(apkanalyzer apk download-size "$APK")
CURRENT_METHODS=$(apkanalyzer dex references "$APK")

if [ -f "$BASELINE_FILE" ]; then
  read BASE_SIZE BASE_DOWNLOAD BASE_METHODS < "$BASELINE_FILE"
  SIZE_DIFF=$((CURRENT_SIZE - BASE_SIZE))
  METHOD_DIFF=$((CURRENT_METHODS - BASE_METHODS))

  echo "| Metric | Baseline | Current | Delta |"
  echo "|--------|----------|---------|-------|"
  echo "| APK Size | $BASE_SIZE | $CURRENT_SIZE | $SIZE_DIFF |"
  echo "| Download | $BASE_DOWNLOAD | $CURRENT_DOWNLOAD | $((CURRENT_DOWNLOAD - BASE_DOWNLOAD)) |"
  echo "| Methods  | $BASE_METHODS | $CURRENT_METHODS | $METHOD_DIFF |"

  # Fail on >500KB growth or >1000 new methods
  if [ $SIZE_DIFF -gt 524288 ] || [ $METHOD_DIFF -gt 1000 ]; then
    echo "FAIL: Size regression detected"
    exit 1
  fi
fi

echo "$CURRENT_SIZE $CURRENT_DOWNLOAD $CURRENT_METHODS" > "$BASELINE_FILE"
```

### GitHub Actions Size Comment Bot

```yaml
# .github/workflows/size-check.yml
name: APK Size Check
on: pull_request
jobs:
  size-diff:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build base APK
        run: git stash && git checkout ${{ github.base_ref }} && ./gradlew assembleRelease
      - name: Save base APK
        run: cp app/build/outputs/apk/release/app-release.apk base.apk
      - name: Build target APK
        run: git checkout - && git stash pop && ./gradlew assembleRelease
      - uses: microsoft/android-app-size-diff@v1
        with:
          baseAppPath: base.apk
          targetAppPath: app/build/outputs/apk/release/app-release.apk
          summaryOutputPath: size-report.md
          metrics: apkSize,installSize,dexFiles,arscFile,nativeLibs
          thresholds: 524288,1048576,262144,131072,524288
      - name: Comment PR
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          path: size-report.md
```

### apkdiff Tool

```bash
# https://github.com/radekdoulik/apkdiff
apkdiff old.apk new.apk
apkdiff --test-apk-size-regression=524288 old.apk new.apk      # Fail if >512KB growth
apkdiff --test-apk-percentage-regression=5 old.apk new.apk      # Fail if >5% growth
```

## Size Optimization Techniques (CLI-Verifiable)

### Image Optimization

```bash
# Convert PNG to WebP (cwebp from libwebp)
cwebp -q 80 image.png -o image.webp
# Typical savings: 25-35% vs PNG, verify: ls -la image.{png,webp}

# Batch convert (skip 9-patch PNGs)
find app/src/main/res -name "*.png" ! -name "*.9.png" -exec sh -c \
  'cwebp -q 80 "$1" -o "${1%.png}.webp" && rm "$1"' _ {} \;

# PNG optimization (lossless)
pngquant --quality=65-80 --skip-if-larger --ext .png --force image.png
optipng -o5 image.png

# JPEG optimization
jpegoptim --max=80 --strip-all image.jpg

# Find oversized resources in APK
apkanalyzer files list app-release.apk | grep '/res/' | sort -t$'\t' -k2 -rn | head -20
```

### Vector vs Raster Verification

```bash
# Count vector drawables vs PNGs in APK
apkanalyzer files list app-release.apk | grep -c '\.xml.*drawable'
apkanalyzer files list app-release.apk | grep -c '\.png'

# Find PNGs that could be vectors (small icons, simple shapes under 10KB)
apkanalyzer files list app-release.apk | grep '\.png' | awk '$2 < 10000 {print}'
```

## Size Reduction Summary

| Technique | Typical Savings | CLI Verification |
|-----------|----------------|------------------|
| R8 shrinking + obfuscation | 20-40% of DEX | `apkanalyzer dex references` before/after |
| Resource shrinking | 5-15% | `apkanalyzer files list \| grep res \| awk '{sum+=$2} END{print sum}'` |
| PNG to WebP conversion | 25-35% of images | `cwebp` + file size comparison |
| AAB vs fat APK | 20-40% download | `bundletool get-size total --dimensions=ABI` |
| Vector drawables replacing PNGs | 50-80% per icon | `apkanalyzer files list \| grep drawable` |
| Native lib stripping | 30-50% of .so files | `file lib.so` check for "stripped" |
| ProGuard aggressive optimization | additional 5-10% | `apkanalyzer apk compare` debug vs release |
| Remove unused ABIs | 50-75% of lib/ | `apkanalyzer files list \| grep /lib/` per-ABI |
| Kotlin metadata stripping | 1-3% of DEX | Automatic with R8 in release builds |

Documented case studies report combined reductions of 54-65% when applying multiple techniques simultaneously.
