#!/usr/bin/env pwsh
#
#  Copyright 2022, Roger Brown
#
#  This file is part of rhubarb-geek-nz/SQLite.Interop.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#

$VERSION = '1.0.118.0'
$SHA256 = '21093e5ffa803009c6b02e5f5495b5e07971fd0371c667359960419068a432f2'
$ZIPNAME = ('sqlite-netStandard20-binary-{0}.zip' -f $VERSION)
$TOOLS = 'sqlite-tools-win32-x86-3430200.zip'

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

trap
{
   throw $PSItem
}

foreach ($Name in 'bin', 'obj')
{
   if (Test-Path -Path $Name)
   {
      Remove-Item -Path $Name -Force -Recurse
   }
}

& "$env:ProgramW6432\dotnet\dotnet.exe" build 'test.csproj' --configuration Release

if ($LastExitCode -ne 0)
{
   exit $LastExitCode
}

if (-not (Test-Path -Path 'test.db'))
{
   Write-Output -InputObject 'Following should succeed and create a database'
   
   if (-not (Test-Path -Path $TOOLS))
   {
      if (-not (Test-Path -Path ('{0}.zip' -f $TOOLS)))
      {
         Invoke-WebRequest -Uri ('https://www.sqlite.org/2023/{0}.zip' -f $TOOLS) -OutFile ('{0}.zip' -f $TOOLS)
      }
      
      Expand-Archive -Path ('{0}.zip' -f $TOOLS) -DestinationPath .
   }
   
   @"
CREATE TABLE MESSAGES (
	CONTENT VARCHAR(256)
);

INSERT INTO MESSAGES (CONTENT) VALUES ('Hello World');

SELECT * FROM MESSAGES;
"@ | & "$TOOLS\sqlite3.exe" test.db
   
   if ($LastExitCode -ne 0)
   {
      exit $LastExitCode
   }
}

if (("$env:PROCESSOR_ARCHITECTURE" -eq 'x86') -or ("$env:PROCESSOR_ARCHITECTURE" -eq 'AMD64'))
{
   Write-Output -InputObject 'Following should succeed and read the database'
   
   & "$env:ProgramW6432\dotnet\dotnet.exe" 'bin\Release\net6.0\test.dll'
   
   if ($LastExitCode -ne 0)
   {
      exit $LastExitCode
   }
}

Remove-Item -Path 'bin\Release\net6.0\runtimes' -Force -Recurse

Write-Output -InputObject 'Following should fail with missing SQLite.Interop.dll'

& "$env:ProgramW6432\dotnet\dotnet.exe" 'bin\Release\net6.0\test.dll'

if ($LastExitCode -eq 0)
{
   throw 'This should have failed with no SQLite.Interop.dll'
}

if (-not (Test-Path -Path 'runtimes'))
{
   Expand-Archive -Path SQLite.Interop-$VERSION -win .zip -DestinationPath '.'
}

switch ("$env:PROCESSOR_ARCHITECTURE")
{
   'x86'
   {
      Copy-Item -LiteralPath 'runtimes\win-x86\native\SQLite.Interop.dll' -Destination 'bin\Release\net6.0'
   }
   'AMD64'
   {
      Copy-Item -LiteralPath 'runtimes\win-x64\native\SQLite.Interop.dll' -Destination 'bin\Release\net6.0'
   }
   'ARM'
   {
      Copy-Item -LiteralPath 'runtimes\win-arm\native\SQLite.Interop.dll' -Destination 'bin\Release\net6.0'
   }
   'ARM64'
   {
      Copy-Item -LiteralPath 'runtimes\win-arm64\native\SQLite.Interop.dll' -Destination 'bin\Release\net6.0'
   }
   default
   {
      throw 'Unknown architecure'
   }
}

Write-Output -InputObject 'Following should fail with missing entry point SI7fca2652f71267db in SQLite.Interop.dll'

& "$env:ProgramW6432\dotnet\dotnet.exe" 'bin\Release\net6.0\test.dll'

if ($LastExitCode -eq 0)
{
   throw 'This should have failed with missing entry point SI7fca2652f71267db in SQLite.Interop.dll'
}

if (-not (Test-Path -Path $ZIPNAME))
{
   Invoke-WebRequest -Uri ('https://system.data.sqlite.org/blobs/{0}/{1}' -f $VERSION, $ZIPNAME) -OutFile $ZIPNAME
}

Remove-Item -Path 'bin\Release\net6.0\System.Data.SQLite.dll'

$null = New-Item -Path '.' -Name 'tmp' -ItemType 'directory'

try
{
   Expand-Archive -LiteralPath $ZIPNAME -DestinationPath 'tmp'
   
   if ((Get-FileHash -LiteralPath $ZIPNAME -Algorithm 'SHA256').Hash -ne $SHA256)
   {
      throw ('SHA256 mismatch for {0}' -f $ZIPNAME)
   }
   
   $null = Move-Item -Path 'tmp\System.Data.SQLite.dll' -Destination 'bin\Release\net6.0'
}
finally
{
   Remove-Item -Path 'tmp' -Force -Recurse
}

Write-Output -InputObject 'Following should succeed and read the database'

& "$env:ProgramW6432\dotnet\dotnet.exe" 'bin\Release\net6.0\test.dll'

if ($LastExitCode -ne 0)
{
   exit $LastExitCode
}

Write-Output -InputObject 'Tests complete'
