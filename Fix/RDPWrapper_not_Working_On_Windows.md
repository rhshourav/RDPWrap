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


