<#
=====================================================================
  Cleanup-WH-AI.ps1  -  Completely remove WOHHUP x AI / WOHHUPxAI (WH-AI)
  App + Revit add-in + user data + registry + shortcuts.

  USE WHEN: a machine has an OLD build and you want a clean slate
  before installing the new version.

  HOW TO RUN (right-click > Run with PowerShell, OR):
      powershell -ExecutionPolicy Bypass -File .\Cleanup-WH-AI.ps1
  Preview only (deletes nothing):
      powershell -ExecutionPolicy Bypass -File .\Cleanup-WH-AI.ps1 -DryRun
  Skip the confirmation prompt:
      powershell -ExecutionPolicy Bypass -File .\Cleanup-WH-AI.ps1 -Yes

  REQUIREMENT: CLOSE Revit and the app first. If Revit is open, add-in
  DLLs are locked and will report FAILED - close Revit and re-run.
  If an OLD build was installed under Program Files, run as Administrator.

  SAFE: touches ONLY WH-AI / WOHHUPxAI artifacts (fixed names + GUID).
  Does NOT touch other add-ins: WohhupMainApp, WohhupRevitLibrary,
  WohhupQAQC, WohhupSetting, TH Tools, THBIM, RevitAddinManager.
=====================================================================
#>

param(
    [switch]$DryRun,   # list only, delete nothing
    [switch]$Yes       # skip the confirmation prompt
)

$ErrorActionPreference = 'Continue'

# ---- WH-AI identifiers (from source, stable across all builds) ----
$AddinId       = '5c8c257d-f446-4a4b-8e29-798c56637b92'   # unique add-in AddInId
$AddinFolder   = 'WH-AI'                                    # add-in folder in Addins\<year>
$AddinManifest = 'WOHHUP-MCP-REVIT.addin'                  # .addin manifest name
$ProcNames     = @('WOHHUPxAI', 'MCP-REVIT-Desktop')       # process names, all builds
# Installer AppIds (3 generations) -> Uninstall key "..._is1"
$AppIds        = @(
    '8F4C9E1D-7B23-4A56-9E0F-1A2B3C4D5E6F',  # current
    'A1B2C3D4-E5F6-7890-ABCD-EF1234567890',  # middle
    '10FF325D-B833-4D9D-930D-11756A491FEF'   # oldest (Program Files)
)
$RevitYears    = 2022..2028   # scan wide to be safe

# ---- counters + helpers ----
$script:nRemoved = 0; $script:nMissing = 0; $script:nFailed = 0
$script:failedPaths = @()

function Write-Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }

function Remove-Target([string]$path, [string]$label) {
    if ([string]::IsNullOrWhiteSpace($path)) { return }
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host ("  [ -- ] Not present: {0}" -f $path) -ForegroundColor DarkGray
        $script:nMissing++; return
    }
    if ($DryRun) {
        Write-Host ("  [DRY ] Would delete: {0}" -f $path) -ForegroundColor Yellow
        return
    }
    # Retry: a just-killed process can hold a handle for a moment.
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
            Write-Host ("  [ OK ] Deleted: {0}" -f $path) -ForegroundColor Green
            $script:nRemoved++; return
        } catch {
            if ($attempt -ge 3) {
                Write-Host ("  [FAIL] Could NOT delete: {0}  ({1})" -f $path, $_.Exception.Message) -ForegroundColor Red
                $script:nFailed++; $script:failedPaths += $path
            } else { Start-Sleep -Milliseconds 700 }
        }
    }
}

function Remove-RegValue([string]$key, [string]$name) {
    if ($DryRun) {
        if (Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue) {
            Write-Host ("  [DRY ] Would delete reg value: {0}\{1}" -f $key, $name) -ForegroundColor Yellow
        }
        return
    }
    try {
        if (Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $key -Name $name -Force -ErrorAction Stop
            Write-Host ("  [ OK ] Deleted reg value: {0}\{1}" -f $key, $name) -ForegroundColor Green
            $script:nRemoved++
        }
    } catch {
        Write-Host ("  [FAIL] reg value {0}\{1}: {2}" -f $key, $name, $_.Exception.Message) -ForegroundColor Red
        $script:nFailed++
    }
}

function Remove-RegKey([string]$key) {
    if (-not (Test-Path $key)) { return }
    if ($DryRun) { Write-Host ("  [DRY ] Would delete reg key: {0}" -f $key) -ForegroundColor Yellow; return }
    try {
        Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
        Write-Host ("  [ OK ] Deleted reg key: {0}" -f $key) -ForegroundColor Green
        $script:nRemoved++
    } catch {
        Write-Host ("  [FAIL] reg key {0}: {1}" -f $key, $_.Exception.Message) -ForegroundColor Red
        $script:nFailed++
    }
}

# =====================================================================
Write-Host "========================================================" -ForegroundColor White
Write-Host "  Clean removal of WOHHUP x AI / WOHHUPxAI (WH-AI)" -ForegroundColor White
if ($DryRun) { Write-Host "  *** PREVIEW MODE (DryRun) - deletes nothing ***" -ForegroundColor Yellow }
Write-Host "========================================================" -ForegroundColor White

# ---- Warn if Revit is open (add-in DLLs will be locked) ----
$revit = Get-Process -Name 'Revit' -ErrorAction SilentlyContinue
if ($revit) {
    Write-Host "`n[!] REVIT IS RUNNING - add-in files are locked and cannot be deleted." -ForegroundColor Red
    Write-Host "    Close ALL Revit windows, then re-run this script." -ForegroundColor Red
}

# ---- Warn about admin (only needed if an old Program Files build exists) ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$oldPF   = @("$env:ProgramFiles\WohhupAI", "$env:ProgramW6432\WohhupAI") | Where-Object { $_ -and (Test-Path $_) }
if ($oldPF -and -not $isAdmin) {
    Write-Host "`n[!] An old build was found under Program Files, but you are NOT running as admin." -ForegroundColor Yellow
    Write-Host "    Removing it needs admin - right-click PowerShell > Run as administrator." -ForegroundColor Yellow
}

# ---- Confirm ----
if (-not $DryRun -and -not $Yes) {
    Write-Host "`nThis will PERMANENTLY delete the app + add-in + ALL WH-AI data on this machine." -ForegroundColor Yellow
    $ans = Read-Host "Type  YES  to continue"
    if ($ans -ne 'YES') { Write-Host "Cancelled." -ForegroundColor Yellow; return }
}

# ---- 1. Kill processes ----
Write-Step "1) Stop running processes"
foreach ($p in $ProcNames) {
    $procs = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($procs) {
        if ($DryRun) { Write-Host ("  [DRY ] Would kill: {0} (PID {1})" -f $p, ($procs.Id -join ',')) -ForegroundColor Yellow }
        else { $procs | Stop-Process -Force -ErrorAction SilentlyContinue; Write-Host ("  [ OK ] Killed: {0}" -f $p) -ForegroundColor Green }
    } else { Write-Host ("  [ -- ] Not running: {0}" -f $p) -ForegroundColor DarkGray }
}

# Also kill CHILD processes that keep the install folder locked: node.exe running
# from the app dir (MCP server) + WebView2 hosts using the app's user-data dirs.
# Strictly scoped to WH-AI paths, so other apps' node/WebView2 are never touched.
$installRoots = @("$env:LOCALAPPDATA\WOHHUPxAI", "$env:ProgramFiles\WohhupAI", "$env:ProgramW6432\WohhupAI") |
    Where-Object { $_ }
try {
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | ForEach-Object {
        $mine = $false
        foreach ($root in $installRoots) {
            if ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { $mine = $true; break }
        }
        if (-not $mine -and $_.Name -eq 'msedgewebview2.exe' -and $_.CommandLine -and
            ($_.CommandLine -match '\\WohhupAI\\' -or $_.CommandLine -match '\\WOHHUPxAI\\')) { $mine = $true }
        if ($mine) {
            if ($DryRun) { Write-Host ("  [DRY ] Would kill child: {0} (PID {1})" -f $_.Name, $_.ProcessId) -ForegroundColor Yellow }
            else { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; Write-Host ("  [ OK ] Killed child: {0} (PID {1})" -f $_.Name, $_.ProcessId) -ForegroundColor Green } catch {} }
        }
    }
} catch {}
if (-not $DryRun) { Start-Sleep -Milliseconds 1500 }  # let handles release

# ---- 2. App folders (all 3 generations) ----
Write-Step "2) App folders"
Remove-Target "$env:LOCALAPPDATA\WOHHUPxAI"      "app (new)"
Remove-Target "$env:ProgramFiles\WohhupAI"       "app (old, Program Files)"
if ($env:ProgramW6432 -and $env:ProgramW6432 -ne $env:ProgramFiles) {
    Remove-Target "$env:ProgramW6432\WohhupAI"   "app (old, Program Files x64)"
}

# ---- 3. WebView2 cache ----
Write-Step "3) WebView2 cache"
Remove-Target "$env:LOCALAPPDATA\WohhupAI"       "WebView2 cache"

# ---- 4. Revit add-in for every year (folder + manifest, + scan by AddInId) ----
Write-Step "4) Revit add-in (Addins\<year>)"
foreach ($y in $RevitYears) {
    $ydir = "$env:APPDATA\Autodesk\Revit\Addins\$y"
    if (-not (Test-Path -LiteralPath $ydir)) { continue }

    Remove-Target (Join-Path $ydir $AddinFolder)   "add-in folder $y"
    Remove-Target (Join-Path $ydir $AddinManifest) "add-in manifest $y"

    # In case the manifest was renamed: scan every .addin containing our AddInId.
    Get-ChildItem -LiteralPath $ydir -Filter '*.addin' -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -eq $AddinManifest) { return }   # already handled above
        try {
            $txt = Get-Content -LiteralPath $_.FullName -Raw -ErrorAction Stop
            if ($txt -match [regex]::Escape($AddinId)) {
                Remove-Target $_.FullName "add-in manifest (AddInId match) $y"
            }
        } catch {}
    }
}

# ---- 5. ProgramData (usually only on a dev machine) ----
Write-Step "5) ProgramData\Autodesk\Revit\WH-AI (if present)"
Remove-Target "$env:ProgramData\Autodesk\Revit\WH-AI" "ProgramData WH-AI"

# ---- 6. Shortcuts (Desktop + Start Menu, user + common) ----
Write-Step "6) Shortcuts"
$desktops = @(
    [Environment]::GetFolderPath('DesktopDirectory'),
    [Environment]::GetFolderPath('CommonDesktopDirectory')
) | Select-Object -Unique
foreach ($d in $desktops) {
    Remove-Target (Join-Path $d 'WOHHUPxAI.lnk')   "desktop lnk"
    Remove-Target (Join-Path $d 'WOHHUP x AI.lnk')  "desktop lnk (old)"
}
$startMenus = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
) | Select-Object -Unique
foreach ($s in $startMenus) {
    Remove-Target (Join-Path $s 'WOHHUPxAI')        "start-menu group"
    Remove-Target (Join-Path $s 'WOHHUP x AI')      "start-menu group (old)"
    Remove-Target (Join-Path $s 'WOHHUPxAI.lnk')    "start-menu lnk"
    Remove-Target (Join-Path $s 'WOHHUP x AI.lnk')  "start-menu lnk (old)"
}

# ---- 7. Registry ----
Write-Step "7) Registry"
# 7a. Start-with-Windows (Run) - fixed value + scan values pointing at our app
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
Remove-RegValue $runKey 'WOHHUPxAI'
try {
    $runProps = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
    if ($runProps) {
        foreach ($prop in $runProps.PSObject.Properties) {
            if ($prop.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
            $val = [string]$prop.Value
            if ($val -match '\\WOHHUPxAI\\' -or $val -match '\\WohhupAI\\' -or $val -match 'MCP-REVIT-Desktop') {
                Remove-RegValue $runKey $prop.Name
            }
        }
    }
} catch {}

# 7b. Uninstall keys for all 3 AppIds, in HKCU + HKLM (+Wow6432Node).
# Enumerate and match the key name by our AppId GUID (robust to how Inno
# brace-escapes the key, e.g. "{GUID}}_is1") - never touches other products.
$uninstBases = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
foreach ($base in $uninstBases) {
    if (-not (Test-Path $base)) { continue }
    Get-ChildItem $base -ErrorAction SilentlyContinue | ForEach-Object {
        $child = $_.PSChildName
        foreach ($id in $AppIds) {
            if ($child -like "*$id*") { Remove-RegKey $_.PSPath; break }
        }
    }
}

# ---- Summary ----
Write-Host "`n========================================================" -ForegroundColor White
if ($DryRun) {
    Write-Host "  PREVIEW done - nothing deleted. Remove -DryRun to run for real." -ForegroundColor Yellow
} else {
    Write-Host ("  Done. Deleted: {0}  |  Not present: {1}  |  Failed: {2}" -f $script:nRemoved, $script:nMissing, $script:nFailed) -ForegroundColor White
    if ($script:nFailed -gt 0) {
        Write-Host "`n  [!] Left behind (usually because Revit/app was still open):" -ForegroundColor Red
        $script:failedPaths | ForEach-Object { Write-Host ("      - {0}" -f $_) -ForegroundColor Red }
        Write-Host "      -> CLOSE Revit + the app, then RE-RUN this script." -ForegroundColor Red
    } else {
        Write-Host "  Machine is clean of WH-AI. You can install the new version." -ForegroundColor Green
    }
}
Write-Host "========================================================" -ForegroundColor White
Write-Host "`nNote: if you use Claude Desktop, optionally remove the 'wohhup-server'" -ForegroundColor DarkGray
Write-Host "entry from  %APPDATA%\Claude\claude_desktop_config.json  (not required)." -ForegroundColor DarkGray
