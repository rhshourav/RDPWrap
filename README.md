# RDP Wrap

![Environment](https://img.shields.io/badge/Windows-Vista,%207,%208,%2010-brightgreen.svg)
[![Release](https://img.shields.io/github/rhshourav/RDPWrapp.svg)](https://github.com/rhshourav/RDPWrap/releases)
![License](https://img.shields.io/github/license/rhshourav/rdpwrap.svg)
![Downloads](https://img.shields.io/github/downloads/rhshourav/RDPWrap/latest/total.svg)
![TotalDownloads](https://img.shields.io/github/downloads/rhshourav/RDPWrap/total.svg)

The goal of this project is to enable Remote Desktop Host support and concurrent RDP sessions on reduced functionality systems for home usage.

RDP Wrapper works as a layer between Service Control Manager and Terminal Services, so the original termsrv.dll file remains untouched. Also this method is very strong against Windows Update.


| NT Version    | 
| ------------- |
| Windows Vista | 
| Windows 7     |
| Windows 8     |
| Windows 8.1   |
| Windows 10    |
---
[WinPPE]: http://forums.mydigitallife.info/threads/39411-Windows-Product-Policy-Editor

This solution was inspired by [Windows Product Policy Editor][WinPPE], big thanks to **kost** :)

— binarymaster

### Attention:
It's recommended to have original termsrv.dll file with the RDP Wrapper installation. If you have modified it before with other patchers, it may become unstable and crash in any moment.

### Information:
- Source code is available, so you can build it on your own
- RDP Wrapper does not patch termsrv.dll, it loads termsrv with different parameters
- RDPWInst and RDPChecker can be redistributed without development folder and batch files
- RDPWInst can be used for unattended installation / deployment
- Windows 2000, XP and Server 2003 will not be supported

### Key features:
- RDP host server on any Windows edition beginning from Vista
- Console and remote sessions at the same time
- Using the same user simultaneously for local and remote logon (see configuration app)
- Up to [15 concurrent sessions]
- Console and RDP session shadowing 
- Full [multi-monitor support]

### Porting to other platforms:
- **ARM** for Windows RT (see links below)
- **IA-64** for Itanium-based Windows Server? *Well, I have no idea* :)

### Building the binaries:
- **x86 Delphi version** can be built with *Embarcadero RAD Studio 2010*
- **x86/x64 C++ version** can be built with *Microsoft Visual Studio 2013*


### Files in release package:

| File name | Description |
| --------- | ----------- |
| `RDPWInst.exe`  | RDP Wrapper Library installer/uninstaller |
| `RDPCheck.exe`  | Local RDP Checker (you can check the RDP is working) |
| `RDPConf.exe`   | RDP Wrapper Configuration |
| `install.bat`   | Quick install batch file |
| `uninstall.bat` | Quick uninstall batch file |
| `update.bat`    | Quick update batch file |

#### Confirmed working on:
- Windows Vista Starter (x86 - Service Pack 1 and higher)
- Windows Vista Home Basic
- Windows Vista Home Premium
- Windows Vista Business
- Windows Vista Enterprise
- Windows Vista Ultimate
- Windows Server 2008
- Windows 7 Starter
- Windows 7 Home Basic
- Windows 7 Home Premium
- Windows 7 Professional
- Windows 7 Enterprise
- Windows 7 Ultimate
- Windows Server 2008 R2
- Windows 8 Developer Preview
- Windows 8 Consumer Preview
- Windows 8 Release Preview
- Windows 8
- Windows 8 Single Language
- Windows 8 Pro
- Windows 8 Enterprise
- Windows Server 2012
- Windows 8.1 Preview
- Windows 8.1
- Windows 8.1 Connected (with Bing)
- Windows 8.1 Single Language
- Windows 8.1 Connected Single Language (with Bing)
- Windows 8.1 Pro
- Windows 8.1 Enterprise
- Windows Server 2012 R2
- Windows 10 Technical Preview
- Windows 10 Pro Technical Preview
- Windows 10 Home
- Windows 10 Home Single Language
- Windows 10 Pro
- Windows 10 Enterprise
- Windows Server 2016 Technical Preview

Installation instructions:
- Download latest release binaries and unpack files
- Right-click on **`install.bat`** and select Run as Administrator
- See command output for details

To update INI file:
- Right-click on **`update.bat`** and select Run as Administrator
- See command output for details

To uninstall:
- Go to the directory where you extracted the files
- Right-click on **`uninstall.bat`** and select Run as Administrator
- See command output for details
###
## For In-depth Installtation And Troubleshooting [Click Me](https://github.com/rhshourav/RDPWrap/blob/main/Install.md)
