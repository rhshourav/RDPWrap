<#
  RDP-AutoLogoff-FullAuto.ps1  (PowerShell 5.1-safe)

  What it does:
    - Immediate logoff on RDP disconnect using ONEVENT Scheduled Task:
        Channel: Microsoft-Windows-TerminalServices-LocalSessionManager/Operational
        EventID : 24 (Session disconnected)
    - Self-enforcement: creates a 2nd task that re-applies config on every boot
    - Self-check: validates channel enabled + tasks exist + point to correct scripts
    - Writes logs to: C:\ProgramData\RDP-AutoLogoff\Enforce.log

  Modes:
    - Install   (default) : enforce + check
    - Check                : verify only
    - Uninstall            : remove: remove tasks + remove files
#>

[CmdletBinding()]
param(
  [ValidateSet('Install','Check','Uninstall')]
  [string]$Mode = 'Install',

  [string]$BaseDir = "$env:ProgramData\RDP-AutoLogoff",
  [string]$TaskEventName   = 'RDP AutoLogoff on Disconnect',
  [string]$TaskEnforceName = 'RDP AutoLogoff Enforce'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Channel = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
$PayloadPath  = Join-Path $BaseDir 'AutoLogoff-DisconnectedRdp.ps1'
$InstallerPath = Join-Path $BaseDir 'Enforce.ps1'
$LogPath      = Join-Path $BaseDir 'Enforce.log'

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
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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

  return [pscustomobject]@{ ExitCode=$p.ExitCode; StdOut=$out; StdErr=$err }
}

function Get-Sha256([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return '' }
  return (Get-FileHash -Path $path -Algorithm SHA256).Hash
}

function Write-FileIfDifferent([string]$path, [string]$content) {
  $expectedHash = ([System.BitConverter]::ToString(
    (New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($content))
  ) -replace '-', '')

  $currentHash = Get-Sha256 $path
  if ($currentHash -ne $expectedHash) {
    Log "Writing/Updating: $path"
    $tmp = Join-Path $BaseDir ("tmp_" + [guid]::NewGuid().ToString('N') + ".tmp")
    [IO.File]::WriteAllText($tmp, $content, (New-Object Text.UTF8Encoding($false)))
    Move-Item -Force -Path $tmp -Destination $path
  } else {
    Log "File OK (hash match): $path"
  }
}

# Payload script: logs off disconnected RDP sessions
$PayloadContent = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = "SilentlyContinue"

$BaseDir = Join-Path $env:ProgramData "RDP-AutoLogoff"
$LogFile = Join-Path $BaseDir "AutoLogoff.log"
New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null

function Write-Log([string]$Msg) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  Add-Content -Path $LogFile -Value "[$ts] $Msg" -Encoding UTF8
}

# Prevent concurrent runs
$mutexName = "Global\RDP-AutoLogoff-Disconnected"
$created = $false
$mutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$created)
if (-not $mutex.WaitOne(0)) { exit 0 }

try {
  $lines = & qwinsta 2>$null
  if (-not $lines) { Write-Log "qwinsta returned no output."; exit 0 }

  foreach ($line in $lines) {
    # rdp-tcp#X  <user>  <id>  Disc
    if ($line -match "^\s*>?\s*(?<sess>rdp-tcp#?\d*)\s+(?<user>\S*)\s+(?<id>\d+)\s+(?<state>Disc)\b") {
      $id = [int]$Matches.id
      $user = $Matches.user
      Write-Log "Logging off disconnected RDP session: ID=$id USER=$user LINE='$line'"
      & logoff $id /V 2>$null
    }
  }
}
catch {
  Write-Log ("ERROR: " + $_.Exception.Message)
}
finally {
  try { $mutex.ReleaseMutex() | Out-Null } catch {}
  $mutex.Dispose()
}
'@

# This installer copies itself into ProgramData for the Enforce-on-boot task to run locally.
function Ensure-SelfCopied {
  try {
    $self = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($self)) { return }
    if ($self -and (Test-Path -LiteralPath $self)) {
      $selfContent = Get-Content -LiteralPath $self -Raw -Encoding UTF8
      Write-FileIfDifferent -path $InstallerPath -content $selfContent
    }
  } catch {
    Log "WARN: Could not self-copy installer: $($_.Exception.Message)"
  }
}

function Enable-Channel {
  $r = Run-Exe "wevtutil.exe" ("sl `"$Channel`" /e:true")
  if ($r.ExitCode -ne 0) {
    throw "Failed to enable channel. wevtutil exit=$($r.ExitCode) err=$($r.StdErr)"
  }
  Log "Event channel enabled: $Channel"
}

function Check-ChannelEnabled {
  $r = Run-Exe "wevtutil.exe" ("gl `"$Channel`"")
  if ($r.ExitCode -ne 0) { throw "Cannot query channel: $Channel" }
  if ($r.StdOut -notmatch "enabled:\s*true") { throw "Channel NOT enabled: $Channel" }
  Log "Channel OK: enabled=true"
}

function Create-OrUpdate-TaskEvent {
  # ONEVENT task
  $trigger = "*[System[(EventID=24)]]"
  $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PayloadPath`""

  # Create/update
  $cmd = "/Create /F /TN `"$TaskEventName`" /SC ONEVENT /EC `"$Channel`" /MO `"$trigger`" /TR `"$tr`" /RU SYSTEM /RL HIGHEST"
  $r = Run-Exe "schtasks.exe" $cmd
  if ($r.ExitCode -ne 0) { throw "Failed to create/update ONEVENT task. schtasks exit=$($r.ExitCode) err=$($r.StdErr)" }
  Log "Task OK: $TaskEventName"
}

function Create-OrUpdate-TaskEnforce {
  # ONSTART task to re-apply enforcement every boot
  $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallerPath`" -Mode Install"
  $cmd = "/Create /F /TN `"$TaskEnforceName`" /SC ONSTART /TR `"$tr`" /RU SYSTEM /RL HIGHEST"
  $r = Run-Exe "schtasks.exe" $cmd
  if ($r.ExitCode -ne 0) { throw "Failed to create/update ONSTART enforce task. schtasks exit=$($r.ExitCode) err=$($r.StdErr)" }
  Log "Task OK: $TaskEnforceName"
}

function Check-Task([string]$name, [string]$mustContain) {
  $r = Run-Exe "schtasks.exe" ("/Query /TN `"$name`" /V /FO LIST")
  if ($r.ExitCode -ne 0) { throw "Task missing/not queryable: $name" }

  if ($r.StdOut -notmatch "Run As User:\s*(SYSTEM|S-1-5-18)") { throw "Task not running as SYSTEM: $name" }
  if ($r.StdOut -notmatch [Regex]::Escape($mustContain)) { throw "Task does not reference expected path: $mustContain (Task: $name)" }

  Log "Task self-check OK: $name"
}

function Uninstall-All {
  Log "Uninstall starting..."
  Run-Exe "schtasks.exe" ("/Delete /TN `"$TaskEventName`" /F") | Out-Null
  Run-Exe "schtasks.exe" ("/Delete /TN `"$TaskEnforceName`" /F") | Out-Null

  foreach ($p in @($PayloadPath,$InstallerPath, (Join-Path $BaseDir 'AutoLogoff.log'))) {
    if (Test-Path -LiteralPath $p) {
      Remove-Item -LiteralPath $p -Force
      Log "Removed: $p"
    }
  }

  Log "Uninstall complete."
}

# -----------------------------
# MAIN
# -----------------------------
try {
  Log "=== Mode=$Mode Host=$env:COMPUTERNAME User=$env:USERNAME ==="

  if ($Mode -ne 'Check' -and $Mode -ne 'Uninstall') {
    if (-not (Is-Admin)) { throw "Run as Administrator (or as SYSTEM via GPO/Task). Not admin." }
  }

  if ($Mode -eq 'Uninstall') {
    Uninstall-All
    return
  }

  if ($Mode -eq 'Install') {
    Enable-Channel
    Write-FileIfDifferent -path $PayloadPath -content $PayloadContent
    Ensure-SelfCopied

    Create-OrUpdate-TaskEvent
    Create-OrUpdate-TaskEnforce

    # Self-check after enforcement
    Check-ChannelEnabled
    Check-Task -name $TaskEventName   -mustContain $PayloadPath
    Check-Task -name $TaskEnforceName -mustContain $InstallerPath

    Log "INSTALL/ENFORCE OK."
    return
  }

  if ($Mode -eq 'Check') {
    Check-ChannelEnabled
    if (-not (Test-Path -LiteralPath $PayloadPath)) { throw "Missing payload: $PayloadPath" }
    if (-not (Test-Path -LiteralPath $InstallerPath)) { throw "Missing installer copy: $InstallerPath" }

    Check-Task -name $TaskEventName   -mustContain $PayloadPath
    Check-Task -name $TaskEnforceName -mustContain $InstallerPath

    Log "CHECK OK."
    return
  }
}
catch {
  Log ("FAIL: " + $_.Exception.Message)
  throw
}
