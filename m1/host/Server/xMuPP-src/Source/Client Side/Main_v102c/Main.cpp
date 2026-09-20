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
#include <detours.h>
#include <TlHelp32.h>

HINSTANCE hins;

static char gIp[32] = "103.56.164.158";
static char gSerial[17] = "k5lEopalwaudns8h";
static char gVersion[8] = "1.02.03";
static WORD gCsPort = 44405;
static volatile LONG gHooked = 0;
static volatile LONG gPatchStarted = 0;
static volatile LONG gEarlyHooks = 0;
static volatile LONG gBlockCtExit = 0;
static volatile LONG gEntryStarted = 0;

static void M1Log(const char* text)
{
	HANDLE f = CreateFile("m1-main-dll.log",GENERIC_WRITE,FILE_SHARE_READ,0,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
	if(f == INVALID_HANDLE_VALUE)
	{
		return;
	}
	SetFilePointer(f,0,0,FILE_END);
	DWORD w = 0;
	SYSTEMTIME st;
	GetLocalTime(&st);
	char line[512];
	wsprintf(line,"%02d:%02d:%02d.%03d %s",st.wHour,st.wMinute,st.wSecond,st.wMilliseconds,text);
	WriteFile(f,line,(DWORD)strlen(line),&w,0);
	WriteFile(f,"\r\n",2,&w,0);
	CloseHandle(f);
}

static void ApplyLivePatches()
{
	MemoryCpy(0x7A16C2,gIp,sizeof(gIp));
	SetByte(0x7A2838,(BYTE)(gVersion[0] + 1));
	SetByte(0x7A2839,(BYTE)(gVersion[2] + 2));
	SetByte(0x7A283A,(BYTE)(gVersion[3] + 3));
	SetByte(0x7A283B,(BYTE)(gVersion[5] + 4));
	SetByte(0x7A283C,(BYTE)(gVersion[6] + 5));
	MemoryCpy(0x7A2840,gSerial,sizeof(gSerial));
}

static void ApplyCltLicensePatches()
{
	// SuZaNa CLtDLL B540 writes these two bytes into unpacked main.
	__try
	{
		DWORD old = 0;
		BYTE* p = (BYTE*)0x8C1318;
		if(VirtualProtect(p, 2, PAGE_EXECUTE_READWRITE, &old))
		{
			p[0] = 0x82;
			p[1] = 0x15;
			VirtualProtect(p, 2, old, &old);
			M1Log("applied CLtDLL B540 bytes at 8C1318");
		}
	}
	__except(EXCEPTION_EXECUTE_HANDLER)
	{
		M1Log("B540 byte patch failed");
	}
}

static int IsCsPort(WORD port)
{
	return port == 44405 || port == 55557;
}

static void ForceCsAddr(sockaddr_in* in)
{
	in->sin_addr.s_addr = inet_addr(gIp);
	in->sin_port = htons(gCsPort);
}

// Log up to 48 bytes of a packet as hex, e.g. "send C1 04 F4 06".
static void M1LogHex(const char* tag,const char* buf,int len)
{
	char line[256];
	int n = wsprintf(line,"%s len=%d:",tag,len);
	for(int i=0;i<len && i<48 && n < (int)sizeof(line)-4;i++)
	{
		n += wsprintf(line+n," %02X",(BYTE)buf[i]);
	}
	M1Log(line);
}

static int (WINAPI *TrueRecv)(SOCKET,char*,int,int) = recv;

static int WINAPI MineRecv(SOCKET s,char* buf,int len,int flags)
{
	int r = TrueRecv(s,buf,len,flags);
	if(r > 0)
	{
		M1LogHex("recv",buf,r);
	}
	else
	{
		char log[64];
		wsprintf(log,"recv ret=%d wsa=%d",r,r < 0 ? WSAGetLastError() : 0);
		M1Log(log);
	}
	return r;
}

static int (WINAPI *TrueSendTo)(SOCKET,const char*,int,int,const struct sockaddr*,int) = sendto;
static int (WINAPI *TrueConnect)(SOCKET,const struct sockaddr*,int) = connect;
static int (WINAPI *TrueSend)(SOCKET,const char*,int,int) = send;

static int WINAPI MineSendTo(SOCKET s,const char* buf,int len,int flags,const struct sockaddr* to,int tolen)
{
	const struct sockaddr* use = to;
	int useLen = tolen;
	sockaddr_in copy;

	if(to != 0 && tolen >= (int)sizeof(sockaddr_in) && to->sa_family == AF_INET)
	{
		memcpy(&copy,to,sizeof(copy));
		WORD port = ntohs(copy.sin_port);
		char log[192];
		wsprintf(log,"sendto %s:%u len=%d b0=%02X",inet_ntoa(copy.sin_addr),port,len,(BYTE)(buf && len > 0 ? buf[0] : 0));
		M1Log(log);
		if(IsCsPort(port) != 0)
		{
			ForceCsAddr(&copy);
			use = (const struct sockaddr*)&copy;
			useLen = sizeof(copy);
			char rw[128];
			wsprintf(rw,"sendto rewrite -> %s:%u",gIp,gCsPort);
			M1Log(rw);
		}
	}
	else
	{
		M1Log("sendto non-ipv4");
	}

	return TrueSendTo(s,buf,len,flags,use,useLen);
}

static int WINAPI MineConnect(SOCKET s,const struct sockaddr* name,int namelen)
{
	const struct sockaddr* use = name;
	int useLen = namelen;
	sockaddr_in copy;

	if(name != 0 && namelen >= (int)sizeof(sockaddr_in) && name->sa_family == AF_INET)
	{
		memcpy(&copy,name,sizeof(copy));
		WORD port = ntohs(copy.sin_port);
		char log[192];
		wsprintf(log,"connect %s:%u",inet_ntoa(copy.sin_addr),port);
		M1Log(log);
		if(IsCsPort(port) != 0)
		{
			ForceCsAddr(&copy);
			use = (const struct sockaddr*)&copy;
			useLen = sizeof(copy);
			char rw[128];
			wsprintf(rw,"connect rewrite -> %s:%u",gIp,gCsPort);
			M1Log(rw);
		}
	}
	else
	{
		M1Log("connect non-ipv4");
	}

	return TrueConnect(s,use,useLen);
}

static int WINAPI MineSend(SOCKET s,const char* buf,int len,int flags)
{
	SOCKADDR_IN addr;
	int addrLen = sizeof(addr);
	if(getpeername(s,(SOCKADDR*)&addr,&addrLen) == 0)
	{
		char log[192];
		wsprintf(log,"send %s:%u",inet_ntoa(addr.sin_addr),ntohs(addr.sin_port));
		M1LogHex(log,buf,len);
	}
	else
	{
		M1Log("send (unconnected)");
	}

	return TrueSend(s,buf,len,flags);
}

static void InstallWinsockHooks()
{
	if(InterlockedCompareExchange(&gHooked,1,0) != 0)
	{
		return;
	}

	DetourTransactionBegin();
	DetourUpdateThread(GetCurrentThread());
	DetourAttach(&(PVOID&)TrueSendTo,MineSendTo);
	DetourAttach(&(PVOID&)TrueConnect,MineConnect);
	DetourAttach(&(PVOID&)TrueSend,MineSend);
	DetourAttach(&(PVOID&)TrueRecv,MineRecv);
	LONG err = DetourTransactionCommit();
	if(err == 0)
	{
		M1Log("winsock hooks OK (sendto/connect/send)");
	}
	else
	{
		char log[64];
		wsprintf(log,"winsock hooks FAIL err=%d",err);
		M1Log(log);
		gHooked = 0;
	}
}

static int LooksLikeIpAt(DWORD va)
{
	BYTE* p = (BYTE*)va;
	int n = 0, dots = 0;
	for(int i=0;i<31 && p[i];i++)
	{
		char c = (char)p[i];
		if(c == '.') dots++;
		else if(c < '0' || c > '9') return 0;
		n++;
	}
	return n >= 7 && dots == 3;
}

// SuZaNa CLtDLL false-positives on console windows / VPS tooling and then ExitProcess.
static HMODULE (WINAPI *TrueLoadLibraryA)(LPCSTR) = LoadLibraryA;
static HMODULE (WINAPI *TrueLoadLibraryExA)(LPCSTR,HANDLE,DWORD) = LoadLibraryExA;
static FARPROC (WINAPI *TrueGetProcAddress)(HMODULE,LPCSTR) = GetProcAddress;
static HANDLE (WINAPI *TrueCreateThread)(LPSECURITY_ATTRIBUTES,SIZE_T,LPTHREAD_START_ROUTINE,LPVOID,DWORD,LPDWORD) = CreateThread;

static HANDLE WINAPI MineCreateThread(LPSECURITY_ATTRIBUTES sa, SIZE_T stack, LPTHREAD_START_ROUTINE start, LPVOID param, DWORD flags, LPDWORD id)
{
	char log[160];
	wsprintf(log,"CreateThread start=%p param=%p flags=%08X callerTid=%u",start,param,flags,GetCurrentThreadId());
	M1Log(log);
	if(start == 0)
	{
		M1Log("CreateThread NULL start — blocked");
		if(id) *id = 0;
		SetLastError(ERROR_INVALID_PARAMETER);
		return 0;
	}
	HANDLE h = TrueCreateThread(sa,stack,start,param,flags,id);
	if(h && id)
	{
		wsprintf(log,"CreateThread OK newTid=%u",*id);
		M1Log(log);
	}
	return h;
}

static FARPROC WINAPI MineGetProcAddress(HMODULE m, LPCSTR name)
{
	FARPROC p = TrueGetProcAddress(m, name);
	if(name && ((DWORD)name > 0xFFFF))
	{
		if(!p)
		{
			char log[192];
			wsprintf(log,"GetProcAddress NULL for %s mod=%p",name,m);
			M1Log(log);
		}
		else if(strstr(name,"aff") || strstr(name,"voce"))
		{
			char log[192];
			wsprintf(log,"GetProcAddress %s -> %p",name,p);
			M1Log(log);
		}
	}
	else if(!p && name && ((DWORD)name <= 0xFFFF))
	{
		char log[128];
		wsprintf(log,"GetProcAddress ordinal %u NULL mod=%p",(DWORD)name,m);
		M1Log(log);
	}
	return p;
}

static void PatchSuZaNaScanners(HMODULE mod)
{
	if(!mod) return;
	BYTE* base = (BYTE*)mod;
	// Neutered scanners (RVA from CLtDLL 2010 build) — keep B540 license patches intact.
	// 9F70 FindWindowEx class scanner, B420 process scanner, B320/A110 helper loops.
	const DWORD rvas[] = { 0x9F70, 0xB420, 0xB320, 0xA110, 0xA070, 0xA250 };
	BYTE stub[] = { 0x33, 0xC0, 0xC3 }; // xor eax,eax; ret
	for(int i=0;i<(int)(sizeof(rvas)/sizeof(rvas[0]));i++)
	{
		BYTE* p = base + rvas[i];
		DWORD old = 0;
		if(VirtualProtect(p, sizeof(stub), PAGE_EXECUTE_READWRITE, &old))
		{
			memcpy(p, stub, sizeof(stub));
			VirtualProtect(p, sizeof(stub), old, &old);
			char log[64];
			wsprintf(log,"patched CLtDLL scanner RVA %04X",rvas[i]);
			M1Log(log);
		}
	}
	// Also rewrite ConsoleWindowClass string so any missed check won't match.
	BYTE* s = base + 0xD7CC;
	DWORD old2 = 0;
	if(VirtualProtect(s, 20, PAGE_READWRITE, &old2))
	{
		memcpy(s, "ConsoleWindowClasZ", 18);
		VirtualProtect(s, 20, old2, &old2);
		M1Log("patched ConsoleWindowClass string in CLtDLL");
	}
}

static int IsCLtDllName(LPCSTR name)
{
	if(!name) return 0;
	const char* slash = strrchr(name,'\\');
	const char* base = slash ? slash+1 : name;
	return _stricmp(base,"CLtDLL.dll") == 0;
}

static HMODULE WINAPI MineLoadLibraryA(LPCSTR name)
{
	if(IsCLtDllName(name))
	{
		// Any successful CLtDLL LoadLibrary (SuZaNa or stub) takes the client
		// "license OK" path which immediately AVs (EIP=0) on this VPS.
		// Keep process alive via MessageBox/ExitProcess nop + EntryProc patches.
		M1Log("LoadLibraryA CLtDLL blocked (VPS anti-crash)");
		SetLastError(ERROR_MOD_NOT_FOUND);
		return 0;
	}
	return TrueLoadLibraryA(name);
}

static HMODULE WINAPI MineLoadLibraryExA(LPCSTR name,HANDLE h,DWORD flags)
{
	if(IsCLtDllName(name))
	{
		M1Log("LoadLibraryExA CLtDLL blocked (VPS anti-crash)");
		SetLastError(ERROR_MOD_NOT_FOUND);
		return 0;
	}
	return TrueLoadLibraryExA(name,h,flags);
}
static int (WINAPI *TrueMessageBoxA)(HWND,LPCSTR,LPCSTR,UINT) = MessageBoxA;
static HWND (WINAPI *TrueFindWindowA)(LPCSTR,LPCSTR) = FindWindowA;
static HWND (WINAPI *TrueFindWindowW)(LPCWSTR,LPCWSTR) = FindWindowW;
static HWND (WINAPI *TrueFindWindowExA)(HWND,HWND,LPCSTR,LPCSTR) = FindWindowExA;
static void (WINAPI *TrueExitProcess)(UINT) = ExitProcess;
static struct hostent* (WINAPI *TrueGethostbyname)(const char*) = gethostbyname;
static BOOL (WINAPI *TrueProcess32FirstW)(HANDLE,LPPROCESSENTRY32W) = Process32FirstW;
static BOOL (WINAPI *TrueProcess32NextW)(HANDLE,LPPROCESSENTRY32W) = Process32NextW;
static BOOL (WINAPI *TrueModule32FirstW)(HANDLE,LPMODULEENTRY32W) = Module32FirstW;
static BOOL (WINAPI *TrueModule32NextW)(HANDLE,LPMODULEENTRY32W) = Module32NextW;
static BOOL (WINAPI *TrueTerminateProcess)(HANDLE,UINT) = TerminateProcess;
static void (WINAPI *TrueRtlExitUserProcess)(UINT) = 0;

static void WINAPI MineRtlExitUserProcess(UINT code)
{
	if(gBlockCtExit)
	{
		char log[64];
		wsprintf(log,"nop RtlExitUserProcess code=%u",code);
		M1Log(log);
		return;
	}
	TrueRtlExitUserProcess(code);
}

static int IsLicenseHost(const char* name)
{
	return name && strstr(name,"servidoresmuonline") != 0;
}

static struct hostent* WINAPI MineGethostbyname(const char* name)
{
	if(IsLicenseHost(name))
	{
		M1Log("gethostbyname: license host -> example.com");
		return TrueGethostbyname("example.com");
	}
	return TrueGethostbyname(name);
}

static int WINAPI MineMessageBoxA(HWND h,LPCSTR text,LPCSTR caption,UINT type)
{
	int block = 0;
	if((caption && strstr(caption,"Erro 100")) || (text && (strstr(text,"Programa Hacker") || strstr(text,"SuZaNa"))))
	{
		block = 1;
		M1Log("nop-msg: CLtDLL Erro 100");
	}
	else if(text && strstr(text,"servidoresmuonline"))
	{
		block = 1;
		M1Log("nop-msg: license nag servidoresmuonline");
	}
	else if(caption && _stricmp(caption,"Error") == 0 && text && strstr(text,"Acesse:"))
	{
		block = 1;
		M1Log("nop-msg: license nag Acesse");
	}

	if(block)
	{
		InterlockedExchange(&gBlockCtExit,1);
		return IDOK;
	}
	return TrueMessageBoxA(h,text,caption,type);
}

static int ClassIsConsoleA(LPCSTR cls)
{
	return cls && (_stricmp(cls,"ConsoleWindowClass") == 0 || _stricmp(cls,"ConsoleWindowClasX") == 0);
}

static int TitleIsBadA(LPCSTR title)
{
	if(!title) return 0;
	if(_stricmp(title,"cmd") == 0 || _stricmp(title,"Debug") == 0) return 1;
	if(strstr(title,"Hacker") || strstr(title,"Cheat") || strstr(title,"Olly") || strstr(title,"Process Hacker")) return 1;
	return 0;
}

static HWND WINAPI MineFindWindowA(LPCSTR cls,LPCSTR title)
{
	if(ClassIsConsoleA(cls) || TitleIsBadA(title)) return 0;
	return TrueFindWindowA(cls,title);
}

static HWND WINAPI MineFindWindowW(LPCWSTR cls,LPCWSTR title)
{
	if(cls && (_wcsicmp(cls,L"ConsoleWindowClass") == 0 || _wcsicmp(cls,L"ConsoleWindowClasX") == 0)) return 0;
	if(title && (_wcsicmp(title,L"cmd") == 0 || _wcsicmp(title,L"Debug") == 0 || wcsstr(title,L"Hacker") || wcsstr(title,L"Cheat"))) return 0;
	return TrueFindWindowW(cls,title);
}

static HWND WINAPI MineFindWindowExA(HWND parent,HWND child,LPCSTR cls,LPCSTR title)
{
	char log[160];
	wsprintf(log,"FindWindowExA cls=%s title=%s",cls ? cls : "(null)",title ? title : "(null)");
	M1Log(log);
	// SuZaNa: FindWindowExA(0,0,"ConsoleWindowClass",0) and cheat form classes
	if(ClassIsConsoleA(cls) || TitleIsBadA(title)) return 0;
	if(cls && (
		_stricmp(cls,"TAddForm") == 0 ||
		_stricmp(cls,"Tmb") == 0 ||
		_stricmp(cls,"TformSettings") == 0 ||
		_stricmp(cls,"TWildProxyMain") == 0 ||
		_stricmp(cls,"AutoIt v3 GUI") == 0 ||
		_stricmp(cls,"TUserdefinedform") == 0 ||
		_stricmp(cls,"ThunderRT6FormDC") == 0 ||
		_stricmp(cls,"TformAddressChange") == 0 ||
		_stricmp(cls,"TMemoryBrowser") == 0 ||
		_stricmp(cls,"TFoundCodeDialog") == 0 ||
		strstr(cls,"Afx:") == cls
	)) return 0;
	return TrueFindWindowExA(parent,child,cls,title);
}

static void WINAPI MineExitProcess(UINT code)
{
	if(gBlockCtExit)
	{
		char log[64];
		wsprintf(log,"nop ExitProcess code=%u",code);
		M1Log(log);
		return;
	}
	TrueExitProcess(code);
}

static BOOL WINAPI MineTerminateProcess(HANDLE h,UINT code)
{
	if(gBlockCtExit)
	{
		M1Log("nop TerminateProcess");
		return TRUE;
	}
	return TrueTerminateProcess(h,code);
}

static BOOL WINAPI MineProcess32FirstW(HANDLE h,LPPROCESSENTRY32W pe)
{
	BOOL ok = TrueProcess32FirstW(h,pe);
	if(ok)
	{
		pe->th32ProcessID = GetCurrentProcessId();
		GetModuleFileNameW(0,pe->szExeFile,MAX_PATH);
		wchar_t* slash = wcsrchr(pe->szExeFile,L'\\');
		if(slash) memmove(pe->szExeFile,slash+1,(wcslen(slash+1)+1)*sizeof(wchar_t));
	}
	return ok;
}

static BOOL WINAPI MineProcess32NextW(HANDLE,LPPROCESSENTRY32W)
{
	return FALSE;
}

static int ModuleNameIsHidden(const wchar_t* name)
{
	if(!name) return 0;
	return _wcsicmp(name,L"Main.dll") == 0 || _wcsicmp(name,L"detours.dll") == 0;
}

static BOOL WINAPI MineModule32FirstW(HANDLE h,LPMODULEENTRY32W me)
{
	BOOL ok = TrueModule32FirstW(h,me);
	while(ok && ModuleNameIsHidden(me->szModule))
	{
		ok = TrueModule32NextW(h,me);
	}
	return ok;
}

static BOOL WINAPI MineModule32NextW(HANDLE h,LPMODULEENTRY32W me)
{
	BOOL ok;
	do
	{
		ok = TrueModule32NextW(h,me);
	}
	while(ok && ModuleNameIsHidden(me->szModule));
	return ok;
}

static void InstallEarlyAntiCtHooks()
{
	if(InterlockedCompareExchange(&gEarlyHooks,1,0) != 0)
	{
		return;
	}

	TrueRtlExitUserProcess = (void (WINAPI*)(UINT))GetProcAddress(GetModuleHandle("ntdll.dll"),"RtlExitUserProcess");

	DetourTransactionBegin();
	DetourUpdateThread(GetCurrentThread());
	DetourAttach(&(PVOID&)TrueMessageBoxA,MineMessageBoxA);
	DetourAttach(&(PVOID&)TrueFindWindowA,MineFindWindowA);
	DetourAttach(&(PVOID&)TrueFindWindowW,MineFindWindowW);
	DetourAttach(&(PVOID&)TrueFindWindowExA,MineFindWindowExA);
	DetourAttach(&(PVOID&)TrueLoadLibraryA,MineLoadLibraryA);
	DetourAttach(&(PVOID&)TrueLoadLibraryExA,MineLoadLibraryExA);
	DetourAttach(&(PVOID&)TrueGetProcAddress,MineGetProcAddress);
	DetourAttach(&(PVOID&)TrueCreateThread,MineCreateThread);
	DetourAttach(&(PVOID&)TrueExitProcess,MineExitProcess);
	DetourAttach(&(PVOID&)TrueTerminateProcess,MineTerminateProcess);
	if(TrueRtlExitUserProcess)
	{
		DetourAttach(&(PVOID&)TrueRtlExitUserProcess,MineRtlExitUserProcess);
	}
	DetourAttach(&(PVOID&)TrueGethostbyname,MineGethostbyname);
	DetourAttach(&(PVOID&)TrueProcess32FirstW,MineProcess32FirstW);
	DetourAttach(&(PVOID&)TrueProcess32NextW,MineProcess32NextW);
	DetourAttach(&(PVOID&)TrueModule32FirstW,MineModule32FirstW);
	DetourAttach(&(PVOID&)TrueModule32NextW,MineModule32NextW);
	LONG err = DetourTransactionCommit();
	if(err == 0)
	{
		M1Log("early anti-CLtDLL hooks OK");
	}
	else
	{
		char log[64];
		wsprintf(log,"early anti-CLtDLL hooks FAIL err=%d",err);
		M1Log(log);
		gEarlyHooks = 0;
	}
}

static DWORD WINAPI PatchThread(LPVOID)
{
	InstallWinsockHooks();

	for(int n=0;n<80;n++)
	{
		ApplyLivePatches();
		Sleep(200);
	}

	M1Log("repatch loop done");
	return 0;
}

extern "C" _declspec(dllexport) void EntryProc();

static DWORD WINAPI EarlyAndDeferredThread(LPVOID)
{
	M1Log("EarlyAndDeferred start");
	InstallEarlyAntiCtHooks(); // idempotent if DllMain already did it
	InstallWinsockHooks();
	M1Log("waiting for ASPack unpack (IP VA)");
	for(int n=0;n<40;n++)
	{
		__try
		{
			if(LooksLikeIpAt(0x7A16C2))
			{
				M1Log("unpack visible — EntryProc");
				EntryProc();
				return 0;
			}
		}
		__except(EXCEPTION_EXECUTE_HANDLER)
		{
		}
		Sleep(50);
	}
	M1Log("unpack wait short-timeout — EntryProc anyway");
	EntryProc();
	return 0;
}

static void LoadMainInfo()
{
	if(gProtect.ReadMainFile("main.emu") != 0)
	{
		M1Log("main.emu OK");
		memcpy(gIp,gProtect.m_MainInfo.IpAddress,sizeof(gIp));
		memcpy(gSerial,gProtect.m_MainInfo.ClientSerial,sizeof(gSerial));
		memcpy(gVersion,gProtect.m_MainInfo.ClientVersion,sizeof(gVersion));
		if(gProtect.m_MainInfo.IpAddressPort != 0)
		{
			gCsPort = gProtect.m_MainInfo.IpAddressPort;
		}
		if(gCsPort != 44405 && gCsPort != 55557)
		{
			char warn[96];
			wsprintf(warn,"emu port %u invalid — forcing 44405",gCsPort);
			M1Log(warn);
			gCsPort = 44405;
		}
		char log[128];
		wsprintf(log,"emu ip=%s port=%u ver=%s",gIp,gCsPort,gVersion);
		M1Log(log);
	}
	else
	{
		M1Log("main.emu FAIL — using hardcoded 103.56.164.158 / k5lE / 1.02.03");
	}
}

extern "C" _declspec(dllexport) void EntryProc()
{
	if(InterlockedCompareExchange(&gEntryStarted,1,0) != 0)
	{
		return;
	}

	M1Log("EntryProc start");
	LoadMainInfo();
	ApplyLivePatches();
	ApplyCltLicensePatches();
	// Allow ExitProcess again after license bypass so the game can shut down normally later.
	InterlockedExchange(&gBlockCtExit,0);

	// ProtocolCoreEx can crash mismatched 1.02c packs; enable only when M1_HOOK_PROTOCOL=1
	if(GetEnvironmentVariableA("M1_HOOK_PROTOCOL",0,0) > 0)
	{
		BYTE op = *(BYTE*)0x4FF68D;
		if(op == 0xE8 || op == 0xE9 || op == 0xFF)
		{
			SetCompleteHook(0xFF,0x4FF68D,&ProtocolCoreEx);
			M1Log("ProtocolCoreEx hooked");
		}
		else
		{
			char log[64];
			wsprintf(log,"skip ProtocolCoreEx opcode=%02X",op);
			M1Log(log);
		}
	}
	else
	{
		M1Log("ProtocolCoreEx skipped (set M1_HOOK_PROTOCOL=1 to enable)");
	}

	if(GetFileAttributes("Data\\Enc1.dat") != INVALID_FILE_ATTRIBUTES)
	{
		gPacketManager.LoadEncryptionKey("Data\\Enc1.dat");
		gPacketManager.LoadDecryptionKey("Data\\Dec2.dat");
		M1Log("Enc1/Dec2 loaded");
	}
	else
	{
		M1Log("Enc1/Dec2 missing — skip");
	}

	if(InterlockedCompareExchange(&gPatchStarted,1,0) == 0)
	{
		CreateThread(0,0,PatchThread,0,0,0);
	}

	M1Log("EntryProc done");
}

static LONG WINAPI M1Vectored(EXCEPTION_POINTERS* ep)
{
	if(!ep || !ep->ExceptionRecord) return EXCEPTION_CONTINUE_SEARCH;
	DWORD code = ep->ExceptionRecord->ExceptionCode;
	if(code != 0xC0000005 && code != 0xC0000008) return EXCEPTION_CONTINUE_SEARCH;
	char log[320];
	DWORD addr = (DWORD)ep->ExceptionRecord->ExceptionAddress;
	DWORD info0 = ep->ExceptionRecord->NumberParameters > 0 ? (DWORD)ep->ExceptionRecord->ExceptionInformation[0] : 0;
	DWORD info1 = ep->ExceptionRecord->NumberParameters > 1 ? (DWORD)ep->ExceptionRecord->ExceptionInformation[1] : 0;
	wsprintf(log,"VEH AV tid=%u code=%08X eip=%08X access=%u ptr=%08X",GetCurrentThreadId(),code,addr,info0,info1);
	M1Log(log);
	if(ep->ContextRecord)
	{
		wsprintf(log,"VEH ctx eip=%08X esp=%08X eax=%08X ebx=%08X ecx=%08X edx=%08X esi=%08X edi=%08X",
			ep->ContextRecord->Eip, ep->ContextRecord->Esp,
			ep->ContextRecord->Eax, ep->ContextRecord->Ebx,
			ep->ContextRecord->Ecx, ep->ContextRecord->Edx,
			ep->ContextRecord->Esi, ep->ContextRecord->Edi);
		M1Log(log);
		DWORD* sp = (DWORD*)ep->ContextRecord->Esp;
		__try
		{
			wsprintf(log,"VEH stack %08X %08X %08X %08X %08X %08X",
				sp[0],sp[1],sp[2],sp[3],sp[4],sp[5]);
			M1Log(log);
		}
		__except(EXCEPTION_EXECUTE_HANDLER) {}
	}
	return EXCEPTION_CONTINUE_SEARCH;
}

BOOL APIENTRY DllMain(HANDLE hModule, DWORD reason, LPVOID)
{
	if(reason == DLL_PROCESS_ATTACH)
	{
		hins = (HINSTANCE)hModule;
		DisableThreadLibraryCalls((HMODULE)hModule);
		M1Log("DllMain attach");
		AddVectoredExceptionHandler(1, M1Vectored);
		// Install anti-CLtDLL hooks BEFORE CreateRemoteThread returns / main resumes,
		// so FindWindowExA is hooked before SuZaNa can see ConsoleWindowClass.
		InstallEarlyAntiCtHooks();
		CreateThread(0,0,EarlyAndDeferredThread,0,0,0);
	}
	return 1;
}
