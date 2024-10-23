### Before you proceed, make sure that the Remote Desktop protocol is enabled in Windows.
  - Go to Settings -> System --> Remote Desktop --> Enable Remote Destop.
   
    <img src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_2.jpg">
  - Or use the classic Control Panel: run the command  ``` SystemPropertiesRemote ```   and check the option Allow remote connection to this computer.


### RDP Wrapper: Enable Multiple RDP Sessions on Windows
##
The RDP Wrapper Library OpenSource project allows you to enable multiple RDP sessions on Windows 10/11 without replacing the termsrv.dll file. This tool acts as a layer between SCM (Service Control Manager) and the Remote Desktop Services. The RDP wrapper doesn’t make any changes to the termsrv.dll file, it simply loads the termsrv with the modified settings.

Thus, the RDPWrap will work even in the case of termsrv.dll file update. It allows you not to be afraid of Windows updates.

``` Important. Before installing the RDP Wrapper, it is important to make sure that you are using the original (unpatched)```
``` version of the termsrv.dll file. Otherwise, the RDP Wrapper may become unstable or not start at all.```

You can download the RDP Wrapper from the GitHub repository [hear](https://github.com/rhshourav/RDPWrap/releases) (the latest available version of the RDP Wrapper Library is v1.0). The project hasn’t been updated since 2017, but it can be used in all new builds of Windows 10 and 11. To use the wrapper on modern versions of Windows, simply update the rdpwrap.ini configuration file.
