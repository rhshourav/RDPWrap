<#
  RDP-AutoLogoff-FullAuto.ps1  (PowerShell 5.1-safe)
  Version: 1.0.4
  Author : Shourav | GitHub: github.com/rhshourav

  Fully automated:
    - Enables LocalSessionManager/Operational channel (registry verified)
    - Installs ONEVENT task (EventID 24) -> payload logs off disconnected RDP sessions
    - Installs ONSTART task -> re-enforces at every boot (downloads this script from GitHub URL)
    - Self-checks using task XML (non-localized)
#>

[CmdletBinding()]
param(
  [ValidateSet('Install','Check','Uninstall')]
  [string]$Mode = 'Install',

  # IMPORTANT: set this to the exact raw URL of THIS script in your repo
  [string]$SelfUrl = "https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/AutoLogoff/RDP-AutoLogoff-FullAuto.ps1",

  [string]$BaseDir = "$env:ProgramData\RDP-AutoLogoff",
  [string]$TaskEventName   = "RDP AutoLogoff on Disconnect",
  [string]$TaskEnforceName = "RDP AutoLogoff Enforce"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$ScriptVersion = '1.0.4'
$Author        = 'Shourav | GitHub: github.com/rhshourav'

# -----------------------------
# Constants / Paths
# -----------------------------
$Channel      = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
$PayloadPath  = Join-Path $BaseDir 'AutoLogoff-DisconnectedRdp.ps1'
$RunnerPath   = Join-Path $BaseDir 'Run-Enforce.ps1'
$LogPath      = Join-Path $BaseDir 'Install.log'

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    New-Item -ItemType Directory -Path $p -Force | Out-Null
  }
}
Ensure-Dir $BaseDir

function Log([string]$msg) {
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $line = "[$ts] $msg"
  Add-Content -Path $LogPath -Value $line -Encoding UTF8
  Write-Host $line
}

function Is-Admin {
  $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Run-Exe([string]$file, [string]$args) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $file
  $psi.Arguments = $args
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  [pscustomobject]@{ ExitCode=$p.ExitCode; StdOut=$out; StdErr=$err }
}

function Hash-StringSha256([string]$s) {
  $sha = New-Object Security.Cryptography.SHA256Managed
  $bytes = [Text.Encoding]::UTF8.GetBytes($s)
  ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
}

function Get-Sha256([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return '' }
  (Get-FileHash -Path $path -Algorithm SHA256).Hash
}

function Write-FileIfDifferent([string]$path, [string]$content) {
  $expectedHash = Hash-StringSha256 $content
  $currentHash  = Get-Sha256 $path

  if ($currentHash -ne $expectedHash) {
    Log "Writing/Updating: $path"
    $tmp = Join-Path $BaseDir ("tmp_" + [guid]::NewGuid().ToString('N') + ".tmp")
    [IO.File]::WriteAllText($tmp, $content, (New-Object Text.UTF8Encoding($false)))
    Move-Item -Force -Path $tmp -Destination $path
  } else {
    Log "File OK (hash match): $path"
  }
}

# -----------------------------
# Channel enable + check (registry, non-localized)
# -----------------------------
function Get-ChannelRegPath {
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\$Channel"
}

function Ensure-ChannelEnabled {
  $r = Run-Exe "wevtutil.exe" ("sl `"$Channel`" /e:true")
  if ($r.ExitCode -ne 0) {
    throw "wevtutil enable failed. exit=$($r.ExitCode) err=$($r.StdErr)"
  }

  $rp = Get-ChannelRegPath
  if (-not (Test-Path -LiteralPath $rp)) {
    throw "Channel registry key not found: $rp"
  }

  $enabled = (Get-ItemProperty -LiteralPath $rp -Name Enabled -ErrorAction Stop).Enabled
  if ($enabled -ne 1) {
    Log "Registry Enabled=$enabled. Forcing Enabled=1."
    Set-ItemProperty -LiteralPath $rp -Name Enabled -Value 1 -Type DWord -ErrorAction Stop
    [void](Run-Exe "wevtutil.exe" ("sl `"$Channel`" /e:true"))
  }

  $enabled2 = (Get-ItemProperty -LiteralPath $rp -Name Enabled -ErrorAction Stop).Enabled
  if ($enabled2 -ne 1) { throw "Channel still not enabled. Enabled=$enabled2" }

  Log "Channel OK: Enabled=1 (registry)"
}

function Check-ChannelEnabled {
  $rp = Get-ChannelRegPath
  if (-not (Test-Path -LiteralPath $rp)) { throw "Channel registry key not found: $rp" }
  $enabled = (Get-ItemProperty -LiteralPath $rp -Name Enabled -ErrorAction Stop).Enabled
  if ($enabled -ne 1) { throw "Channel NOT enabled (Enabled=$enabled): $Channel" }
  Log "Channel check OK: Enabled=1 (registry)"
}

# -----------------------------
# Payload (runs on disconnect event)
# -----------------------------
$PayloadContent =
"Set-StrictMode -Version 2.0`r`n" +
'$ErrorActionPreference = "SilentlyContinue"' + "`r`n`r`n" +
'$BaseDir = Join-Path $env:ProgramData "RDP-AutoLogoff"' + "`r`n" +
'$LogFile = Join-Path $BaseDir "AutoLogoff.log"' + "`r`n" +
'New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null' + "`r`n`r`n" +
'function Write-Log([string]$Msg) {' + "`r`n" +
'  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")' + "`r`n" +
'  Add-Content -Path $LogFile -Value "[$ts] $Msg" -Encoding UTF8' + "`r`n" +
'}' + "`r`n`r`n" +
'$mutexName = "Global\RDP-AutoLogoff-Disconnected"' + "`r`n" +
'$created = $false' + "`r`n" +
'$mutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$created)' + "`r`n" +
'if (-not $mutex.WaitOne(0)) { exit 0 }' + "`r`n`r`n" +
'try {' + "`r`n" +
'  $lines = & qwinsta 2>$null' + "`r`n" +
'  if (-not $lines) { Write-Log "qwinsta returned no output."; exit 0 }' + "`r`n`r`n" +
'  foreach ($line in $lines) {' + "`r`n" +
'    if ($line -match "^\s*>?\s*(?<sess>rdp-tcp#?\d*)\s+(?<user>\S*)\s+(?<id>\d+)\s+(?<state>Disc)\b") {' + "`r`n" +
'      $id = [int]$Matches.id' + "`r`n" +
'      $user = $Matches.user' + "`r`n" +
'      Write-Log "Logging off disconnected RDP session: ID=$id USER=$user LINE=''$line''"' + "`r`n" +
'      & logoff $id /V 2>$null' + "`r`n" +
'    }' + "`r`n" +
'  }' + "`r`n" +
'} catch {' + "`r`n" +
'  Write-Log ("ERROR: " + $_.Exception.Message)' + "`r`n" +
'} finally {' + "`r`n" +
'  try { $mutex.ReleaseMutex() | Out-Null } catch {}' + "`r`n" +
'  $mutex.Dispose()' + "`r`n" +
'}' + "`r`n"

# -----------------------------
# Runner (called at boot to re-enforce)
# -----------------------------
$RunnerContent =
"param([Parameter(Mandatory=`$true)][string]`$Url)`r`n" +
"Set-StrictMode -Version 2.0`r`n" +
"`$ErrorActionPreference = 'Stop'`r`n" +
"function Get-RemoteText([string]`$u){`r`n" +
"  try { return (Invoke-RestMethod -UseBasicParsing -Uri `$u) } catch { return (Invoke-RestMethod -Uri `$u) }`r`n" +
"}`r`n" +
"`$src = Get-RemoteText `$Url`r`n" +
"`$sb = [ScriptBlock]::Create([string]`$src)`r`n" +
"& `$sb -Mode Install -SelfUrl `$Url`r`n"

# -----------------------------
# Task helpers (use XML for verification)
# -----------------------------
function Get-TaskXml([string]$name) {
  $r = Run-Exe "schtasks.exe" ("/Query /TN `"$name`" /XML")
  if ($r.ExitCode -ne 0) { return "" }
  $r.StdOut
}

function Create-OrUpdate-TaskEvent {
  $trigger = "*[System[(EventID=24)]]"
  $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PayloadPath`""
  $cmd = "/Create /F /TN `"$TaskEventName`" /SC ONEVENT /EC `"$Channel`" /MO `"$trigger`" /TR `"$tr`" /RU SYSTEM /RL HIGHEST"
  $r = Run-Exe "schtasks.exe" $cmd
  if ($r.ExitCode -ne 0) { throw "Failed ONEVENT task. exit=$($r.ExitCode) err=$($r.StdErr)" }
  Log "Task OK: $TaskEventName"
}

function Create-OrUpdate-TaskEnforce {
  $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$RunnerPath`" -Url `"$SelfUrl`""
  $cmd = "/Create /F /TN `"$TaskEnforceName`" /SC ONSTART /TR `"$tr`" /RU SYSTEM /RL HIGHEST"
  $r = Run-Exe "schtasks.exe" $cmd
  if ($r.ExitCode -ne 0) { throw "Failed ONSTART task. exit=$($r.ExitCode) err=$($r.StdErr)" }
  Log "Task OK: $TaskEnforceName"
}

function SelfCheck-Tasks {
  $x1 = Get-TaskXml $TaskEventName
  if ([string]::IsNullOrWhiteSpace($x1)) { throw "Task missing: $TaskEventName" }
  if ($x1 -notmatch [Regex]::Escape($PayloadPath)) { throw "TaskEvent does not reference payload path." }
  if ($x1 -notmatch [Regex]::Escape($Channel))     { throw "TaskEvent does not reference channel." }
  if ($x1 -notmatch "EventID=24")                  { throw "TaskEvent does not contain EventID 24 filter." }

  $x2 = Get-TaskXml $TaskEnforceName
  if ([string]::IsNullOrWhiteSpace($x2)) { throw "Task missing: $TaskEnforceName" }
  if ($x2 -notmatch [Regex]::Escape($RunnerPath))  { throw "TaskEnforce does not reference RunnerPath." }
  if ($x2 -notmatch [Regex]::Escape($SelfUrl))     { throw "TaskEnforce does not reference SelfUrl." }

  Log "Task self-check OK (XML)."
}

function Uninstall-All {
  Log "Uninstall starting..."
  [void](Run-Exe "schtasks.exe" ("/Delete /TN `"$TaskEventName`" /F"))
  [void](Run-Exe "schtasks.exe" ("/Delete /TN `"$TaskEnforceName`" /F"))

  foreach ($p in @($PayloadPath,$RunnerPath,(Join-Path $BaseDir 'AutoLogoff.log'))) {
    if (Test-Path -LiteralPath $p) {
      Remove-Item -LiteralPath $p -Force
      Log "Removed: $p"
    }
  }
  Log "Uninstall complete."
}

# -----------------------------
# Banner
# -----------------------------
Log "======================================================================="
Log " RDP AutoLogoff FullAuto  v$ScriptVersion"
Log " Author: $Author"
Log " Host  : $env:COMPUTERNAME"
Log " User  : $env:USERNAME"
Log " Mode  : $Mode"
Log " SelfUrl: $SelfUrl"
Log "======================================================================="

# -----------------------------
# Main
# -----------------------------
if ($Mode -ne 'Check' -and $Mode -ne 'Uninstall') {
  if (-not (Is-Admin)) { throw "Not elevated. Run PowerShell as Administrator (or run as SYSTEM)." }
}

switch ($Mode) {
  'Uninstall' {
    Uninstall-All
    break
  }

  'Install' {
    Ensure-ChannelEnabled
    Write-FileIfDifferent -path $PayloadPath -content $PayloadContent
    Write-FileIfDifferent -path $RunnerPath  -content $RunnerContent
    Create-OrUpdate-TaskEvent
    Create-OrUpdate-TaskEnforce

    # Self-checks
    Check-ChannelEnabled
    SelfCheck-Tasks

    Log "INSTALL/ENFORCE OK."
    break
  }

  'Check' {
    Check-ChannelEnabled
    if (-not (Test-Path -LiteralPath $PayloadPath)) { throw "Missing payload: $PayloadPath" }
    if (-not (Test-Path -LiteralPath $RunnerPath))  { throw "Missing runner: $RunnerPath" }
    SelfCheck-Tasks
    Log "CHECK OK."
    break
  }
}
