# TwinCAT 3 Auto-Deploy

This is for Demo purposes only and not to be deployed on any working hardware or software. 
Discovers a TwinCAT 3 target on the network, sets up an ADS route, and deploys a project to it automatically.


---

## Dependencies

| Dependency | Version | Install |
|---|---|---|
| PowerShell | 7+ | [aka.ms/powershell](https://aka.ms/powershell) |
| .NET SDK | 8+ | [dot.net/download](https://dot.net/download) |
| .NET Framework | 4.8 | Included in Windows 10/11 |
| TwinCAT 3 XAE/XAR | 3.1.4024+ | Install via Beckhoff setup |
| TcXaeMgmt module | latest | `Install-Module -Name TcXaeMgmt` |

> TwinCAT 3 XAE must be installed on this machine — the ADS router and TcXaeShell are required at runtime.

---

## Setup

1. Place your TwinCAT 3 project `.sln` file inside `TcAI_Demo\TwinCAT_ProjectTemp\`.
2. Install the TcXaeMgmt PowerShell module: `Install-Module -Name TcXaeMgmt`
3. Restore the C# project dependencies: `dotnet restore TcAI_Demo\TcAI_Project\TcAI_Project`

---

## Usage

Run the script from the repo root in a **PowerShell 7** terminal:

```powershell
.\Discover-TwinCATTarget.ps1
```

When prompted, enter the credentials for the TwinCAT target system.

**What it does, in order:**
1. Broadcast-searches the network for TwinCAT 3 targets.
2. Adds an ADS route to the discovered target.
3. Retrieves the target's AMS Net ID.
4. Opens the TwinCAT project in TcXaeShell, assigns the target, activates the configuration, and restarts TwinCAT.
