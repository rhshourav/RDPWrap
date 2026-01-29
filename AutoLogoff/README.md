# RDP AutoLogoff (Immediate Logoff on Disconnect) — Windows 10 (Domain)

**Version:** 1.1.2  
**Author:** Shourav — github.com/rhshourav

This project enforces the behavior you actually want:

- Closing an RDP window normally leaves a session **Disconnected**.
- This script forces **immediate logoff** when the RDP session disconnects.

It does this by creating an **event-triggered scheduled task** that fires on the RDP disconnect event and runs a payload to log off disconnected sessions. It also creates a **boot-time enforcement task** so the config re-applies on every restart.

---

## What it changes

Creates and maintains:

### 1) Event Log Channel
Enables this channel (required to trigger on disconnect event):

- `Microsoft-Windows-TerminalServices-LocalSessionManager/Operational`

Verification is done via registry (not localized `wevtutil gl` output).

### 2) Local Files
Stored in:

- `C:\ProgramData\RDP-AutoLogoff\`

Files:
- `AutoLogoff-DisconnectedRdp.ps1` → payload that logs off disconnected RDP sessions
- `Enforce.ps1` → enforcer script (copied from the installer when run from file; or a downloader if installed via IEX)
- `Task-Event.xml` → scheduled task definition (disconnect event)
- `Task-Boot.xml` → scheduled task definition (boot enforcement)
- `Install.log` → installer log
- `AutoLogoff.log` → runtime payload log (when disconnect happens)

### 3) Scheduled Tasks (runs as SYSTEM)
- **`RDP AutoLogoff on Disconnect`**
  - Trigger: Event ID **24** (disconnect) from `LocalSessionManager/Operational`
  - Action: runs `AutoLogoff-DisconnectedRdp.ps1`

- **`RDP AutoLogoff Enforce`**
  - Trigger: **On system boot**
  - Action: runs `Enforce.ps1` to re-apply settings and re-check integrity

---

## Critical warning (don’t ignore)
This is **aggressive** by design.

If the network drops (Wi-Fi jitter, VPN flap, packet loss), your RDP session will be treated as “disconnected” and you will be **logged off immediately**, potentially losing:
- in-progress installs
- long-running scripts
- unsaved work

If you want a safer approach, use a **disconnected-session timeout** policy instead of immediate logoff.

---

## Requirements

- Windows 10 host (domain-joined OK)
- PowerShell 5.1+
- Run installer **as Administrator** (or via SYSTEM deployment)

---

## Install (local file)

1) Copy the script to the target host (example: `C:\Users\...\Documents\test.ps1`)
2) Run in an elevated PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\test.ps1
````

---

## Install (one-liner / IEX)

> Warning: `iex (irm ...)` executes remote code directly.

```powershell
iex (irm https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/AutoLogoff/RDP-AutoLogoff-FullAuto.ps1)
```

When installed via IEX, the script may store a minimal `Enforce.ps1` that re-downloads the script on boot using the `SelfUrl`.

---

## Verify

### 1) Confirm files exist

```powershell
dir C:\ProgramData\RDP-AutoLogoff
```

### 2) Confirm tasks exist

```powershell
schtasks /Query /TN "RDP AutoLogoff on Disconnect" /V /FO LIST
schtasks /Query /TN "RDP AutoLogoff Enforce" /V /FO LIST
```

### 3) Confirm event channel enabled

```powershell
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" -Name Enabled
```

Expected: `Enabled : 1`

### 4) Confirm runtime logoff fires

1. RDP into the host
2. Close the RDP window (disconnect)
3. Check payload log:

```powershell
type C:\ProgramData\RDP-AutoLogoff\AutoLogoff.log
```

---

## Check mode (self-check only)

```powershell
powershell -ExecutionPolicy Bypass -File .\test.ps1 -Mode Check
```

This verifies:

* event channel enabled
* tasks exist and their action/trigger configuration is correct
* payload/enforcer exist

---

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\test.ps1 -Mode Uninstall
```

Removes:

* both tasks
* all files in `C:\ProgramData\RDP-AutoLogoff\` (project-related)

---

## Troubleshooting

### “Disconnected” still shows after closing RDP

Expected momentarily. If it never logs off:

* task trigger not firing (event log channel disabled)
* task not created / wrong trigger
* task blocked by permissions

Check:

```powershell
wevtutil gl Microsoft-Windows-TerminalServices-LocalSessionManager/Operational
schtasks /Query /TN "RDP AutoLogoff on Disconnect" /XML
type C:\ProgramData\RDP-AutoLogoff\AutoLogoff.log
```

### Task not firing

Validate the task XML trigger includes:

* Event ID `24`
* Correct channel path

Dump XML:

```powershell
schtasks /Query /TN "RDP AutoLogoff on Disconnect" /XML
```

### Domain GPO overwriting tasks

If your domain has task policies/preferences that conflict, the tasks may be removed or replaced. Fix by deploying this via GPO so the domain is the source of truth.

---

## Notes / Design rationale

Windows RDP “X” close = **disconnect**, not logoff. This project explicitly converts disconnect into logoff using the session disconnect event.

That’s the only way to stop “Disconnected” sessions accumulating without relying on timeouts.

