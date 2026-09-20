using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

// Launch main.exe on a private Win32 desktop so SuZaNa CLtDLL FindWindowEx(ConsoleWindowClass)
// cannot see agent/PowerShell consoles on the default desktop.
class LaunchMuDesktop {
  const uint MEM_COMMIT = 0x1000, MEM_RESERVE = 0x2000, PAGE_READWRITE = 4;
  const uint CREATE_SUSPENDED = 0x00000004;
  const uint EXTENDED_STARTUPINFO_PRESENT = 0x00080000;
  const int PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY = 0x00020007;
  const ulong PROCESS_CREATION_MITIGATION_POLICY_DEP_DISABLE = 0x00000002UL;
  const int IpVa = unchecked((int)0x7A16C2);

  [DllImport("user32", SetLastError = true, CharSet = CharSet.Unicode)]
  static extern IntPtr CreateDesktop(string name, IntPtr dev, IntPtr devMode, int flags, uint access, IntPtr sa);
  [DllImport("user32", SetLastError = true)] static extern bool CloseDesktop(IntPtr h);
  [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)]
  static extern bool CreateProcess(string app, string cmd, IntPtr pa, IntPtr ta, bool inh, uint flags, IntPtr env, string dir, IntPtr si, out PROCESS_INFORMATION pi);
  [DllImport("kernel32", SetLastError = true)] static extern bool InitializeProcThreadAttributeList(IntPtr list, int count, int flags, ref IntPtr size);
  [DllImport("kernel32", SetLastError = true)] static extern bool UpdateProcThreadAttribute(IntPtr list, uint flags, IntPtr attr, IntPtr value, IntPtr size, IntPtr prev, IntPtr retSize);
  [DllImport("kernel32", SetLastError = true)] static extern void DeleteProcThreadAttributeList(IntPtr list);
  [DllImport("kernel32", SetLastError = true)] static extern uint ResumeThread(IntPtr hThread);
  [DllImport("kernel32", SetLastError = true)] static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr a, uint s, uint t, uint p);
  [DllImport("kernel32", SetLastError = true)] static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, uint s, out uint w);
  [DllImport("kernel32", SetLastError = true)] static extern bool ReadProcessMemory(IntPtr h, IntPtr a, byte[] b, int s, out int r);
  [DllImport("kernel32", SetLastError = true)] static extern IntPtr GetProcAddress(IntPtr h, string n);
  [DllImport("kernel32", SetLastError = true)] static extern IntPtr GetModuleHandle(string n);
  [DllImport("kernel32", SetLastError = true)] static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr a, uint s, IntPtr start, IntPtr p, uint f, out uint id);
  [DllImport("kernel32", SetLastError = true)] static extern uint WaitForSingleObject(IntPtr h, uint ms);
  [DllImport("kernel32", SetLastError = true)] static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32", SetLastError = true)] static extern bool GetExitCodeProcess(IntPtr h, out uint code);

  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  struct STARTUPINFO {
    public int cb;
    public IntPtr reserved, desktop, title;
    public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
    public short wShowWindow, cbReserved2;
    public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
  }

  [StructLayout(LayoutKind.Sequential)]
  struct STARTUPINFOEX {
    public STARTUPINFO StartupInfo;
    public IntPtr lpAttributeList;
  }

  [StructLayout(LayoutKind.Sequential)]
  struct PROCESS_INFORMATION {
    public IntPtr hProcess, hThread;
    public int dwProcessId, dwThreadId;
  }

  static bool Inject(IntPtr h, string dllPath) {
    byte[] path = Encoding.ASCII.GetBytes(dllPath + "\0");
    IntPtr mem = VirtualAllocEx(h, IntPtr.Zero, (uint)path.Length, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (mem == IntPtr.Zero) return false;
    uint written;
    WriteProcessMemory(h, mem, path, (uint)path.Length, out written);
    IntPtr load = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");
    uint tid;
    IntPtr th = CreateRemoteThread(h, IntPtr.Zero, 0, load, mem, 0, out tid);
    if (th == IntPtr.Zero) return false;
    WaitForSingleObject(th, 15000);
    CloseHandle(th);
    return true;
  }

  static bool LooksLikeIp(byte[] b) {
    int n = 0, dots = 0;
    for (int i = 0; i < b.Length && b[i] != 0; i++) {
      char c = (char)b[i];
      if (c == '.') dots++;
      else if (c < '0' || c > '9') return false;
      n++;
    }
    return n >= 7 && dots == 3;
  }

  static int Main() {
    string dir = Path.GetDirectoryName(Process.GetCurrentProcess().MainModule.FileName);
    string exe = Path.Combine(dir, "main.exe");
    string dll = Path.Combine(dir, "Main.dll");
    if (!File.Exists(exe) || !File.Exists(dll)) { Console.WriteLine("Need main.exe + Main.dll"); return 1; }

    string clt = Path.Combine(dir, "CLtDLL.dll");
    // Do NOT overwrite CLtDLL.dll — play-safe may already have a scanner-neutered build.
    // Stock backup remains at CLtDLL.dll.suzana.bak for restore when needed.
    Console.WriteLine("CLtDLL present=" + File.Exists(clt) + " size=" + (File.Exists(clt) ? new FileInfo(clt).Length : 0));

    const uint DESKTOP_ALL = 0x1FF;
    IntPtr desk = CreateDesktop("MuM1Desktop", IntPtr.Zero, IntPtr.Zero, 0, DESKTOP_ALL, IntPtr.Zero);
    if (desk == IntPtr.Zero) {
      Console.WriteLine("CreateDesktop err=" + Marshal.GetLastWin32Error());
      return 2;
    }
    Console.WriteLine("Private desktop MuM1Desktop OK");

    IntPtr size = IntPtr.Zero;
    InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref size);
    IntPtr attrList = Marshal.AllocHGlobal((int)size);
    InitializeProcThreadAttributeList(attrList, 1, 0, ref size);
    IntPtr policyMem = Marshal.AllocHGlobal(8);
    Marshal.WriteInt64(policyMem, unchecked((long)PROCESS_CREATION_MITIGATION_POLICY_DEP_DISABLE));
    UpdateProcThreadAttribute(attrList, 0, new IntPtr(PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY), policyMem, new IntPtr(8), IntPtr.Zero, IntPtr.Zero);

    var siex = new STARTUPINFOEX();
    siex.StartupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFOEX));
    siex.StartupInfo.desktop = Marshal.StringToHGlobalUni("MuM1Desktop");
    siex.lpAttributeList = attrList;
    IntPtr siPtr = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(STARTUPINFOEX)));
    Marshal.StructureToPtr(siex, siPtr, false);

    PROCESS_INFORMATION pi;
    uint flags = CREATE_SUSPENDED | EXTENDED_STARTUPINFO_PRESENT;
    bool ok = CreateProcess(exe, "\"" + exe + "\"", IntPtr.Zero, IntPtr.Zero, false, flags, IntPtr.Zero, dir, siPtr, out pi);
    if (!ok) {
      Console.WriteLine("CreateProcess err=" + Marshal.GetLastWin32Error());
      // fallback without mitigation, still private desktop
      var si = new STARTUPINFO();
      si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
      si.desktop = Marshal.StringToHGlobalUni("MuM1Desktop");
      IntPtr si2 = Marshal.AllocHGlobal(si.cb);
      Marshal.StructureToPtr(si, si2, false);
      ok = CreateProcess(exe, "\"" + exe + "\"", IntPtr.Zero, IntPtr.Zero, false, CREATE_SUSPENDED, IntPtr.Zero, dir, si2, out pi);
      Marshal.FreeHGlobal(si2);
    }
    if (!ok) { CloseDesktop(desk); return 3; }

    Console.WriteLine("pid=" + pi.dwProcessId + " on MuM1Desktop — inject Main.dll");
    bool inj = Inject(pi.hProcess, dll);
    Console.WriteLine(inj ? "Inject OK" : "Inject FAILED");
    ResumeThread(pi.hThread);

    for (int i = 0; i < 100; i++) {
      Thread.Sleep(100);
      uint code;
      if (GetExitCodeProcess(pi.hProcess, out code) && code != 259) {
        Console.WriteLine("main exited early code=" + unchecked((int)code));
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        CloseDesktop(desk);
        return 4;
      }
      byte[] buf = new byte[32];
      int read;
      if (ReadProcessMemory(pi.hProcess, new IntPtr(IpVa), buf, 32, out read) && LooksLikeIp(buf)) {
        int z = Array.IndexOf(buf, (byte)0);
        Console.WriteLine("Unpacked IP: " + Encoding.ASCII.GetString(buf, 0, z < 0 ? 32 : z));
        break;
      }
    }

    uint live;
    GetExitCodeProcess(pi.hProcess, out live);
    Console.WriteLine(live == 259
      ? "main RUNNING on private desktop (pid=" + pi.dwProcessId + "). Switch desktop or use RDP view."
      : "main dead code=" + live);

    // Keep desktop handle open while process runs (closing can destroy windows).
    Console.WriteLine("Press Enter to close launcher (game may keep running)...");
    try { Console.ReadLine(); } catch { Thread.Sleep(8000); }

    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    CloseDesktop(desk);
    DeleteProcThreadAttributeList(attrList);
    Marshal.FreeHGlobal(attrList);
    Marshal.FreeHGlobal(policyMem);
    Marshal.FreeHGlobal(siPtr);
    return live == 259 ? 0 : 5;
  }
}
