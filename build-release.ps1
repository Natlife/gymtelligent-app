$ErrorActionPreference = "Stop"

# ============================================================
#  Gymtelligent - Production APK Build Script
#  Edit release-version.txt to control the exported APK name.
#  Edit config/env/production.json to control build-time app config.
#  Output: dist/mobile/gymtelligent-v<version>-android-release.apk
# ============================================================

$KEYSTORE = "android\app\gymtelligent-release.jks"
$VERSION_FILE = "release-version.txt"
$ENV_FILE = "config/env/production.json"
$OUTPUT_DIR = "dist\mobile"
$PRIMARY_SOURCE_APK = "build\app\outputs\flutter-apk\app-release.apk"
$FALLBACK_SOURCE_APK = "build\app\outputs\apk\release\app-release.apk"
$SOURCE_AAB = "build\app\outputs\bundle\release\app-release.aab"

function Read-ReleaseVersion {
    if (-not (Test-Path $VERSION_FILE)) {
        throw "Missing $VERSION_FILE. Create it with a value like: 1.0.0"
    }

    $version = (Get-Content $VERSION_FILE -Raw).Trim()

    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "$VERSION_FILE is empty. Set a value like: 1.0.0"
    }

    if ($version -match '[\\/:*?"<>|]') {
        throw "$VERSION_FILE contains characters that are not valid in a file name."
    }

    return $version
}

function Read-AppEnvironment {
    if (-not (Test-Path $ENV_FILE)) {
        throw "Missing $ENV_FILE. Copy config/env/production.example.json to $ENV_FILE and update it."
    }

    try {
        $envConfig = Get-Content $ENV_FILE -Raw | ConvertFrom-Json
    } catch {
        throw "$ENV_FILE is not valid JSON."
    }

    if ([string]::IsNullOrWhiteSpace($envConfig.API_BASE_URL)) {
        throw "$ENV_FILE must define API_BASE_URL."
    }

    return $envConfig
}

$RELEASE_VERSION = Read-ReleaseVersion
$APP_ENV_CONFIG = Read-AppEnvironment
$FINAL_APK_NAME = "gymtelligent-v$RELEASE_VERSION.apk"
$FINAL_APK_PATH = Join-Path $OUTPUT_DIR $FINAL_APK_NAME
$FINAL_AAB_NAME = "gymtelligent-v$RELEASE_VERSION.aab"
$FINAL_AAB_PATH = Join-Path $OUTPUT_DIR $FINAL_AAB_NAME

Write-Host ""
Write-Host "[1/5] Checking prerequisites..." -ForegroundColor Cyan
Write-Host "      Release version: v$RELEASE_VERSION" -ForegroundColor Gray
Write-Host "      Environment file: $ENV_FILE" -ForegroundColor Gray
Write-Host "      App env: $($APP_ENV_CONFIG.APP_ENV)" -ForegroundColor Gray
Write-Host "      API URL: $($APP_ENV_CONFIG.API_BASE_URL)" -ForegroundColor Gray

if (-not (Test-Path $KEYSTORE)) {
    Write-Host ""
    Write-Host "[WARNING] Release keystore not found at: $KEYSTORE" -ForegroundColor Yellow
    Write-Host "          Run: keytool -genkey -v -keystore $KEYSTORE -keyalg RSA -keysize 2048 -validity 10000 -alias gymtelligent" -ForegroundColor White
    Write-Host "          Then fill in android\key.properties (copy from key.properties.example)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[WARNING] Building with DEBUG signing key. NOT suitable for Play Store." -ForegroundColor Red
}

if (-not (Test-Path "android\key.properties")) {
    Write-Host "[WARNING] android\key.properties not found. Using debug signing." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[2/5] Cleaning previous build..." -ForegroundColor Cyan
flutter clean

Write-Host ""
Write-Host "[3/5] Fetching dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host ""
Write-Host "[4/5] Building release APK and App Bundle (AAB)..." -ForegroundColor Cyan

# Clean old artifacts to prevent copying stale files
if (Test-Path $PRIMARY_SOURCE_APK) { Remove-Item $PRIMARY_SOURCE_APK -Force }
if (Test-Path $FALLBACK_SOURCE_APK) { Remove-Item $FALLBACK_SOURCE_APK -Force }
if (Test-Path $SOURCE_AAB) { Remove-Item $SOURCE_AAB -Force }

Write-Host "      Building APK..." -ForegroundColor Gray
& flutter build apk --release "--dart-define-from-file=$ENV_FILE"

Write-Host "      Building App Bundle (AAB)..." -ForegroundColor Gray
# The App Bundle build might exit with non-zero code due to symbol stripping issues with NDK 28,
# but the AAB itself is successfully compiled and signed by Gradle.
$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& flutter build appbundle --release "--dart-define-from-file=$ENV_FILE"
$ErrorActionPreference = $oldPreference

# Verify APK build
if (Test-Path $PRIMARY_SOURCE_APK) {
    $SOURCE_APK = $PRIMARY_SOURCE_APK
} elseif (Test-Path $FALLBACK_SOURCE_APK) {
    $SOURCE_APK = $FALLBACK_SOURCE_APK
} else {
    Write-Host ""
    Write-Host "[ERROR] Build failed - APK not found." -ForegroundColor Red
    exit 1
}

# Verify AAB build
if (-not (Test-Path $SOURCE_AAB)) {
    Write-Host ""
    Write-Host "[ERROR] Build failed - App Bundle (AAB) not found." -ForegroundColor Red
    Write-Host "        Checked: $SOURCE_AAB" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[5/5] Exporting versioned artifacts..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null
Copy-Item -LiteralPath $SOURCE_APK -Destination $FINAL_APK_PATH -Force
Copy-Item -LiteralPath $SOURCE_AAB -Destination $FINAL_AAB_PATH -Force

$apkSize = [math]::Round((Get-Item $FINAL_APK_PATH).Length / 1MB, 2)
$aabSize = [math]::Round((Get-Item $FINAL_AAB_PATH).Length / 1MB, 2)

Write-Host ""
Write-Host "[OK] Build successful!" -ForegroundColor Green
Write-Host "     APK: $((Get-Item $FINAL_APK_PATH).FullName)" -ForegroundColor Green
Write-Host "     Size (APK): ${apkSize} MB" -ForegroundColor Green
Write-Host "     AAB: $((Get-Item $FINAL_AAB_PATH).FullName)" -ForegroundColor Green
Write-Host "     Size (AAB): ${aabSize} MB" -ForegroundColor Green
