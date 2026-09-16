$ErrorActionPreference = 'Stop'
$safe = 'D:\work\m1\host\Client\play-safe'
$msb = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe'
$proj = 'D:\work\m1\host\Server\xMuPP-src\Source\Client Side\Main_v102c\Main_v102c.vcxproj'
$mainCpp = 'D:\work\m1\host\Server\xMuPP-src\Source\Client Side\Main_v102c\Main.cpp'
$utilCpp = 'D:\work\m1\host\Server\xMuPP-src\Source\Client Side\Main_v102c\Util.cpp'

# Fix SetCompleteHook varargs (undefined behavior with &offset+1 under modern MSVC)
$util = Get-Content $utilCpp -Raw
if ($util -notmatch 'va_start') {
  $old = @'
void SetCompleteHook(BYTE head,DWORD offset,...) // OK
{
	DWORD OldProtect;

	VirtualProtect((void*)offset,5,PAGE_EXECUTE_READWRITE,&OldProtect);

	if(head != 0xFF)
	{
		*(BYTE*)(offset) = head;
	}

	DWORD* function = &offset+1;

	*(DWORD*)(offset+1) = (*function)-(offset+5);

	VirtualProtect((void*)offset,5,OldProtect,&OldProtect);
}
'@
  $new = @'
void SetCompleteHook(BYTE head,DWORD offset,...) // OK
{
	DWORD OldProtect;
	va_list arg;
	va_start(arg, offset);
	DWORD function = va_arg(arg, DWORD);
	va_end(arg);

	VirtualProtect((void*)offset,5,PAGE_EXECUTE_READWRITE,&OldProtect);

	if(head != 0xFF)
	{
		*(BYTE*)(offset) = head;
	}

	*(DWORD*)(offset+1) = function-(offset+5);

	VirtualProtect((void*)offset,5,OldProtect,&OldProtect);
}
'@
  if (-not $util.Contains('DWORD* function = &offset+1')) { throw 'SetCompleteHook pattern not found' }
  $util2 = $util.Replace($old, $new)
  if ($util2 -eq $util) { throw 'Util.cpp replace failed' }
  # ensure stdarg
  if ($util2 -notmatch '#include <stdarg.h>') {
    $util2 = $util2.Replace('#include "stdafx.h"', "#include `"stdafx.h`"`r`n#include <stdarg.h>")
  }
  Set-Content $utilCpp -Value $util2 -Encoding ASCII
  Write-Host 'Fixed SetCompleteHook va_list'
}

function Build-Main {
  & $msb $proj /p:Configuration=Debug /p:Platform=Win32 /p:PlatformToolset=v143 /t:Build /m /v:q /nologo
  if ($LASTEXITCODE -ne 0) { throw "build failed $LASTEXITCODE" }
  Copy-Item 'D:\work\m1\host\Server\xMuPP-src\Source\Client Side\Main_v102c\Build\Debug\Main.dll' "$safe\Main.dll" -Force
}

function Test-Client([string]$label, [int]$seconds = 8) {
  Get-Process Main,main -EA SilentlyContinue | Stop-Process -Force
  Start-Sleep 1
  $p = Start-Process "$safe\main.exe" -WorkingDirectory $safe -PassThru
  Start-Sleep $seconds
  $msg = "{0}: exited={1} code={2} title={3}" -f $label, $p.HasExited, $p.ExitCode, $p.MainWindowTitle
  Write-Host $msg
  if (-not $p.HasExited) {
    Stop-Process -Id $p.Id -Force -EA SilentlyContinue
    return $true
  }
  return $false
}

# Full EntryProc: delay hooks off DllMain loader lock via CreateThread
@'
#include "stdafx.h"
#include "resource.h"
#include "Main.h"
#include "Common.h"
#include "CustomItem.h"
#include "CustomJewel.h"
#include "CustomWing.h"
#include "CustomWIngEffect.h"
#include "HackCheck.h"
#include "HealthBar.h"
#include "Item.h"
#include "PacketManager.h"
#include "PrintPlayer.h"
#include "Protect.h"
#include "Protocol.h"
#include "Reconnect.h"
#include "Resolution.h"
#include "Util.h"
#include "Util/CCRC32.H"
#include <atltime.h>

HINSTANCE hins;

static DWORD WINAPI InitThread(LPVOID)
{
	Sleep(500);

	if(gProtect.ReadMainFile("main.emu") == 0)
	{
		return 0;
	}

	MemoryCpy(0x7A16C2, gProtect.m_MainInfo.IpAddress, sizeof(gProtect.m_MainInfo.IpAddress));

	SetByte(0x7A2838, (BYTE)(gProtect.m_MainInfo.ClientVersion[0] + 1));
	SetByte(0x7A2839, (BYTE)(gProtect.m_MainInfo.ClientVersion[2] + 2));
	SetByte(0x7A283A, (BYTE)(gProtect.m_MainInfo.ClientVersion[3] + 3));
	SetByte(0x7A283B, (BYTE)(gProtect.m_MainInfo.ClientVersion[5] + 4));
	SetByte(0x7A283C, (BYTE)(gProtect.m_MainInfo.ClientVersion[6] + 5));

	MemoryCpy(0x7A2840, gProtect.m_MainInfo.ClientSerial, sizeof(gProtect.m_MainInfo.ClientSerial));

	SetCompleteHook(0xFF, 0x4FF68D, &ProtocolCoreEx);

	gPacketManager.LoadEncryptionKey("Data\\Enc1.dat");
	gPacketManager.LoadDecryptionKey("Data\\Dec2.dat");
	return 0;
}

extern "C" _declspec(dllexport) void EntryProc()
{
	CreateThread(0, 0, InitThread, 0, 0, 0);
}

BOOL APIENTRY DllMain(HANDLE hModule, DWORD reason, LPVOID)
{
	if(reason == DLL_PROCESS_ATTACH)
	{
		hins = (HINSTANCE)hModule;
		DisableThreadLibraryCalls((HMODULE)hModule);
		EntryProc();
	}
	return 1;
}
'@ | Set-Content $mainCpp -Encoding ASCII

Build-Main
$ok = Test-Client 'full-delayed' 10
Write-Host "stable=$ok"

# Align GS serial to client default if needed - dump serial bytes at 0x7A2840 from Main.exe
$b = [IO.File]::ReadAllBytes("$safe\Main.exe")
# VA 0x7A2840 -> file: same mapping as IP 0x7A16C2 at file 0x39FEC2 => delta file = VA - 0x401800?
# From earlier: VA 0x7A16C2 file 0x39FEC2 => file = VA - 0x401800
$fo = 0x7A2840 - 0x401800
$serial = [Text.Encoding]::ASCII.GetString($b[$fo..($fo+15)])
$ver = [Text.Encoding]::ASCII.GetString($b[(0x7A2838-0x401800)..((0x7A2838-0x401800)+4)])
Write-Host "file serial@$fo = '$serial'"
Write-Host "file verbytes = '$ver'"

# Ensure servers up and relaunch for user
$root = 'D:\work\m1\host\Server\xMuPP-src\Server Files'
foreach ($n in @('DataServer','JoinServer','ConnectServer','GameServer')) {
  if (-not (Get-Process $n -EA SilentlyContinue)) {
    Start-Process "$root\$n\$n.exe" -WorkingDirectory "$root\$n"
    Start-Sleep 2
  }
}
Get-Process GameServer -EA SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Start-Process "$root\GameServer\GameServer.exe" -WorkingDirectory "$root\GameServer"
Start-Sleep 4
Get-Process Main,main -EA SilentlyContinue | Stop-Process -Force
Start-Sleep 1
Start-Process "$safe\main.exe" -WorkingDirectory $safe
Start-Sleep 6
Get-Process Main,main,GameServer -EA SilentlyContinue | Format-Table Name,Id,MainWindowTitle -AutoSize
Write-Host 'LAUNCHED play-safe'
Write-Host 'Login: test / test123'
