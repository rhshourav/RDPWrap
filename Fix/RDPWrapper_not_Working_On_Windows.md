# RDP Wrapper Not Working on Windows

###
In some cases, the RDP Wrapper may not work as you expect it to and you may not be able to use more than one RDP connection on Windows.

The ``termsrv.dll`` file version can be updated during Windows Updates installation. If the description for your version of Windows is missing from the rdpwrap.ini file, then the RDP Wrapper will not be able to apply the necessary settings. In this case, the status ```[not supported]```. will be displayed in the RDP Wrapper Configuration window.

✅ In this case, you must update the rdpwrap.ini file as described above [by This.](https://raw.githubusercontent.com/sebaxakerhtc/rdpwrap.ini/master/rdpwrap.ini)

If RDP Wrapper does not work after updating the rdpwrap.ini file, try to open the rdpwrap.ini file and look for the section for your version of Windows.

How to understand if your Windows version is supported in rdpwrapper config?

The screenshot below shows that for my version of Windows 11 (10.0.22621.317) there are two sections of settings:
```
[10.0.22621.317]
...
[10.0.22621.317-SLInit]
...
```

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_9.jpg">
</div>

If there is no section in the rdpwrap configuration file for your version of Windows, try searching the web for the rdpwrap.ini file. Add the configuration settings you found to the end of the file.

If the RDP Wrapper does not work after you install security updates or upgrade the Windows build, check that there is no ```Listener state: Not listening ``` warning in the RDPWrap Diagnostics section.

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_10.jpg">
</div>

Try updating the rdpwrap.ini file, and then reinstalling the rdpwrapper service:
```
rdpwinst.exe -u
```
```
rdpwinst.exe -i
```
It can happen that when you try to make a second RDP connection as a different user, you will get an error message:
```
The number of connections to this computer is limited and all connections are in use right now.
Try connecting later or contact your system administrator.
```
<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_11.jpg">
</div>

In this case, you can use the ```local Group Policy Editor (gpedit.msc)``` to enable the ```“Limit number of connections”```option under ```Computer Configuration -> Administrative Templates -> Windows Components -> Remote Desktop Services -> Remote Desktop Session Host -> Connections section. Increase the ‘RD maximum connection allowed’ value to 999999.```

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_12.jpg">
</div>

Restart your computer to ```update the local Group Policy``` and apply the settings.
```
gpupdate /force
```
###

## Patch the Termsrv.dll to Enable Multiple Remote Desktop Sessions

To remove the limit on the number of concurrent RDP user connections in Windows without using rdpwrapper, you can ```replace``` the original ```termsrv.dll``` file. This is the main library file used by the Remote Desktop Service. The file is located in the ```C:\Windows\System32``` directory.

It is advisable to make a backup copy of the termsrv.dll file before editing or replacing it. This will help you to revert to the original version of the file if necessary. Open an elevated command prompt and run the command:

``` copy c:\Windows\System32\termsrv.dll termsrv.dll_backup ```
```
SUCCESS: The file (or folder): c:\Windows\System32\termsrv.dll now owned by the administrators group
```

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_13.jpg">
</div>

Now you need to stop the Remote Desktop service ```(TermService)``` using the ```services.msc``` console or with the command:
```
net stop TermService
```
It also stops the Remote Desktop Services UserMode Port Redirector service.

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_14.jpg">
</div>

Run the ```winver``` command or the following PowerShell command to find your Windows build number:
```
Get-ComputerInfo | select WindowsProductName, WindowsVersion
```

Then open the termsrv.dll file using any HEX editor (for example, Tiny Hexer). Depending on the build of Windows you are using, you will need to find and replace the string according to the table below:
```
-----------------------------------------------------------------------------------------------------------------
|    Windows build      |    	         Find the string                | 	      Replace with              |
|-----------------------|-----------------------------------------------|---------------------------------------|
|  Windows 11 22H2      |      39 81 3C 06 00 00 0F 84 75 7A 01 00	|                                       |
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 22H2       |      39 81 3C 06 00 00 0F 84 85 45 01 00      |                                       |
|-----------------------|-----------------------------------------------|                                       |
| Windows 11 21H2 (RTM) |      39 81 3C 06 00 00 0F 84 4F 68 01 00      |                                       |
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 x64 21H2   |      39 81 3C 06 00 00 0F 84 DB 61 01 00      |					|
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 x64 21H1   |      39 81 3C 06 00 00 0F 84 2B 5F 01 00      |                                       |
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 x64 20H2   |     39 81 3C 06 00 00 0F 84 21 68 01 00       |  B8 00 01 00 00 89 81 38 06 00 00 90  |
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 x64 2004   |     39 81 3C 06 00 00 0F 84 D9 51 01 00       |                                       |
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 x64 1909   |     39 81 3C 06 00 00 0F 84 5D 61 01 00       |                                       |
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 x64 1903   |     39 81 3C 06 00 00 0F 84 5D 61 01 00       |                                       |
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 x64 1809   |     39 81 3C 06 00 00 0F 84 3B 2B 01 00       |                                       |
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 x64 1803   |     8B 99 3C 06 00 00 8B B9 38 06 00 00       |                                       |
|-----------------------|-----------------------------------------------|                                       |
| Windows 10 x64 1709   |     39 81 3C 06 00 00 0F 84 B1 7D 02 00       |                                       |
-----------------------------------------------------------------------------------------------------------------
 
```

``` Tiny Hexer cannot edit termsvr.dll file directly from the system32 folder. Copy it to your desktop and replace the original file after modifying it. ```

For example, my build of Windows 10 x64 is 22H2 19045.2006 (termsrv.dll file version is 10.0.19041.1949). Open the termsrv.dll file in Tiny Hexer, then find the text:
```
39 81 3C 06 00 00 0F 84 75 7A 01 00
```
and replace it with:
```
B8 00 01 00 00 89 81 38 06 00 00 90
```

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_15.jpg">
</div>

Save the file and start the TermService.

If something goes wrong and you experience some problems with the Remote Desktop service, stop the service and replace the modified termsrv.dll file with the original version:

```copy termsrv.dll_backup c:\Windows\System32\termsrv.dll```

To avoid manually editing the termsrv.dll file with a HEX editor, you can use the following PowerShell script to automatically patch the termsrv.dll file. The PowerShell script code is available in my GitHub repository at the following link:

[https://github.com/maxbakhub/winposh/blob/main/termsrv_rdp_patch.ps1](https://github.com/maxbakhub/winposh/blob/main/termsrv_rdp_patch.ps1)

This script was written for the Windows PowerShell version and does not work in modern PowerShell Core.


👍 The advantage of the method of enabling multiple RDP sessions in Windows 10 or 11 by replacing the termsrv.dll file is that antivirus software will not react to it (unlike RDPWrap, which is detected by many antivirus products as a malware/hack tool/trojan).

👎The disadvantage of this is that you will have to manually edit the file each time you update the Windows build (or if the monthly cumulative patches update the version of termsrv.dll).
###

## Multiple Concurrent RDP Connections in Windows 10 Enterprise Multi-session
Microsoft has recently released a special edition of the operating system called ```Windows Enterprise Multi-Session``` (Previously known as Windows 10 Enterprise for Remote Sessions and Windows 10 Enterprise for Virtual Desktops)

The key feature of this edition is that it supports multiple concurrent RDP user sessions out of the box. Although the Windows multi-session edition is only allowed to be run in Azure VMs, you can install this edition on an on-premises network and use that computer as a terminal server (even though this would be against Microsoft’s licensing policies).

```The Enterprise Multi-Session edition is available for both Windows 10 and Windows 11.```

The Enterprise Multi-Session edition is available for both Windows 10 and Windows 11.

Open a command prompt and check your current edition of Windows (Professional in this example):
``` DISM /online /Get-CurrentEdition ```

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_16.jpg">
</div>

Upgrade your edition of Windows 10 from Pro to Enterprise with the command:
```
changepk.exe /ProductKey NPPR9-FWDCX-D2C8J-H872K-2YT43 
```

