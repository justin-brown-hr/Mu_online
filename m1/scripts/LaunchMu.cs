using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

class LaunchMu {
  const uint MEM_COMMIT = 0x1000, MEM_RESERVE = 0x2000, PAGE_READWRITE = 4;
  const uint CREATE_SUSPENDED = 0x00000004;
  const uint EXTENDED_STARTUPINFO_PRESENT = 0x00080000;
  const int IpVa = unchecked((int)0x7A16C2);
  const int PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY = 0x00020007;
  // winbase.h — disable DEP for this process (needed for ASPack on OptOut systems)
  const ulong PROCESS_CREATION_MITIGATION_POLICY_DEP_DISABLE = 0x00000002UL;

  [StructLayout(LayoutKind.Sequential)]
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

  static bool TryReadIp(IntPtr h, out string ip) {
    ip = null;
    byte[] buf = new byte[32];
    int read;
    if (!ReadProcessMemory(h, new IntPtr(IpVa), buf, buf.Length, out read) || read < 8) return false;
    if (!LooksLikeIp(buf)) return false;
    int z = Array.IndexOf(buf, (byte)0);
    ip = Encoding.ASCII.GetString(buf, 0, z < 0 ? buf.Length : z);
    return true;
  }

  static bool Inject(IntPtr h, string dllPath) {
    byte[] path = Encoding.ASCII.GetBytes(dllPath + "\0");
    IntPtr mem = VirtualAllocEx(h, IntPtr.Zero, (uint)path.Length, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (mem == IntPtr.Zero) { Console.WriteLine("VirtualAllocEx err=" + Marshal.GetLastWin32Error()); return false; }
    uint written;
    WriteProcessMemory(h, mem, path, (uint)path.Length, out written);
    IntPtr load = GetProcAddress(GetModuleHandle("kernel32.dll"), "LoadLibraryA");
    uint tid;
    IntPtr th = CreateRemoteThread(h, IntPtr.Zero, 0, load, mem, 0, out tid);
    if (th == IntPtr.Zero) { Console.WriteLine("CreateRemoteThread err=" + Marshal.GetLastWin32Error()); return false; }
    WaitForSingleObject(th, 15000);
    CloseHandle(th);
    return true;
  }

  static bool ModuleLoaded(int pid, string name) {
    try {
      foreach (ProcessModule m in Process.GetProcessById(pid).Modules) {
        if (m.ModuleName.Equals(name, StringComparison.OrdinalIgnoreCase)) return true;
      }
    } catch { }
    return false;
  }

  static bool CreateSuspendedNoDep(string exe, string dir, out PROCESS_INFORMATION pi) {
    pi = new PROCESS_INFORMATION();
    IntPtr size = IntPtr.Zero;
    InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref size);
    IntPtr attrList = Marshal.AllocHGlobal((int)size);
    if (!InitializeProcThreadAttributeList(attrList, 1, 0, ref size)) {
      Console.WriteLine("InitAttrList err=" + Marshal.GetLastWin32Error());
      Marshal.FreeHGlobal(attrList);
      return false;
    }

    // 64-bit policy value even on WoW64 host when creating 32-bit child from 32-bit parent: use UInt64
    IntPtr policyMem = Marshal.AllocHGlobal(8);
    Marshal.WriteInt64(policyMem, unchecked((long)PROCESS_CREATION_MITIGATION_POLICY_DEP_DISABLE));
    if (!UpdateProcThreadAttribute(attrList, 0, new IntPtr(PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY), policyMem, new IntPtr(8), IntPtr.Zero, IntPtr.Zero)) {
      Console.WriteLine("UpdateAttr DEP_DISABLE err=" + Marshal.GetLastWin32Error() + " — continuing without");
    } else {
      Console.WriteLine("CreateProcess mitigation: DEP_DISABLE");
    }

    var siex = new STARTUPINFOEX();
    siex.StartupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFOEX));
    siex.lpAttributeList = attrList;
    IntPtr siPtr = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(STARTUPINFOEX)));
    Marshal.StructureToPtr(siex, siPtr, false);

    uint flags = CREATE_SUSPENDED | EXTENDED_STARTUPINFO_PRESENT;
    bool ok = CreateProcess(exe, "\"" + exe + "\"", IntPtr.Zero, IntPtr.Zero, false, flags, IntPtr.Zero, dir, siPtr, out pi);
    if (!ok) {
      Console.WriteLine("CreateProcess(ex) err=" + Marshal.GetLastWin32Error() + " — fallback plain suspended");
      var si = new STARTUPINFO();
      si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
      IntPtr si2 = Marshal.AllocHGlobal(si.cb);
      Marshal.StructureToPtr(si, si2, false);
      ok = CreateProcess(exe, "\"" + exe + "\"", IntPtr.Zero, IntPtr.Zero, false, CREATE_SUSPENDED, IntPtr.Zero, dir, si2, out pi);
      Marshal.FreeHGlobal(si2);
      if (!ok) Console.WriteLine("CreateProcess err=" + Marshal.GetLastWin32Error());
    }

    DeleteProcThreadAttributeList(attrList);
    Marshal.FreeHGlobal(attrList);
    Marshal.FreeHGlobal(policyMem);
    Marshal.FreeHGlobal(siPtr);
    return ok;
  }

  static int Main() {
    string dir = Path.GetDirectoryName(Process.GetCurrentProcess().MainModule.FileName);
    string exe = Path.Combine(dir, "main.exe");
    string dll = Path.Combine(dir, "Main.dll");
    if (!File.Exists(exe) || !File.Exists(dll)) { Console.WriteLine("Need main.exe + Main.dll beside LaunchMu.exe"); return 1; }

    Console.WriteLine("Starting suspended " + exe);
    PROCESS_INFORMATION pi;
    if (!CreateSuspendedNoDep(exe, dir, out pi)) return 2;

    Console.WriteLine("pid=" + pi.dwProcessId + " — inject Main.dll before resume");
    bool ok = Inject(pi.hProcess, dll);
    Console.WriteLine(ok ? "Inject OK" : "Inject FAILED");
    if (!ok) {
      CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
      return 4;
    }

    Thread.Sleep(200);
    Console.WriteLine("ResumeThread");
    ResumeThread(pi.hThread);

    string ip = null;
    for (int i = 0; i < 100; i++) {
      Thread.Sleep(100);
      uint code;
      if (GetExitCodeProcess(pi.hProcess, out code) && code != 259) {
        Console.WriteLine("main exited early code=" + unchecked((int)code));
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        Console.WriteLine("Press Enter to close...");
        try { Console.ReadLine(); } catch { Thread.Sleep(3000); }
        return 3;
      }
      if (TryReadIp(pi.hProcess, out ip)) {
        Console.WriteLine("Unpacked IP visible: " + ip);
        break;
      }
    }

    bool loaded = ModuleLoaded(pi.dwProcessId, "Main.dll");
    Console.WriteLine(loaded ? "Confirmed loaded: Main.dll" : "Main.dll NOT in module list");

    uint live = 0;
    GetExitCodeProcess(pi.hProcess, out live);
    if (live == 259) {
      Console.WriteLine("main.exe is still running (pid=" + pi.dwProcessId + ").");
      Console.WriteLine("This console can close — look for the MU game window.");
    } else {
      Console.WriteLine("main.exe already dead, exit code=" + unchecked((int)live));
      Console.WriteLine("Check Erro 100 / Error dialogs, and play-safe\\m1-main-dll.log");
    }

    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    Console.WriteLine("Press Enter to close...");
    try { Console.ReadLine(); } catch { Thread.Sleep(5000); }
    return (live == 259) ? 0 : 5;
  }
}
