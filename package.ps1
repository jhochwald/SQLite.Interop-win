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
$SHA256 = 'bb599fa265088abb8a7d4af6218cae97df8b9c8ed6f04fb940a5d564920ee6a1'
$ZIPNAME = ('sqlite-netFx-source-{0}.zip' -f $VERSION)
$INTEROP_RC_VERSION = $VERSION.Replace('.', ',')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

trap
{
   throw $PSItem
}

foreach ($Name in 'bin', 'obj', 'runtimes', ('SQLite.Interop-{0}-win.zip' -f $VERSION))
{
   if (Test-Path -Path $Name)
   {
      Remove-Item -Path $Name -Force -Recurse
   }
}

if (-not (Test-Path -Path 'src'))
{
   if (-not (Test-Path -Path $ZIPNAME))
   {
      Invoke-WebRequest -Uri ('https://system.data.sqlite.org/blobs/{0}/{1}' -f $VERSION, $ZIPNAME) -OutFile $ZIPNAME
   }
   
   if ((Get-FileHash -LiteralPath $ZIPNAME -Algorithm 'SHA256').Hash -ne $SHA256)
   {
      throw ('SHA256 mismatch for {0}' -f $ZIPNAME)
   }
   
   Expand-Archive -Path $ZIPNAME -DestinationPath 'src'
}

$Utf8NoBomEncoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $False

Get-ChildItem -Path 'src\SQLite.Interop\src\contrib' -Filter *.c -Recurse | ForEach-Object -Process {
   [string]$FileName = $_.FullName
   
   Write-Output -InputObject ('Reading {0}' -f $FileName)
   
   [string]$Content = [IO.File]::ReadAllText($FileName)
   
   $Changed = $False
   
   (
      ('typedef signed int int16_t;', 'typedef signed short int16_t;'),
      ('typedef unsigned int uint16_t;', 'typedef unsigned short uint16_t;'),
      ('typedef signed long int int32_t;', 'typedef signed int int32_t;'),
      ('typedef unsigned long int uint32_t;', 'typedef unsigned int uint32_t;')
   ) | ForEach-Object -Process {
      if ($Content.Contains($_[0]))
      {
         $Content = $Content.Replace($_[0], $_[1])
         $Changed = $True
      }
   }
   
   if ($Changed)
   {
      Write-Output -InputObject ('Writing {0}' -f $FileName)
      [IO.File]::WriteAllText($FileName, $Content, $Utf8NoBomEncoding)
   }
}

(
   ('x86', "${Env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat"),
   ('x64', "${Env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"),
   ('arm', "${Env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsamd64_arm.bat"),
   ('arm64', "${Env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsamd64_arm64.bat")
) | ForEach-Object -Process {
   $ARCH = $_[0]
   $VCVARS = $_[1]
   
   $Workdir = (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)
   
   $BuildCall = (@'
   pushd {0}
CALL "{1}"
IF ERRORLEVEL 1 EXIT %ERRORLEVEL%
NMAKE /NOLOGO -f SQLite.Interop.mak INTEROP_RC_VERSION="{2}" SRCROOT="src"
EXIT %ERRORLEVEL%
'@ -f $Workdir, $VCVARS, $INTEROP_RC_VERSION)
   
   Set-Content -Value $BuildCall -Path '.\build.cmd' -Force -Encoding UTF8 -ErrorAction Continue
   
   & '.\build.cmd'
   
   Remove-Item -Path '.\build.cmd' -Force -ErrorAction SilentlyContinue
   
   if ($LastExitCode -ne 0)
   {
      exit $LastExitCode
   }
   
   $RID = ('win-{0}' -f $ARCH)
   $RIDDIR = ('runtimes\{0}\native' -f $RID)
   
   $null = New-Item -Path '.' -Name $RIDDIR -ItemType 'directory'
   
   $null = Move-Item -Path ('bin\{0}\SQLite.Interop.dll' -f $ARCH) -Destination $RIDDIR
}

Compress-Archive -DestinationPath ('SQLite.Interop-{0}-win.zip' -f $VERSION) -LiteralPath 'runtimes'

Write-Output -InputObject 'Build complete'
