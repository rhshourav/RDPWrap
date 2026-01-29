<#
  RDP AutoLogoff (Immediate logoff on RDP disconnect)
  Version: 1.1.2
  Author : Shourav | GitHub: github.com/rhshourav

  What it does:
    - Enables: Microsoft-Windows-TerminalServices-LocalSessionManager/Operational (registry-verified)
    - Writes payload:  C:\ProgramData\RDP-AutoLogoff\AutoLogoff-DisconnectedRdp.ps1
    - Writes enforcer: C:\ProgramData\RDP-AutoLogoff\Enforce.ps1
    - Creates tasks:
        1) ONEVENT (EventID 24 disconnect) -> runs payload immediately
        2) ONSTART -> runs enforcer each boot (re-enforces + self-check)
    - Self-check parses task XML (robust; no fragile string matching)

  Run:
    Install   : powershell -ExecutionPolicy Bypass -File .\test.ps1
    Check     : powershell -ExecutionPolicy Bypass -File .\test.ps1 -Mode Check
    Uninstall : powershell -ExecutionPolicy Bypass -File .\test.ps1 -Mode Uninstall
#>

[CmdletBinding()]
param(
  [ValidateSet('Install','Check','Uninstall')]
  [string]$Mode = 'Install',

  # Used only if script isn't running from file path (IEX case)
  [string]$SelfUrl = "https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/AutoLogoff/RDP-AutoLogoff-FullAuto.ps1"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Version = '1.1.2'
$Author  = 'Shourav | GitHub: github.com/rhshourav'

# -----------------------------
# Config
# -----------------------------
$BaseDir        = Join-Path $env:ProgramData 'RDP-AutoLogoff'
$Channel        = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
$PayloadPath    = Join-Path $BaseDir 'AutoLogoff-DisconnectedRdp.ps1'
$EnforcerPath   = Join-Path $BaseDir 'Enforce.ps1'
$LogPath        = Join-Path $BaseDir 'Install.log'

$TaskEventName  = 'RDP AutoLogoff on Disconnect'
$TaskBootName   = 'RDP AutoLogoff Enforce'

function Ensure-Dir([string]$p) {
  if (-not (Test-Path -LiteralPath $p)) {
    New-Item -ItemType Directory -Path $p -Force | Out-Null
  }
}

function Log([string]$msg) {
  Ensure-Dir $BaseDir
  $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
  $line = "[$ts] $msg"
  Add-Content -Path $LogPath -Value $line -Encoding UTF8
  Write-Host $line
}

function Is-Admin {
  $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SystemExePath([string]$name) {
  $sys = Join-Path $env:windir "System32\$name"
  $sn  = Join-Path $env:windir "Sysnative\$name"  # only works from 32-bit process on 64-bit OS
  if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess -and (Test-Path -LiteralPath $sn)) {
    return $sn
  }
  return $sys
}

# Robust native exec (no PowerShell native stderr weirdness)
function Run-Native([string]$ExePath, [string[]]$Arguments) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $ExePath
  $psi.Arguments = ($Arguments -join ' ')
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  [pscustomobject]@{
    ExitCode = $p.ExitCode
    StdOut   = $stdout
    StdErr   = $stderr
  }
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
  $expected = Hash-StringSha256 $content
  $current  = Get-Sha256 $path

  if ($current -ne $expected) {
    Log "Writing/Updating: $path"
    $tmp = Join-Path $BaseDir ("tmp_" + [guid]::NewGuid().ToString('N') + ".tmp")
    [IO.File]::WriteAllText($tmp, $content, (New-Object Text.UTF8Encoding($false)))
    Move-Item -Force -Path $tmp -Destination $path
  } else {
    Log "File OK (hash match): $path"
  }
}

# -----------------------------
# Channel enable/check (registry; non-localized)
# -----------------------------
function Get-ChannelRegPath {
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\$Channel"
}

function Ensure-ChannelEnabled {
  $wevt = Get-SystemExePath "wevtutil.exe"
  $r = Run-Native $wevt @("sl", "`"$Channel`"", "/e:true")
  if ($r.ExitCode -ne 0) { throw "wevtutil enable failed: $($r.StdErr.Trim()) $($r.StdOut.Trim())" }

  $rp = Get-ChannelRegPath
  if (-not (Test-Path -LiteralPath $rp)) { throw "Channel registry key not found: $rp" }

  $enabled = (Get-ItemProperty -LiteralPath $rp -Name Enabled -ErrorAction Stop).Enabled
  if ($enabled -ne 1) {
    Log "Registry shows Enabled=$enabled. Forcing Enabled=1."
    Set-ItemProperty -LiteralPath $rp -Name Enabled -Value 1 -Type DWord -ErrorAction Stop
    [void](Run-Native $wevt @("sl", "`"$Channel`"", "/e:true"))
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
# Payload script (runs on disconnect)
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
    if ($line -match "^\s*>?\s*(?<sess>rdp-tcp#?\d*)\s+(?<user>\S*)\s+(?<id>\d+)\s+(?<state>(Disc|Disconnected))\b") {
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
# Minimal enforcer for IEX installs
# -----------------------------
function Get-MinimalEnforcer([string]$url) {
@"
param([ValidateSet('Install','Check','Uninstall')][string]\$Mode='Install',[string]\$SelfUrl='$url')
Set-StrictMode -Version 2.0
\$ErrorActionPreference='Stop'
try { \$src = Invoke-RestMethod -UseBasicParsing -Uri \$SelfUrl } catch { \$src = Invoke-RestMethod -Uri \$SelfUrl }
\$sb  = [ScriptBlock]::Create([string]\$src)
& \$sb -Mode \$Mode -SelfUrl \$SelfUrl
"@
}

# -----------------------------
# Task XML parsing helpers
# -----------------------------
function Get-TaskXmlText([string]$name) {
  $scht = Get-SystemExePath "schtasks.exe"
  $r = Run-Native $scht @("/Query", "/TN", "`"$name`"", "/XML")
  if ($r.ExitCode -ne 0) { return "" }
  $r.StdOut
}

function Get-TaskArgumentString([string]$xmlText) {
  if ([string]::IsNullOrWhiteSpace($xmlText)) { return "" }
  [xml]$x = $xmlText
  $ns = New-Object Xml.XmlNamespaceManager($x.NameTable)
  $ns.AddNamespace('t','http://schemas.microsoft.com/windows/2004/02/mit/task')
  $n = $x.SelectSingleNode('//t:Actions/t:Exec/t:Arguments', $ns)
  if ($n -eq $null) { return "" }
  $n.InnerText
}

function Get-TaskEventSubscription([string]$xmlText) {
  if ([string]::IsNullOrWhiteSpace($xmlText)) { return "" }
  [xml]$x = $xmlText
  $ns = New-Object Xml.XmlNamespaceManager($x.NameTable)
  $ns.AddNamespace('t','http://schemas.microsoft.com/windows/2004/02/mit/task')
  $n = $x.SelectSingleNode('//t:Triggers/t:EventTrigger/t:Subscription', $ns)
  if ($n -eq $null) { return "" }
  $n.InnerText
}

function Task-SelfCheck {
  Check-ChannelEnabled

  if (-not (Test-Path -LiteralPath $PayloadPath))  { throw "Missing payload: $PayloadPath" }
  if (-not (Test-Path -LiteralPath $EnforcerPath)) { throw "Missing enforcer: $EnforcerPath" }

  $tx = Get-TaskXmlText $TaskEventName
  if ([string]::IsNullOrWhiteSpace($tx)) { throw "Missing task: $TaskEventName" }
  $args = Get-TaskArgumentString $tx
  if ($args -notmatch 'AutoLogoff-DisconnectedRdp\.ps1') { throw "TaskEvent action does not reference payload script name." }
  $sub = Get-TaskEventSubscription $tx
  if ($sub -notmatch 'EventID=24') { throw "TaskEvent trigger is not EventID 24." }
  if ($sub -notmatch [Regex]::Escape($Channel)) { throw "TaskEvent trigger does not reference expected channel." }

  $bx = Get-TaskXmlText $TaskBootName
  if ([string]::IsNullOrWhiteSpace($bx)) { throw "Missing task: $TaskBootName" }
  $bargs = Get-TaskArgumentString $bx
  if ($bargs -notmatch [Regex]::Escape($EnforcerPath)) { throw "Boot task does not call enforcer path." }

  Log "Self-check OK."
}

# -----------------------------
# Task creation via XML
# -----------------------------
function Write-XmlUtf16([string]$path, [string]$xml) {
  [IO.File]::WriteAllText($path, $xml, [Text.Encoding]::Unicode)
}

function Register-TaskFromXml([string]$name, [string]$xmlPath) {
  if (-not (Test-Path -LiteralPath $xmlPath)) { throw "XML not found: $xmlPath" }

  $scht = Get-SystemExePath "schtasks.exe"
  $r = Run-Native $scht @("/Create","/F","/TN", "`"$name`"", "/XML", "`"$xmlPath`"")
  if ($r.ExitCode -ne 0) {
    throw "Failed to create task '$name'. STDERR: $($r.StdErr.Trim()) STDOUT: $($r.StdOut.Trim())"
  }
  Log "Task registered: $name"
}

function Build-EventTaskXml {
  $sub = "<QueryList><Query Id=`"0`" Path=`"$Channel`"><Select Path=`"$Channel`">*[System[(EventID=24)]]</Select></Query></QueryList>"
  $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PayloadPath`""

@"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Shourav</Author>
    <Description>Immediate logoff on RDP disconnect (EventID 24).</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription><![CDATA[$sub]]></Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
    <ExecutionTimeLimit>PT1M</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>$args</Arguments>
    </Exec>
  </Actions>
</Task>
"@
}

function Build-BootTaskXml {
  $args = "-NoProfile -ExecutionPolicy Bypass -File `"$EnforcerPath`" -Mode Install -SelfUrl `"$SelfUrl`""

@"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>Shourav</Author>
    <Description>Re-enforce RDP AutoLogoff at boot.</Description>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
    <Enabled>true</Enabled>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>$args</Arguments>
    </Exec>
  </Actions>
</Task>
"@
}

# -----------------------------
# Uninstall
# -----------------------------
function Uninstall-All {
  Log "Uninstall starting..."
  $scht = Get-SystemExePath "schtasks.exe"
  [void](Run-Native $scht @("/Delete","/TN","`"$TaskEventName`"","/F"))
  [void](Run-Native $scht @("/Delete","/TN","`"$TaskBootName`"","/F"))

  foreach ($p in @(
    $PayloadPath,
    $EnforcerPath,
    (Join-Path $BaseDir 'Task-Event.xml'),
    (Join-Path $BaseDir 'Task-Boot.xml'),
    (Join-Path $BaseDir 'AutoLogoff.log')
  )) {
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
  }

  Log "Uninstall complete."
}

# -----------------------------
# Banner
# -----------------------------
Ensure-Dir $BaseDir
Log "======================================================================="
Log " RDP AutoLogoff FullAuto  v$Version"
Log " Author: $Author"
Log " Host  : $env:COMPUTERNAME"
Log " User  : $env:USERNAME"
Log " Mode  : $Mode"
Log "======================================================================="

if ($Mode -ne 'Check' -and $Mode -ne 'Uninstall') {
  if (-not (Is-Admin)) { throw "Not elevated. Run PowerShell as Administrator." }
}

# -----------------------------
# Main
# -----------------------------
switch ($Mode) {
  'Uninstall' {
    Uninstall-All
    break
  }

  'Install' {
    Ensure-Dir $BaseDir
    Ensure-ChannelEnabled
    Write-FileIfDifferent -path $PayloadPath -content $PayloadContent

    # Persist enforcer (prefer self-copy; fallback to minimal downloader for IEX)
    if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
      $self = Get-Content -LiteralPath $PSCommandPath -Raw -Encoding UTF8
      Write-FileIfDifferent -path $EnforcerPath -content $self
      Log "Enforcer persisted from file path: $PSCommandPath"
    } else {
      $min = Get-MinimalEnforcer $SelfUrl
      Write-FileIfDifferent -path $EnforcerPath -content $min
      Log "Enforcer persisted as minimal downloader (IEX-safe)."
    }

    # Write task XMLs
    $eventXmlPath = Join-Path $BaseDir 'Task-Event.xml'
    $bootXmlPath  = Join-Path $BaseDir 'Task-Boot.xml'

    Log "Writing task XML: $eventXmlPath"
    Write-XmlUtf16 -path $eventXmlPath -xml (Build-EventTaskXml)

    Log "Writing task XML: $bootXmlPath"
    Write-XmlUtf16 -path $bootXmlPath  -xml (Build-BootTaskXml)

    # Register tasks (NO delete first)
    Register-TaskFromXml -name $TaskEventName -xmlPath $eventXmlPath
    Register-TaskFromXml -name $TaskBootName  -xmlPath $bootXmlPath

    # Self-check
    Task-SelfCheck

    Log "INSTALL/ENFORCE OK."
    break
  }

  'Check' {
    Task-SelfCheck
    Log "CHECK OK."
    break
  }
}
