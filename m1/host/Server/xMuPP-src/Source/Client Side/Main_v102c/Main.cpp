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

static void M1Log(const char* text)
{
	HANDLE f = CreateFile("m1-main-dll.log",GENERIC_WRITE,FILE_SHARE_READ,0,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
	if(f == INVALID_HANDLE_VALUE)
	{
		return;
	}
	SetFilePointer(f,0,0,FILE_END);
	DWORD w = 0;
	WriteFile(f,text,(DWORD)strlen(text),&w,0);
	WriteFile(f,"\r\n",2,&w,0);
	CloseHandle(f);
}

extern "C" _declspec(dllexport) void EntryProc()
{
	M1Log("EntryProc start");

	char ip[32] = "127.0.0.1";
	char serial[17] = "k5lEopalwaudns8h";
	char version[8] = "1.02.03";

	if(gProtect.ReadMainFile("main.emu") != 0)
	{
		M1Log("main.emu OK");
		memcpy(ip,gProtect.m_MainInfo.IpAddress,sizeof(ip));
		memcpy(serial,gProtect.m_MainInfo.ClientSerial,sizeof(serial));
		memcpy(version,gProtect.m_MainInfo.ClientVersion,sizeof(version));
	}
	else
	{
		M1Log("main.emu FAIL — using hardcoded 127.0.0.1 / k5lE / 1.02.03");
	}

	// Patch live memory after ASPack unpack (file edits do not stick).
	MemoryCpy(0x7A16C2,ip,sizeof(ip));
	SetByte(0x7A2838,(BYTE)(version[0] + 1));
	SetByte(0x7A2839,(BYTE)(version[2] + 2));
	SetByte(0x7A283A,(BYTE)(version[3] + 3));
	SetByte(0x7A283B,(BYTE)(version[5] + 4));
	SetByte(0x7A283C,(BYTE)(version[6] + 5));
	MemoryCpy(0x7A2840,serial,sizeof(serial));

	SetCompleteHook(0xFF,0x4FF68D,&ProtocolCoreEx);
	gPacketManager.LoadEncryptionKey("Data\\Enc1.dat");
	gPacketManager.LoadDecryptionKey("Data\\Dec2.dat");
	M1Log("EntryProc done");
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
