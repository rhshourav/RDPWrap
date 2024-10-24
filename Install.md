### Before you proceed, make sure that the Remote Desktop protocol is enabled in Windows.
  - Go to Settings -> System --> Remote Desktop --> Enable Remote Destop.
   <div align="center">
	<img src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_2.jpg">
  </div>   

  
  - Or use the classic Control Panel: run the command  ``` SystemPropertiesRemote ```   and check the option Allow remote connection to this computer.


### RDP Wrapper: Enable Multiple RDP Sessions on Windows
##
The RDP Wrapper Library OpenSource project allows you to enable multiple RDP sessions on Windows 10/11 without replacing the termsrv.dll file. This tool acts as a layer between SCM (Service Control Manager) and the Remote Desktop Services. The RDP wrapper doesn’t make any changes to the termsrv.dll file, it simply loads the termsrv with the modified settings.

Thus, the RDPWrap will work even in the case of termsrv.dll file update. It allows you not to be afraid of Windows updates.

``` Important. Before installing the RDP Wrapper, it is important to make sure that you are using the original (unpatched)```
``` version of the termsrv.dll file. Otherwise, the RDP Wrapper may become unstable or not start at all.```

You can download the RDP Wrapper from the GitHub repository [hear](https://github.com/rhshourav/RDPWrap/releases) the latest available version of the RDP Wrapper Library is v1.0.

RDP Wrapper is detected as a potentially dangerous program by most antivirus scanners.  For example, it is classified as ```PUA:Win32/RDPWrap ```(Potentially Unwanted Software) with a low threat level by the built-in Microsoft Defender antivirus. If your antivirus settings are blocking the RDP Wrapper from starting, you will need to add it to the exceptions.
<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_3.jpg">
</div>



The RDPWrap-v1.0.zip archive contains some files:
-  ```RDPWinst.exe``` — used to install/uninstall an RDP wrapper library
-  ```RDPConf.exe``` — RDP Wrapper configuration tool
-  ```RDPCheck.exe``` — an RDP check tool (Local RDP Checker)
-  ```install.bat, uninstall.bat, update.bat``` — batch files to install, uninstall, and update RDP Wrapper.

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_4.jpg">
</div>



To install RDPWrap, run the ```install.bat``` file as an administrator. The program is installed in the ````C:\Program Files\RDP Wrapper```` directory

<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_5.jpg">
</div>


Restart your computer and run the ```RDPConfig.exe``` tool. Check that all items in the Diagnostics section are green and that the ```[Fully supported]``` message is displayed. The RDP wrapper started successfully on Windows 11 22H2 in my case.




<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_6.jpg">
</div>


##


And Insatallation done. If You See ERROR  the ```red [not supported] ``` warning.


<div align="center">
	<img style='center' src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_7.jpg">
</div>


Then [Follow This Link.](https://github.com/rhshourav/RDPWrap/blob/main/Fix/not-Supported_FIX.md)
