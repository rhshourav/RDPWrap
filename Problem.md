

<p align="center"><img src="https://raw.githubusercontent.com/rhshourav/RDPWrap/refs/heads/main/src/img/img_1.jpg" alt="Problem"></p>

<h2 align="center">Another user is signed in. If you continue, they’ll be disconnected. Do you want to sign in anyway?</h2>



# Number of Concurrent RDP Connections on Windows

There are several restrictions on the use of Remote Desktop Services in all desktop versions of Windows 10 and 11:

  1. Only Windows Professional and Enterprise editions can accept remote desktop connections. RDP access is not allowed to Home/Single Language Windows editions;
  2. Only one simultaneous RDP connection is available. Attempting to start a second RDP session will prompt the user to end the active session;
  3. If the user is working at the computer console (locally), their local session is disconnected (locked) when they make a remote RDP connection. The remote RDP session will also be terminated if the user logs into Windows from the computer’s console.

The number of concurrent RDP connections on Windows is a license limitation. Microsoft prohibits the creation of a workstation-based Terminal RDP server for multiple users to work simultaneously.

If your tasks require the deployment of a terminal server, Microsoft suggests purchasing a Windows Server (allows two simultaneous RDP connections by default). If you need more concurrent user sessions, you will need to purchase RDS CALs, install, and configure the Remote Desktop Session Host (RDSH) role, or deploy an RDS farm.

Technically, any version of Windows with sufficient RAM and CPU resources can support dozens of remote user sessions simultaneously. On average, an RDP user session requires 150-200MB of memory (excluding running apps). This means that the maximum number of concurrent RDP sessions is limited only by the available resources of the computer.
