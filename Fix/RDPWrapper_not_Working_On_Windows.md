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
