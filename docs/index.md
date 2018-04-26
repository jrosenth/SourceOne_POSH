
EMC SourceOne PowerShell Module               [![License](http://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)=========================================
This project contains a Powershell module for managing and automating the configuration of an EMC SourceOne environment.

Requirements
======================================== 
* EMC SourceOne Version 7.1.3 or greater
* PowerShell 4 or greater
* .NET 4 or greater

Description
=========================================
The EMC SourceOne console (MMC) is the only supported way of configuring and managing a SourceOne implementation.This PowerShell module provides a means of scripting and automating SourceOne configuration and management functions without using theSourceOne console application.
The PowerShell module provides a wrapper around the same .NET and COM objects used by the MMC.
This PowerShell module must be run in an x86 (32 bit) instance of PowerShell.  SourceOne's COM objects are all 32 bit objects and only registered for use by 32 bit applications.
This module also require PowerShell 4.  The underlying COM objects require .NET 4 (or greater) and PowerShell 4 bind to .NET 4 by default.




