param(
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "debug"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$vcvars = Join-Path $repoRoot ".tools\vs2022buildtools\VC\Auxiliary\Build\vcvarsall.bat"

if (-not (Test-Path $vcvars)) {
    throw "Local VS Build Tools not found at $vcvars. Install VS 2022 Build Tools (C++ desktop) under .tools/vs2022buildtools."
}

# Avoid PATH overflow from repeated dev-shell launches in the same session.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

& (Join-Path $PSScriptRoot "patch_firebase_windows.ps1")

Push-Location $repoRoot
try {
    $flutterArgs = switch ($Mode) {
        "debug" { "flutter", "build", "windows", "--debug" }
        "profile" { "flutter", "build", "windows", "--profile" }
        "release" { "flutter", "build", "windows", "--release" }
    }
    cmd /c "call `"$vcvars`" x64 >nul && $($flutterArgs -join ' ')"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}
