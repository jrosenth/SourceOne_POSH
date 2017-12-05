EMC SourceOne PowerShell Module
=========================================
This project contains a Powershell module for managing an EMC SourceOne environment.

Requirements
========================================
EMC SourceOne Version 7.2 or greater
PowerShell 4 or greater
.NET 4 or greater


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
Coming soon..


Available Commands
========================================
One of the foundation concepts in Windows PowerShell is that you should only need to learn a single set of skills and behaviors for any given task; if you've already learned to use the Get-Help command to obtain instructions for a native cmdlet, you can use Get-Help to obtain instructions for SourceOne cmdlets.

The SourceOne PowerShell conforms to the standard comment-based help documentation format. Essentially, the shell knows to look for specially formatted comments inside of a script or function, and it parses those comments to construct the same type of help display you'd see with a native cmdlet. 

To find out what SourceOne cmdlets and functions are available, a convenience command "Get-ES1Commands" has been created.  Executing this cmdlet will display a list of all the public cmdlets and functions available in the SourceOne PowerShell module.

If you wanted to "get-help" on all cmdlets and functions contained within the "SourceOne_POSH" module you can use the command:

           Get-Command -module SourceOne_POSH | Get-Help -detail


Licensing
========================================
SourceOne PowerShell is freely distributed under the <a href="http://emccode.github.io/sampledocs/LICENSE">MIT License</a>. See LICENSE for details.

NOTE: Some included utility and helper functions are licensed under the MICROSOFT LIMITED PUBLIC LICENSE.