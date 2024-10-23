<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_7.jpg">
</div>

#  ```the red [not supported] warning```

##

Most likely, immediately after installation, the tool will show that the RDP wrapper is running (Installed, Running, Listening), but not working. Note the ```red [not supported]``` warning. It reports that this version of Windows 10 22H2 (ver. 10.0.19041.1949) is not supported by the RDPWrapper.

This is because the ```rdpwrap.ini```configuration file does not contain settings for your Windows version (build). +

✅ Download the latest version of ```rdpwrap.ini``` [here](https://github.com/rhshourav/RDPWrap/blob/main/Fix/rdpwrap.ini) : or
[https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/Fix/rdpwrap.ini](https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/Fix/rdpwrap.ini)

Manually copy the contents of this page into the ```C:\Program Files\RDP Wrapper\rdpwrap.ini``` file. Or download the INI file using the PowerShell cmdlet Invoke-WebRequest (you must first stop the Remote Desktop service):

```
Stop-Service termservice -Force
```
Then
```
Invoke-WebRequest https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/Fix/rdpwrap.ini -outfile "C:\Program Files\RDP Wrapper\rdpwrap.ini"
```
<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_8.jpg">
</div>

Now Run This Command as administrator.
```
net start termservice
```
Reboot your PC and run the ```RDPConfig.exe``` tool. Check that all items in the Diagnostics section are green and that the ```[Fully supported]``` message is displayed. 

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_6.jpg">
</div>


You can check that two (or more) RDP sessions are active on the computer at the same time by using the command:
```
qwinsta
```

```
rdp-tcp#0         user1                 1  Active
rdp-tcp#1         user2                 2  Active
```
