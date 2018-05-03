
| Branch | AppVeyor | Latest Release|
| ------ | -------- |
| master | [![Build status](https://ci.appveyor.com/api/projects/status/kx3pjj7o02myqx9a?svg=true)](https://ci.appveyor.com/project/jrosenth/sourceone-posh)|  [![GitHub release](https://img.shields.io/github/release/jrosenth/SourceOne_POSH.svg)](https://github.com/jrosenth/SourceOne_POSH/relelases/latest)

EMC SourceOne PowerShell Module                  [![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
=========================================
This project contains a Powershell extension module for managing and automating the configuration of an EMC SourceOne environment.

Requirements
========================================
  * EMC SourceOne Version 7.1.3 or greater
  * PowerShell 4 or greater
  * .NET 4 or greater

Description
=========================================
The EMC SourceOne console (MMC) is the only supported way of configuring and managing a SourceOne implementation.
This PowerShell module provides a means of scripting and automating SourceOne configuration and management functions without using the
SourceOne console application.

The PowerShell module provides a wrapper around the same .NET and COM objects used by the MMC.

This PowerShell module must be run in an x86 (32 bit) instance of PowerShell.  SourceOne's COM objects are all 32 bit objects and only 
registered for use by 32 bit applications.

This module also require PowerShell 4.  The underlying COM objects require .NET 4 (or greater) and PowerShell 4 bind to .NET 4 by default.

Usage
=========================================
 * You must be logged in as or run the PowerShell instance with a user that has SourceOne administration privileges.
 * Some commands may require the shell instance to be launched using "Run as Administator".  This especially applies to commands which
   connect to and manage other machines (VMs) within the SourceOne implementation. Commands which manage Windows services use the 
   "Windows Management Instrumentation (WMI)" interfaces and objects.  Managing services generally requires administrator privileges 
   and accessing machines remotely also requires elevated privileges.  More information about WMI can be found by
   googling "wmi and powershell".  

Installation
=========================================
There are two methods for installing the SourceOne Powershell.

 * Download and execute the Windows based installer (ES1PowerShellInstall.msi) on a machine with SourceOne installed on it.  It is recommended installing on the same machine as the SourceOne console application, but not required.
   The installer creates a desktop shortcut, installs the module into the SourceOne binary installation location and adds that location to the system environment variable PSModulePath making the module easily available to any PowerShell instance.
   The installer is based on the free and open source <a href="http://wixtoolset.org/"> WIX Toolset </a>

 * Download the contents of the SourceOne_POSH directory and copy it into a directory named "SourceOne_POSH" on a machine with SourceOne installed on it.  Then use the explicit "Import-Module" command to load the module specifying the full path of the directory.

  There are other methods for installing and loading modules in PowerShell.  See <a href="https://msdn.microsoft.com/en-us/library/dd878350(v=vs.85).aspx"> Installing a PowerShell Module </a> and <a href="https://msdn.microsoft.com/en-us/library/dd878284(v=vs.85).aspx"> Importing a PowerShell Module </a> for more information.


Available Commands
========================================
One of the foundation concepts in Windows PowerShell is that you should only need to learn a single set of skills and behaviors for any given task; if you've already learned to use the Get-Help command to obtain instructions for a native cmdlet, you can use Get-Help to obtain instructions for SourceOne cmdlets.

To find out what SourceOne cmdlets and functions are available, a convenience command "Get-ES1Commands" has been created.  Executing this cmdlet will display a list of all the public cmdlets and functions available in the SourceOne PowerShell module.

If you wanted to "get-help" on all cmdlets and functions contained within the "SourceOne_POSH" module you can use the command:
```powershell
   Get-Command -module SourceOne_POSH | Get-Help -detail
```

Unit Tests
=========================================
A small set of unit tests based on an open source framework called Pester is provided.  <a href="https://github.com/pester/Pester">Pester </a>is the ubiquitous test and mock framework for PowerShell.

Contributions
=========================================
Create a fork of the project into your own reposity. Make all your necessary changes and create a pull request with a description on what was added or removed and details explaining the changes in lines of code. If approved, project owners will merge it.


Licensing
========================================
SourceOne PowerShell is freely distributed under the <a href="http://www.apache.org/licenses/LICENSE-2.0">Apache 2.0 License</a>. See LICENSE for details.

NOTE: Some included utility and helper functions are licensed under the MICROSOFT LIMITED PUBLIC LICENSE.

Support
========================================
Please file bugs and issues on the Github issues page for this project. This is to help keep track and document everything related to this repo.  The code and documentation are released with no warranties or SLAs and are intended to be supported through a community driven process.
