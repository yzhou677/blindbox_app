# Patches pub-cache Firebase Windows artifacts for this machine's toolchain.
# Run after `flutter pub get` when Windows desktop linking fails.
param(
    [string]$FirebaseSdkVersion = "13.0.0"
)

$ErrorActionPreference = "Stop"
$pubCache = Join-Path $env:LOCALAPPDATA "Pub\Cache\hosted\pub.dev"

$coreCmake = Join-Path $pubCache "firebase_core-4.9.0\windows\CMakeLists.txt"
if (-not (Test-Path $coreCmake)) {
    throw "firebase_core windows CMake not found at $coreCmake"
}
$coreText = Get-Content $coreCmake -Raw
$coreText = $coreText -replace 'set\(FIREBASE_SDK_VERSION "[0-9.]+"\)', "set(FIREBASE_SDK_VERSION `"$FirebaseSdkVersion`")"
Set-Content $coreCmake $coreText -NoNewline
Write-Host "Set FIREBASE_SDK_VERSION=$FirebaseSdkVersion in firebase_core"

$storagePlugin = Join-Path $pubCache "firebase_storage-13.4.1\windows\firebase_storage_plugin.cpp"
if (-not (Test-Path $storagePlugin)) {
    throw "firebase_storage windows plugin not found at $storagePlugin"
}
$storageText = Get-Content $storagePlugin -Raw
if ($storageText -match 'cpp_storage->UseEmulator') {
    $storageText = $storageText -replace '(?ms)  Storage\* cpp_storage = GetCPPStorageFromPigeon\(app, ""\);\r?\n  cpp_storage->UseEmulator\(host, static_cast<int>\(port\)\);\r?\n  result\(std::nullopt\);', @'
  Storage* cpp_storage = GetCPPStorageFromPigeon(app, "");
  // Firebase C++ SDK < 13.1 has no Storage::UseEmulator on Windows desktop.
  (void)cpp_storage;
  (void)host;
  (void)port;
  result(std::nullopt);
'@
    Set-Content $storagePlugin $storageText -NoNewline
    Write-Host "Patched firebase_storage UseStorageEmulator no-op"
} elseif ($storageText -match '\(void\)cpp_storage;') {
    Write-Host "firebase_storage UseEmulator already patched"
} else {
    throw "firebase_storage_plugin.cpp changed upstream; update patch script"
}
