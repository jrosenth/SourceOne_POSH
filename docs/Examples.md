
Naming Conventions
============================================
 * "Show-" commands produce nicely formatted data which can be redirected to a file.  These can be thought of as reporting commands.  The output from "Show-" command cannot easily be used for further processing or analysis.
 * "Get-" commands produce or return PowerShell objects, arrays of objects, or lists of objects.  The returned objects(s) from any "Get-" command can be further processed or manipulated using other PowerShell language constructs and pipelining.


Examples
====================================
General Machine (VM) Management
-----------------------------------
##### Get a list of all SourceOne Worker and Archiver machine names

```powershell
SourceOne-> Get-ES1ServerList

computername
------------
IPMARCHIVE2
IPMWORKER02
S1MASTER64
S1MASTER7-J1
```
##### Ping all the SourceOne servers
```powershell
SourceOne-> Get-ES1ServerList | Invoke-Ping | Format-Table

Address                 IPV4Address             IPV6Address                        ResponseTime STATUS
-------                 -----------             -----------                        ------------ ------
S1MASTER64              192.168.5.206                                                         0 Responding
IPMWORKER3              192.168.5.211           ::1                                           0 Responding
IPMARCHIVE2                                                                                     Unknown host
IPMWORKER02                                                                                     Unknown host
S1MASTER7-J1                                                                                    Unknown host

```

##### Get a list of just the SourceOne Worker machines 
```powershell
SourceOne-> Get-ES1Workers 

servername                workerid
----------                --------
S1MASTER7-J1.QAGSXPDC.COM        1
IPMWORKER02.QAGSXPDC.COM         2
IPMARCHIVE2.QAGSXPDC.COM         3
IPMWORKER3.QAGSXPDC.COM          4
S1MASTER64.QAGSXPDC.COM          5

```

Archive Server Examples
-----------------------------------

  ##### Display a list of SourceOne Archive machines and their enabled roles

```powershell
   SourceOne-> Show-ArchiverRoles

   Number of Archives: 3

   ArchiveName ServerName                RolesValue Enabled Roles
   ----------- ----------                ---------- -------------
   Archive1    s1Master7.myco.com                15 {Archive, Index, Query, Retrieval}
   IPMArchive  IPMWorker02.myco.com              14 {Index, Query, Retrieval}
   SecondIPM   IPMArchive2.myco.com              14 {Index, Query, Retrieval}

```

  ##### Get a list of SourceOne Archive server objects and their properties

```powershell

   SourceOne-> $arServers=Get-ArchiveServers
   SourceOne-> $arServers | Select ArchiveName,ArchiveRoles,MessageCenterDir,VersionInfo | ft -AutoSize

   ArchiveName ArchiveRoles                       MessageCenterDir                        VersionInfo
   ----------- ------------                       ----------------                        -----------
   Archive1    {Archive, Index, Query, Retrieval} \\S1MASTER64\MsgCenter\Message_Center   7.1.3.3054
   IPMArchive  {Index, Query, Retrieval}                                                  7.1.3.3054
   SecondIPM   {Index, Query, Retrieval}                                                  7.1.3.3054

```

Archive Folder Examples
-----------------------------------

##### Get archive folder summary information similar to that displayed in the management console.

```powershell
SourceOne-> Get-ArchiveFolderSummaryInfo | Format-Table -AutoSize

Name                 Volumes Volume Items Volume Size(MB) Indexes Index Items Index Size(MB) Errors Archive
----                 ------- ------------ --------------- ------- ----------- -------------- ------ -------
AtmosWithRention          42         1910              50      41        1910             34      0 Archive1
CenteraWithRetention       3            0              21       0           0              0      6 Archive1
LC Outside                30         2422             160      30        2422             51      0 Archive1
2 Year                     4           20               0       4          26              0      1 Archive1
Archive                   45         1907             130      40        1907             47      0 Archive1
Cen2NAS                   32         2422             134      30        2422             51      0 Archive1
Centera_LCOUT             33         2438              65      33        2438             51      0 Archive1
Cent2                     21          999              32      21         999             35      0 Archive1
AtmosNoRetention          40         1907              50      40        1907             34      0 Archive1
CentWithRet               34         2440              73      34        2440             50      0 Archive1
Mikes Atmos                0            0               0       0           0              0      0 Archive1
Xtender1                  40         2018             219      43        6004             75      0 IPMArchive
SecondIPMFolder            2         6002              56       1        6002             86      0 SecondIPM
```

##### Get archive folder monthly info similar to that displayed in the management console when an archive folder is expanded.


```powershell

SourceOne-> Get-ArchiveFolderMonthlyInfo -ArchiveName Archive1 -FolderName Archive | sort Name | ft -AutoSize

Archive  Folder  Name   Volumes Volume Items Volume Size(MB) Indexes Index Items Index Size(MB) Errors
-------  ------  ----   ------- ------------ --------------- ------- ----------- -------------- ------
Archive1 Archive 198001       2            2               0       1           2              0      0
Archive1 Archive 199801       1            1               0       1           1              0      0
Archive1 Archive 199804       1            3               0       1           3              0      0
Archive1 Archive 199904       1            2               0       1           2              0      0
Archive1 Archive 199905       1            1               0       1           1              0      0
Archive1 Archive 199906       1            1               0       1           1              0      0
Archive1 Archive 199907       1            1               0       1           1              0      0
Archive1 Archive 199908       1            3               0       1           3              0      0
Archive1 Archive 199909       1            2               5       1           2              6      0
Archive1 Archive 199910       1            5               0       1           5              0      0
Archive1 Archive 199912       1            5               0       1           5              0      0
Archive1 Archive 200001       1            1               0       1           1              0      0
Archive1 Archive 200005       1            2               0       1           2              0      0
Archive1 Archive 200006       1            1               0       1           1              0      0
Archive1 Archive 200010       1            2               0       1           2              0      0
Archive1 Archive 200011       1            2               0       1           2              0      0
Archive1 Archive 200102       1            1               0       1           1              0      0
Archive1 Archive 200103       1            1              13       1           1             11      0
Archive1 Archive 200106       1            2               1       1           2              1      0
Archive1 Archive 200107       2          992              54       1         992             18      0
Archive1 Archive 200108       2          287              12       1         287              2      0
Archive1 Archive 200109       2            4               0       1           4              0      0
Archive1 Archive 200110       1            5               1       1           5              2      0
Archive1 Archive 200111       1            3               0       1           3              0      0
Archive1 Archive 200112       1           21               1       1          21              1      0
Archive1 Archive 200201       1            2               0       1           2              0      0
Archive1 Archive 200202       1            3               3       1           3              0      0
Archive1 Archive 200205       2          203              16       1         203              3      0
Archive1 Archive 201102       1            1               0       1           1              0      0
Archive1 Archive 201104       1           25               0       1          25              0      0
Archive1 Archive 201208       1          117               3       1         117              1      0
Archive1 Archive 201210       1            5               0       1           5              0      0
Archive1 Archive 201302       1            2               0       1           2              0      0
Archive1 Archive 201303       1            5               0       1           5              0      0
Archive1 Archive 201402       1            1               0       1           1              0      0
Archive1 Archive 201406       1            1               0       1           1              0      0
Archive1 Archive 201412       1          182              13       1         182              2      0
Archive1 Archive 201602       1            3               0       1           3              0      0
Archive1 Archive 201605       1            3               0       1           3              0      0
Archive1 Archive 201606       1            4               0       1           4              0      0
```


Service Management Examples
-----------------------------------
   ##### Show the SourceOne services on the local machine
   ```powershell
   SourceOne-> Show-ES1Services

MachineName DisplayName                      Name                         Status
----------- -----------                      ----                         ------
IPMWORKER3  EMC SourceOne Job Dispatcher     ExJobDispatcher             Running
IPMWORKER3  EMC SourceOne Address Resolution ES1AddressResolutionService Running

   ```
##### Get the SourceOne services on a specific machine. 

```powershell
SourceOne-> Get-ES1Services -ComputerName s1master64 | Format-Table -AutoSize

Status  Name                        DisplayName
------  ----                        -----------
Running ES1AddressResolutionService EMC SourceOne Address Resolution
Running ExAddressCacheService       EMC SourceOne Address Cache
Running ExAsAdmin                   EMC SourceOne Administrator
Running ExAsArchive                 EMC SourceOne Archive
Stopped ExAsIndex                   EMC SourceOne Indexer
Running ExAsQuery                   EMC SourceOne Query
Running ExDocMgmtSvc                EMC SourceOne Document Management Service
Running ExDocMgmtSvcOA              EMC SourceOne Offline Access Retrieval Service
Running ExJobDispatcher             EMC SourceOne Job Dispatcher
Running ExJobScheduler              EMC SourceOne Job Scheduler
Running ExSearchService             EMC SourceOne Search Service
```

   ##### Get the SourceOne services on all known machines
```powershell
   
   SourceOne-> Show-AllES1Services

MachineName  DisplayName                                    Name                         Status
-----------  -----------                                    ----                         ------
IPMARCHIVE2  EMC SourceOne Indexer                          ExAsIndex                   Stopped
IPMARCHIVE2  EMC SourceOne Query                            ExAsQuery                   Running
IPMARCHIVE2  EMC SourceOne Job Dispatcher                   ExJobDispatcher             Running
IPMARCHIVE2  EMC SourceOne Archive                          ExAsArchive                 Stopped
IPMARCHIVE2  EMC SourceOne Address Resolution               ES1AddressResolutionService Running
IPMARCHIVE2  EMC SourceOne Inplace Migration                ES1InPlaceMigService        Running
IPMARCHIVE2  EMC SourceOne Administrator                    ExAsAdmin                   Running
IPMWORKER3   EMC SourceOne Job Dispatcher                   ExJobDispatcher             Running
IPMWORKER3   EMC SourceOne Address Resolution               ES1AddressResolutionService Running
S1MASTER64   EMC SourceOne Job Scheduler                    ExJobScheduler              Running
S1MASTER64   EMC SourceOne Job Dispatcher                   ExJobDispatcher             Running
S1MASTER64   EMC SourceOne Search Service                   ExSearchService             Running
S1MASTER64   EMC SourceOne Query                            ExAsQuery                   Running
S1MASTER64   EMC SourceOne Address Resolution               ES1AddressResolutionService Running
S1MASTER64   EMC SourceOne Offline Access Retrieval Service ExDocMgmtSvcOA              Running
S1MASTER64   EMC SourceOne Archive                          ExAsArchive                 Running
S1MASTER64   EMC SourceOne Administrator                    ExAsAdmin                   Running
S1MASTER64   EMC SourceOne Indexer                          ExAsIndex                   Stopped
S1MASTER64   EMC SourceOne Document Management Service      ExDocMgmtSvc                Running
S1MASTER64   EMC SourceOne Address Cache                    ExAddressCacheService       Running

```
##### Stop all SourceOne service running on the local machine
_NOTE : Powershell instance may need to be launched with "Run as Administrator"_
```powershell
SourceOne-> Stop-ES1Services

MachineName DisplayName                      Name                         Status
----------- -----------                      ----                         ------
localhost   EMC SourceOne Job Dispatcher     ExJobDispatcher             Stopped
localhost   EMC SourceOne Address Resolution ES1AddressResolutionService Stopped
```
##### Restart (stop and start) the services on a specific machine.  The ouput is the resulting status of the services.
_NOTE: Progress indicators are displayed_
```powershell
SourceOne-> Restart-ES1Services -ComputerName s1master64

MachineName DisplayName                                    Name                         Status
----------- -----------                                    ----                         ------
s1master64  EMC SourceOne Offline Access Retrieval Service ExDocMgmtSvcOA              Running
s1master64  EMC SourceOne Document Management Service      ExDocMgmtSvc                Running
s1master64  EMC SourceOne Job Dispatcher                   ExJobDispatcher             Running
s1master64  EMC SourceOne Search Service                   ExSearchService             Running
s1master64  EMC SourceOne Job Scheduler                    ExJobScheduler              Running
s1master64  EMC SourceOne Query                            ExAsQuery                   Running
s1master64  EMC SourceOne Address Cache                    ExAddressCacheService       Running
s1master64  EMC SourceOne Address Resolution               ES1AddressResolutionService Running
s1master64  EMC SourceOne Administrator                    ExAsAdmin                   Running
s1master64  EMC SourceOne Indexer                          ExAsIndex                   Running
s1master64  EMC SourceOne Archive                          ExAsArchive                 Running
```

##### Update the password for the SourceOne service account on all machines.  
_NOTE 1 : Powershell instance must be launched with "Run as Administrator"_
_NOTE 2: This process does not change the password for the service account.  The actual account password change is done through the normal Windows account password change/management procedures._

In a multi machine SourceOne deployment changing the password for the SourceOne service account can be very painful.  There are many services on many machines which store the SourceOne service account username and password in order to run the service with those credentials.  Some organizations have security policies which dictate changing passwords, even for services, on a regular basis.

It is recommended this be done from the SourceOnce Master, especially if the master is not running any other SourceOne services other than master and/or console. 

You will be prompted to enter the new password.  The password will be masked and not displayed.  Once the password is entered, it will be validated in combination with the account name given against Active Directory.  If the password validation fails you cannot proceed.
```powershell
SourceOne-> Update-AllS1ServicesAccountInfo -s1acct E5Admin

Enter the password for E5Admin: *********

Server: E5WORKER02 Password changed for service DCWorkerService
Server: E5WORKER02 Password changed for service ES1AddressResolutionService
Server: E5WORKER02 Password changed for service ExAddressCacheService
Server: E5WORKER02 Password changed for service ExAsAdmin
Server: E5WORKER02 Password changed for service ExAsArchive
Server: E5WORKER02 Password changed for service ExAsIndex
Server: E5WORKER02 Password changed for service ExAsQuery
Server: E5WORKER02 Password changed for service ExDocMgmtSvc
Server: E5WORKER02 Password changed for service ExDocMgmtSvcOA
Server: E5WORKER02 Password changed for service ExJobDispatcher
Server: E5WORKER02 Password changed for service ExJobScheduler
Server: E5WORKER02 Password changed for service ExSearchService

SystemName ServiceName                 StopStatus ChangeStatus StartStatus
---------- -----------                 ---------- ------------ -----------
E5WORKER02 ExDocMgmtSvcOA                    True Success             True
E5WORKER02 ExDocMgmtSvc                      True Success             True
E5WORKER02 ExAsQuery                         True Success             True
E5WORKER02 ExSearchService                   True Success             True
E5WORKER02 ExJobScheduler                    True Success             True
E5WORKER02 ExJobDispatcher                   True Success             True
E5WORKER02 ExAddressCacheService             True Success             True
E5WORKER02 ES1AddressResolutionService       True Success             True
E5WORKER02 DCWorkerService                   True Success             True
E5WORKER02 ExAsIndex                         True Success             True
E5WORKER02 ExAsArchive                       True Success             True
E5WORKER02 ExAsAdmin                         True Success             True

```


Database Examples
-----------------------------------
##### Get a list of Archive Connections and their database servers and database names.
```Powershell
	SourceOne-> Get-ES1ArchiveDatabases

Connection                              DBServer                                DBName
----------                              --------                                ------
Archive1                                sql2008-j1                              ES1Archive
IPMArchive                              sql2008-j1                              IPMArchive
SecondIPM                               sql2008-j1                              SecondIPMArchive
```
##### Get the Activity database server and database name
```Powershell
SourceOne-> Get-ES1ActivityDatabase

DBServer                                                    DBName
--------                                                    ------
SQL2008-J1                                                  ES1Activity

```
Organizational Policy and Activity Examples
-----------------------------------
##### Show the activities

```powershell
SourceOne-> Show-ES1Activities

Policy Name Activity Name       State            TaskType                                 TaskTypeID Created              Last Modified         Modified By
----------- -------------       -----            --------                                 ---------- -------              -------------         -----------
foo         Test 1              Active           Journaling JBS                                   16 6/10/2015 6:59:19 PM 6/9/2017 5:49:52 PM
foo         TestHAForReclassify Complete_Failed  Mailbox Management Archive JBS                    3 8/3/2015 7:00:50 PM  11/13/2015 6:53:53 PM
foo         Customer XYZ test   Complete_Failed  Mailbox Management Container Archive JBS         15 3/24/2016 5:57:40 PM 3/24/2016 5:57:40 PM
foo         Customer XYZ test 2 Complete_Success Mailbox Management Container Archive JBS         15 3/24/2016 6:34:10 PM 3/24/2016 6:34:10 PM
foo         SMTP DropDir test   User_Terminated  Journaling JBS                                   16 5/10/2016 1:24:51 PM 5/10/2016 1:24:51 PM
```

##### Show the policies

```powershell
SourceOne-> Show-ES1Policies

Policy Id Name           Description                 State     Created                Last Modified        Modified By
--------- ----           -----------                 -----     -------                -------------        -----------
        1 foo                                        Active    12/30/1899 12:00:00 AM 6/9/2017 5:50:08 PM
        3 Another Policy testing multiple policie... Suspended 12/30/1899 12:00:00 AM 4/28/2016 3:36:31 PM

```
##### Pause all policies
```powershell
SourceOne-> Pause-ES1Policies
Pausing Active Policy:  foo
WARNING: Policy "Another Policy" is not in a state that can be suspended !
```

Logging and Tracing Examples
-----------------------------------
 ##### Get the SourceOne logging trace verbosity level in the Windows registry for the specified component on the local computer.

```powershell
SourceOne-> Get-ES1Trace -Component ExArchiveJBC.exe

Computer       : IPMWORKER3
Component      : ExArchiveJBC.exe
TraceVerbosity : 0
Enabled        : 1
Splits         : 10
```
##### Set or change the logging verbosity level for the specified component on a remote computer.

```powershell
SourceOne-> Set-ES1Trace -level 4 -component exarchivejbc.exe -ComputerArray s1master64 

Computer   Component        OldVerbosity TraceVerbosity Enabled Splits
--------   ---------        ------------ -------------- ------- ------
s1master64 exarchivejbc.exe            0              4 1           10
```
