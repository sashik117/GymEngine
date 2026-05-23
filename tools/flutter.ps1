param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $FlutterArgs
)

$repoRoot = Split-Path -Parent $PSScriptRoot
$flutter = Join-Path $repoRoot "src\flutter\bin\flutter.bat"

if (-not (Test-Path $flutter)) {
  Write-Error "Flutter SDK was not found at $flutter"
  exit 1
}

& $flutter @FlutterArgs
exit $LASTEXITCODE
