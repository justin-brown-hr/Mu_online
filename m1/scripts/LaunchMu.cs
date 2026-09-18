using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

class LaunchMu {
  const uint PROCESS_ALL_ACCESS = 0x1F0FFF;
  const uint MEM_COMMIT = 0x1000, MEM_RESERVE = 0x2000, PAGE_READWRITE = 4;
  const uint CREATE_SUSPENDED = 0x00000004;
  const uint INFINITE = 0xFFFFFFFF;
  const int IpVa = unchecked((int)0x7A16C2);

  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  struct STARTUPINFO {
    public int cb;
    public string reserved, desktop, title;
    public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
    public short wShowWindow, cbReserved2;
    public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
  }

  [StructLayout(LayoutKind.Sequential)]
  struct PROCESS_INFORMATION {
    public IntPtr hProcess, hThread;
    public int dwProcessId, dwThreadId;
  }

  [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)]
  static extern bool CreateProcess(string app, string cmd, IntPtr pa, IntPtr ta, bool inh, uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
  [DllImport("kernel32", SetLastError = true)] static extern uint ResumeThread(IntPtr hThread);
  [DllImport("kernel32", SetLastError = true)] static extern IntPtr OpenProcess(uint a, bool b, int c);
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

  static int Main() {
    string dir = Path.GetDirectoryName(Process.GetCurrentProcess().MainModule.FileName);
    string exe = Path.Combine(dir, "main.exe");
    string dll = Path.Combine(dir, "Main.dll");
    if (!File.Exists(exe) || !File.Exists(dll)) { Console.WriteLine("Need main.exe + Main.dll beside LaunchMu.exe"); return 1; }

    Console.WriteLine("Starting suspended " + exe);
    var si = new STARTUPINFO();
    si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
    PROCESS_INFORMATION pi;
    if (!CreateProcess(exe, "\"" + exe + "\"", IntPtr.Zero, IntPtr.Zero, false, CREATE_SUSPENDED, IntPtr.Zero, dir, ref si, out pi)) {
      Console.WriteLine("CreateProcess err=" + Marshal.GetLastWin32Error());
      return 2;
    }

    Console.WriteLine("pid=" + pi.dwProcessId + " — inject Main.dll before resume (anti-CLtDLL hooks)");
    bool ok = Inject(pi.hProcess, dll);
    Console.WriteLine(ok ? "Inject OK" : "Inject FAILED");
    if (!ok) {
      CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
      return 4;
    }

    // Give DllMain time to install early hooks while still suspended
    Thread.Sleep(200);
    Console.WriteLine("ResumeThread");
    ResumeThread(pi.hThread);

    // Wait briefly for unpack + confirm Main.dll stays mapped
    string ip = null;
    for (int i = 0; i < 100; i++) {
      Thread.Sleep(100);
      uint code;
      if (GetExitCodeProcess(pi.hProcess, out code) && code != 259) {
        Console.WriteLine("main exited early code=" + unchecked((int)code));
        CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
        return 3;
      }
      if (TryReadIp(pi.hProcess, out ip)) {
        Console.WriteLine("Unpacked IP visible: " + ip);
        break;
      }
    }

    bool loaded = ModuleLoaded(pi.dwProcessId, "Main.dll");
    Console.WriteLine(loaded ? "Confirmed loaded: Main.dll" : "Main.dll NOT in module list");
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return loaded ? 0 : 5;
  }
}
