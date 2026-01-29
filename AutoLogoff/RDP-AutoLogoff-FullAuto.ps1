<#
  RDP-AutoLogoff-FullAuto.ps1  (PowerShell 5.1-safe)
  Version: 1.0.2
  Author : Shourav | GitHub: github.com/rhshourav

  Fully automated:
    - Enables LocalSessionManager/Operational channel
    - Installs ONEVENT task (EventID 24) -> logs off disconnected RDP sessions immediately
    - Installs ONSTART task -> re-enforces at every boot
    - Self-check via registry (non-localized)
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

$ScriptVersion = '1.0.2'
$Author        = 'Shourav | GitHub: github.com/rhshourav'

$Channel      = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
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

  [pscustomobject]@{ ExitCode=$p.ExitCode; StdOut=$out; StdErr=$err }
}

function Get-Sha256([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return '' }
  (Get-FileHash -Path $path -Algorithm SHA256).Hash
}

function Hash-StringSha256([string]$s) {
  $sha = New-Object Security.Cryptography.SHA256Managed
  $bytes = [Text.Encoding]::UTF8.GetBytes($s)
  ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '')
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
# Non-localized channel check (registry)
# -----------------------------
function Get-ChannelRegPath {
  # Note: channel name contains '/', registry path uses the same.
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\$Channel"
}

function Ensure-ChannelEnabled {
  # Try via wevtutil first
  $r = Run-Exe "wevtutil.exe" ("sl `"$Channel`" /e:true")
  if ($r.ExitCode -ne 0) {
    throw "Failed enabling channel via wevtutil. exit=$($r.ExitCode) err=$($r.StdErr)"
  }
  Log "wevtutil enable attempted: $Channel"

  # Verify via registry (not localized)
  $rp = Get-ChannelRegPath
  if (-not (Test-Path -LiteralPath $rp)) {
    throw "Channel registry key not found (channel name may be wrong): $rp"
  }

  $enabled = (Get-ItemProperty -LiteralPath $rp -Name Enabled -ErrorAction Stop).Enabled
  if ($enabled -ne 1) {
    # Force-enable via registry as a fallback, then re-apply wevtutil
    Log "Registry shows Enabled=$enabled. Forcing Enabled=1 in registry."
    Set-ItemProperty -LiteralPath $rp -Name Enabled -Value 1 -Type DWord -ErrorAction Stop
    [void](Run-Exe "wevtutil.exe" ("sl `"$Channel`" /e:true"))
    $enabled2 = (Get-ItemProperty -LiteralPath $rp -Name Enabled -ErrorAction Stop).Enabled
    if ($enabled2 -ne 1) {
      throw "Channel still not enabled after registry+wevtutil. Enabled=$enabled2"
    }
  }

  Log "Channel OK (registry): Enabled=1"
}

function Check-ChannelEnabled {
  $rp = Get-ChannelRegPath
  if (-not (Test-Path -LiteralPath $rp)) { throw "Channel registry key not found: $rp" }
  $enabled = (Get-ItemProperty -LiteralPath $rp -Name Enabled -ErrorAction Stop).Enabled
  if ($enabled -ne 1) { throw "Channel NOT enabled (registry Enabled=$enabled): $Channel" }
  Log "Channel check OK (registry): Enabled=1"
}

# -----------------------------
# Payload: log off disconnected RDP sessions
# -----------------------------
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

$mutexName = "Global\RDP-AutoLogoff-Disconnected"
$created = $false
$mutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$created)
if (-not $mutex.WaitOne(0)) { exit 0 }

try {
  $lines = & qwinsta 2>$null
  if (-not $lines) { Write-Log "qwinsta returned no output."; exit 0 }

  foreach ($line in $lines) {
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

# -----------------------------
# Persist installer for ONSTART task (works with iex/irm)
# -----------------------------
function Ensure-InstallerPersisted {
  # 1) If running from a file, use that
  if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
    $self = Get-Content -LiteralPath $PSCommandPath -Raw -Encoding UTF8
    Write-FileIfDifferent -path $InstallerPath -content $self
    Log "Installer persisted from PSCommandPath."
    return
  }

  # 2) If running from IEX, use the scriptblock text
  $def = $MyInvocation.MyCommand.Definition
  if ($def -and $def.Length -gt 5000 -and $def -match 'RDP-AutoLogoff-FullAuto\.ps1') {
    Write-FileIfDifferent -path $InstallerPath -content $def
    Log "Installer persisted from MyCommand.Definition (IEX-safe)."
    return
  }

  throw "Cannot persist installer. Run from file OR via iex(irm URL) where Definition contains the script."
}

# -----------------------------
# Tasks
# -----------------------------
function Create-OrUpdate-TaskEvent {
  $trigger = "*[System[(EventID=24)]]"
  $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PayloadPath`""
  $cmd = "/Create /F /TN `"$TaskEventName`" /SC ONEVENT /EC `"$Channel`" /MO `"$trigger`" /TR `"$tr`" /RU SYSTEM /RL HIGHEST"
  $r = Run-Exe "schtasks.exe" $cmd
  if ($r.ExitCode -ne 0) { throw "Failed ONEVENT task. exit=$($r.ExitCode) err=$($r.StdErr)" }
  Log "Task OK: $TaskEventName"
}

function Create-OrUpdate-TaskEnforce {
  $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallerPath`" -Mode Install"
  $cmd = "/Create /F /TN `"$TaskEnforceName`" /SC ONSTART /TR `"$tr`" /RU SYSTEM /RL HIGHEST"
  $r = Run-Exe "schtasks.exe" $cmd
  if ($r.ExitCode -ne 0) { throw "Failed ONSTART task. exit=$($r.ExitCode) err=$($r.StdErr)" }
  Log "Task OK: $TaskEnforceName"
}

function Check-Task([string]$name, [string]$mustContain) {
  $r = Run-Exe "schtasks.exe" ("/Query /TN `"$name`" /V /FO LIST")
  if ($r.ExitCode -ne 0) { throw "Task missing/not queryable: $name" }

  if ($r.StdOut -notmatch "Run As User:\s*(SYSTEM|S-1-5-18)") { throw "Task not running as SYSTEM: $name" }
  if ($r.StdOut -notmatch [Regex]::Escape($mustContain)) { throw "Task does not reference: $mustContain (Task: $name)" }

  Log "Task self-check OK: $name"
}

function Uninstall-All {
  Log "Uninstall starting..."
  Run-Exe "schtasks.exe" ("/Delete /TN `"$TaskEventName`" /F") | Out-Null
  Run-Exe "schtasks.exe" ("/Delete /TN `"$TaskEnforceName`" /F") | Out-Null

  foreach ($p in @($PayloadPath,$InstallerPath,(Join-Path $BaseDir 'AutoLogoff.log'))) {
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
  Log "======================================================================="
  Log " RDP AutoLogoff FullAuto  v$ScriptVersion"
  Log " Author: $Author"
  Log " Host  : $env:COMPUTERNAME"
  Log " User  : $env:USERNAME"
  Log " Mode  : $Mode"
  Log "======================================================================="

  if ($Mode -ne 'Check' -and $Mode -ne 'Uninstall') {
    if (-not (Is-Admin)) { throw "Run as Administrator (or SYSTEM). Current user isn't elevated." }
  }

  switch ($Mode) {
    'Uninstall' {
      Uninstall-All
      return
    }

    'Install' {
      Ensure-ChannelEnabled
      Write-FileIfDifferent -path $PayloadPath -content $PayloadContent
      Ensure-InstallerPersisted
      Create-OrUpdate-TaskEvent
      Create-OrUpdate-TaskEnforce

      # Self-check
      Check-ChannelEnabled
      Check-Task -name $TaskEventName   -mustContain $PayloadPath
      Check-Task -name $TaskEnforceName -mustContain $InstallerPath

      Log "INSTALL/ENFORCE OK."
      return
    }

    'Check' {
      Check-ChannelEnabled
      if (-not (Test-Path -LiteralPath $PayloadPath))   { throw "Missing payload: $PayloadPath" }
      if (-not (Test-Path -LiteralPath $InstallerPath)) { throw "Missing installer: $InstallerPath" }

      Check-Task -name $TaskEventName   -mustContain $PayloadPath
      Check-Task -name $TaskEnforceName -mustContain $InstallerPath

      Log "CHECK OK."
      return
    }
  }
}
catch {
  Log ("FAIL: " + $_.Exception.Message)
  throw
}
