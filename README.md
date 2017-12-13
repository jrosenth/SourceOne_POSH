EMC SourceOne PowerShell Module
=========================================
This project contains a Powershell module for managing and automating the configuration of an EMC SourceOne environment.

Requirements
========================================
  * EMC SourceOne Version 7.1.3 or greater

  * PowerShell 4 or greater

  * .NET 4 or greater


Description
=========================================
The SourceOne console (MMC) is the only supported way of configuring and managing a SourceOne implementation.
This PowerShell module provides a means of scripting and automating SourceOne configuration and management function without using the
SourceOne console.

The PowerShell module provides a wrapper around the same .NET and COM objects used by the MMC.

This PowerShell module must be run in an x86 (32 bit) instance of PowerShell.  SourceOne's COM objects are all 32 bit objects and only 
registered for use by 32 bit applications.

This module also require PowerShell 4.  The underlying COM objects require .NET 4 (or greater) and PowerShell 4 bind to .NET 4 by default.


Installation
=========================================
There are two methods for installing the SourceOne Powershell.

 * Download and execute the Windows based installer (ES1PowerShellInstall.msi) on a machine with SourceOne installed on it.  It is recommended installing on the same machine as the SourceOne console application, but not required.
   The installer creates a desktop shortcut, installs the module into the SourceOne binary installation location and adds that location to the system environment variable PSModulePath making the module easily available to any PowerShell instance.

 * Download the contents of the SourceOne_POSH directory and copy it into a directory named "SourceOne_POSH" on a machine with SourceOne installed on it.  Then use the explicit "Import-Module" command to load the module specifying the full path of the directory.

  There are other methods for installing and loading modules in PowerShell. See <a href="https://msdn.microsoft.com/en-us/library/dd878350(v=vs.85).aspx"> Installing a PowerShell Module </a> and <a href="https://msdn.microsoft.com/en-us/library/dd878284(v=vs.85).aspx"> Importing a PowerShell Module </a> for more information.


Available Commands
========================================
One of the foundation concepts in Windows PowerShell is that you should only need to learn a single set of skills and behaviors for any given task; if you've already learned to use the Get-Help command to obtain instructions for a native cmdlet, you can use Get-Help to obtain instructions for SourceOne cmdlets.

The SourceOne PowerShell conforms to the standard comment-based help documentation format. Essentially, the shell knows to look for specially formatted comments inside of a script or function, and it parses those comments to construct the same type of help display you'd see with a native cmdlet. 

To find out what SourceOne cmdlets and functions are available, a convenience command "Get-ES1Commands" has been created.  Executing this cmdlet will display a list of all the public cmdlets and functions available in the SourceOne PowerShell module.

If you wanted to "get-help" on all cmdlets and functions contained within the "SourceOne_POSH" module you can use the command:

           Get-Command -module SourceOne_POSH | Get-Help -detail

Contribution
=========================================
Create a fork of the project into your own reposity. Make all your necessary changes and create a pull request with a description on what was added or removed and details explaining the changes in lines of code. If approved, project owners will merge it.


Licensing
========================================
SourceOne PowerShell is freely distributed under the <a href="http://emccode.github.io/sampledocs/LICENSE">MIT License</a>. See LICENSE for details.

NOTE: Some included utility and helper functions are licensed under the MICROSOFT LIMITED PUBLIC LICENSE.

Support
========================================
Please file bugs and issues on the Github issues page for this project. This is to help keep track and document everything related to this repo. For general discussions and further support you can join the <a href="http://community.codedellemc.com"> {code} Community slack channel </a>. The code and documentation are released with no warranties or SLAs and are intended to be supported through a community driven process.
