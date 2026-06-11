# Registers local Android signing SHA-1/SHA-256 with Firebase and refreshes
# android/app/google-services.json. Requires: npx firebase-tools login.
param(
  [string]$ProjectId = "blindbox-collection",
  [string]$AndroidAppId = "1:1094225908408:android:73c90529f8d1a923c81a4d"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$googleServices = Join-Path $repoRoot "android\app\google-services.json"

function Invoke-Firebase {
  param([string[]]$FirebaseArgs)
  & npx --yes firebase-tools@14.11.0 @FirebaseArgs
  if ($LASTEXITCODE -ne 0) {
    throw "firebase command failed: firebase $($FirebaseArgs -join ' ')"
  }
}

function Normalize-Sha([string]$value) {
  return ($value -replace ":", "").ToLowerInvariant()
}

Push-Location (Join-Path $repoRoot "android")
try {
  $report = & .\gradlew signingReport 2>&1 | Out-String
} finally {
  Pop-Location
}

$variant = $null
$hashes = [ordered]@{}
foreach ($line in $report -split "`r?`n") {
  if ($line -match '^\s*Variant:\s*(\S+)') { $variant = $Matches[1] }
  if ($null -eq $variant) { continue }
  if ($line -match '^\s*SHA1:\s*([0-9A-F:]+)$') {
    $hashes["$variant|sha1"] = Normalize-Sha $Matches[1]
  }
  if ($line -match '^\s*SHA-256:\s*([0-9A-F:]+)$') {
    $hashes["$variant|sha256"] = Normalize-Sha $Matches[1]
  }
}

$toRegister = @(
  $hashes["debug|sha1"],
  $hashes["debug|sha256"],
  $hashes["release|sha1"],
  $hashes["release|sha256"]
) | Where-Object { $_ } | Select-Object -Unique

if ($toRegister.Count -eq 0) {
  throw "No SHA hashes parsed from gradlew signingReport"
}

$existing = & npx --yes firebase-tools@14.11.0 apps:android:sha:list $AndroidAppId --project $ProjectId 2>&1 | Out-String
foreach ($sha in $toRegister) {
  if ($existing -match [regex]::Escape($sha)) {
    Write-Host "SHA already registered: $sha"
    continue
  }
  Write-Host "Registering SHA: $sha"
  Invoke-Firebase @("apps:android:sha:create", $AndroidAppId, $sha, "--project", $ProjectId)
}

Write-Host "Downloading google-services.json"
$json = & npx --yes firebase-tools@14.11.0 apps:sdkconfig ANDROID $AndroidAppId --project $ProjectId 2>&1 | Out-String
$start = $json.IndexOf("{")
if ($start -lt 0) { throw "sdkconfig output did not include JSON" }
$payload = $json.Substring($start).Trim()
Set-Content -Path $googleServices -Value $payload -NoNewline
Write-Host "Wrote $googleServices"
Write-Host "Reinstall on device: flutter clean && flutter run"
