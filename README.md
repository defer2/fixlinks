# fixlinks

Fixes broken links of migrated KB documents from one CA Service Desk Manager system to another with pdm_ket and pdm_kit commands.

## How it works?

## Configuration file

Create conf.ini in script root directory with this properties:

```
[Logs]
logFile=fixlinks.log

[Databases]
DBServer_SRC=<SERVER>,<PORT>
DBName_SRC=MDB
DBUser_SRC=<DB Username>
DBPassword_SRC=<DB Password>

DBServer_TGT=<SERVER>,<PORT>
DBName_TGT=MDB
DBUser_TGT=<DB Username>
DBPassword_TGT=<DB Password>
```

## Usage
In a powershell console:
```
.\fixlinks.ps1
```
